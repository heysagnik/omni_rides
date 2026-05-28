import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/map_style.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../utils/vehicle_marker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the matched driver details, live ETA, and OTP.
///
/// Phases:
///   en_route  → Driver is heading to pickup
///   arrived   → Driver is at pickup (show OTP prominently)
///   started   → Ride began → navigate to InTransit
class DriverMatchedScreen extends StatefulWidget {
  const DriverMatchedScreen({super.key});

  @override
  State<DriverMatchedScreen> createState() => _DriverMatchedScreenState();
}

class _DriverMatchedScreenState extends State<DriverMatchedScreen> {
  final RideService _rideService = RideService();
  Timer? _pollTimer;
  Timer? _trackTimer;       // live-location polling (every 4 s)
  GoogleMapController? _mapController;

  // 'en_route' | 'arrived'
  String _phase = 'en_route';

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildMapOverlay(); // immediately render markers from state data
      _fetchAndPoll();    // fetch fresh data in background
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _trackTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Map helpers ──────────────────────────────────────────────────────────

  Future<void> _buildMapOverlay() async {
    if (!mounted) return;
    final state = context.read<AppState>();

    final dLat = state.driverLat;
    final dLng = state.driverLng;
    final pLat = state.pickupLat;
    final pLng = state.pickupLng;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Pickup marker
    if (pLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pLat, pLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your pickup'),
      ));
    }

    // Driver marker + route
    if (dLat != 0 && pLat != 0) {
      final vehicleIcon = await buildVehicleMarker(state.selectedRideType);
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(dLat, dLng),
        icon: vehicleIcon,
        infoWindow: InfoWindow(title: state.driverName.isNotEmpty ? state.driverName : 'Driver'),
      ));

      // Fetch driving route
      final routePoints = await _fetchRoute(LatLng(dLat, dLng), LatLng(pLat, pLng));
      if (routePoints.isNotEmpty) {
        polylines.add(Polyline(
          polylineId: const PolylineId('driver_route'),
          points: routePoints,
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
    _fitCamera(dLat, dLng, pLat, pLng);
  }

  void _fitCamera(double dLat, double dLng, double pLat, double pLng) {
    if (_mapController == null || pLat == 0) return;

    final hasBoth = dLat != 0 && pLat != 0;
    if (hasBoth) {
      final minLat = dLat < pLat ? dLat : pLat;
      final maxLat = dLat > pLat ? dLat : pLat;
      final minLng = dLng < pLng ? dLng : pLng;
      final maxLng = dLng > pLng ? dLng : pLng;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.003, minLng - 0.003),
            northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
          ),
          80,
        ),
      );
    } else {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pLat, pLng), 16),
      );
    }
  }

  Future<List<LatLng>> _fetchRoute(LatLng origin, LatLng dest) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) return [];

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&mode=driving'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final legs = routes[0]['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final leg = legs[0] as Map<String, dynamic>;
        final durationVal = leg['duration']?['value'] as num?;
        if (durationVal != null) {
          final realTimeEta = (durationVal / 60).round();
          if (mounted) {
            context.read<AppState>().updateDriverLocation(
                  origin.latitude,
                  origin.longitude,
                  realTimeEta > 0 ? realTimeEta : 1,
                );
          }
        }
      }

      final polylineStr =
          routes[0]['overview_polyline']?['points'] as String?;
      if (polylineStr == null || polylineStr.isEmpty) return [];

      return _decodePolyline(polylineStr);
    } catch (_) {
      return [];
    }
  }

  /// Decodes a Google encoded polyline string into a list of LatLng.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ── Data fetching ────────────────────────────────────────────────────────

  Future<void> _fetchAndPoll() async {
    await _updateDriverLiveLocation(); // immediate first fetch
    await _fetchRide();
    if (!mounted) return;
    // Live-location every 4 s — redraws route + updates ETA
    _trackTimer = Timer.periodic(const Duration(seconds: 4), (_) => _updateDriverLiveLocation());
    // Ride status every 5 s — detects phase transitions
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchRide());
  }

  /// Polls /ride/:id/track for the latest driver GPS position,
  /// updates AppState, then redraws the map route and recalculates ETA.
  Future<void> _updateDriverLiveLocation() async {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty || !mounted) return;

    final track = await _rideService.getTrack(rideId);
    if (!mounted || track == null) return;

    // Parse driver location — support both flat and nested formats
    final loc = track['driverLocation'] as Map<String, dynamic>?;
    final double lat = (loc?['lat'] as num?)?.toDouble() ??
        (track['lat'] as num?)?.toDouble() ?? 0;
    final double lng = (loc?['lng'] as num?)?.toDouble() ??
        (track['lng'] as num?)?.toDouble() ?? 0;

    if (lat == 0 && lng == 0) return;

    // Keep existing ETA until _fetchRoute refreshes it from Directions API
    context.read<AppState>().updateDriverLocation(
          lat, lng, context.read<AppState>().etaMinutes);

    await _buildMapOverlay(); // redraws route + animates camera
  }

  Future<void> _fetchRide() async {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) return;

    final details = await _rideService.getRideDetails(rideId);
    if (!mounted || details == null) return;

    final d = details['ride'] ?? details['data'] ?? details;
    final status = (d['status'] as String?) ?? '';
    final state = context.read<AppState>();


    // --- Driver info (robust parsing — same logic as searching_screen) ---
    final driver = d['driver'] as Map<String, dynamic>? ?? {};

    final name = (driver['name'] ??
            driver['fullName'] ??
            driver['full_name'] ??
            d['driverName'] ??
            d['driver_name'] ??
            state.driverName)
        .toString();

    final vehicleRaw = driver['vehicle'];
    final vehicleObj = vehicleRaw is Map<String, dynamic> ? vehicleRaw : null;
    final vehicle = vehicleObj != null
        ? (vehicleObj['model'] ?? vehicleObj['name'] ?? '').toString()
        : (vehicleRaw ?? driver['vehicleModel'] ?? driver['vehicle_model'] ??
                d['vehicle'] ?? d['vehicleModel'] ?? state.driverVehicle)
            .toString();

    final plate = (vehicleObj?['plate'] ??
            vehicleObj?['licensePlate'] ??
            vehicleObj?['number'] ??
            driver['plate'] ??
            driver['vehiclePlate'] ??
            driver['licensePlate'] ??
            d['plate'] ??
            state.driverPlate)
        .toString();

    final rating =
        ((driver['rating'] ?? driver['averageRating'] ?? d['driver_rating'] ??
                    d['driverRating']) as num?)
                ?.toDouble() ??
            (state.driverRating > 0 ? state.driverRating : null);

    final phone = (driver['phone'] ??
            driver['phoneNumber'] ??
            driver['phone_number'] ??
            d['driver_phone'] ??
            d['driverPhone'] ??
            state.driverPhone)
        .toString();

    final lat =
        ((driver['lat'] ?? driver['latitude'] ?? d['driver_lat']) as num?)
                ?.toDouble() ??
            state.driverLat;
    final lng =
        ((driver['lng'] ?? driver['longitude'] ?? d['driver_lng']) as num?)
                ?.toDouble() ??
            state.driverLng;

    final eta =
        ((d['eta'] ?? d['etaMinutes'] ?? d['eta_minutes']) as num?)?.toInt() ??
            state.etaMinutes;

    final otp = d['otpCode']?.toString() ?? '';

    state.driverMatched(
      name: name.isNotEmpty ? name : 'Your Driver',
      vehicle: vehicle,
      plate: plate,
      rating: rating ?? 4.5,
      phone: phone,
      lat: lat,
      lng: lng,
      eta: eta > 0 ? eta : state.etaMinutes,
    );

    if (otp.isNotEmpty) state.setOtp(otp);

    // Refresh map markers/route if driver location changed
    if (lat != 0 && (lat != state.driverLat || lng != state.driverLng)) {
      _buildMapOverlay();
    }

    final isRideStarted = status == 'ride_started' ||
        status == 'in_progress' ||
        d['startedAt'] != null ||
        d['otpVerified'] == true;

    // Phase transitions
    if (isRideStarted) {
      _pollTimer?.cancel();
      state.startRide();
      if (mounted) Navigator.pushReplacementNamed(context, AppRouter.inTransit);
      return;
    }

    if (status == 'cancelled') {
      _pollTimer?.cancel();
      state.cancelRide('Ride cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride was cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (status == 'driver_arrived' && _phase == 'en_route') {
          _phase = 'arrived';
        }
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final initialTarget = state.pickupLat != 0
        ? LatLng(state.pickupLat, state.pickupLng)
        : const LatLng(12.9716, 77.5946); // Bengaluru fallback

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRouter.home, (route) => false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Google Map showing driver → pickup
            GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 16,
            ),
            style: MapStyles.premiumStyle,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
              // Fit camera once map is ready
              _fitCamera(
                state.driverLat,
                state.driverLng,
                state.pickupLat,
                state.pickupLng,
              );
            },
          ),

          // Back button — goes to home and keeps ride alive (minimized banner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _MapButton(
              icon: PhosphorIconsRegular.caretDown,
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRouter.home, (route) => false),
            ),
          ),

          // Bottom panel — shows immediately with state data
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              phase: _phase,
              state: state,
            ),
          ),
        ],
      ),
    ),   // Scaffold
    );   // PopScope
  }
}

// ── Bottom panel ─────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final String phase;
  final AppState state;

  const _BottomPanel({required this.phase, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Status chip
          _StatusChip(phase: phase, etaMinutes: state.etaMinutes),
          const SizedBox(height: 20),

          // Driver row
          _DriverRow(state: state),
          const SizedBox(height: 16),

          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),

          // OTP box
          _OtpBox(otp: state.rideOtp, highlight: phase == 'arrived'),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String phase;
  final int etaMinutes;

  const _StatusChip({required this.phase, required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final arrived = phase == 'arrived';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: arrived
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(14),
        border: arrived
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            arrived
                ? PhosphorIconsRegular.checkCircle
                : PhosphorIconsRegular.car,
            color: arrived ? AppColors.primary : AppColors.textDark,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived ? 'Driver has arrived' : 'Driver is on the way',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: arrived ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                if (!arrived && etaMinutes > 0)
                  Text(
                    'Arriving in $etaMinutes min',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (!arrived && etaMinutes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$etaMinutes min',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final AppState state;
  const _DriverRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final name =
        state.driverName.isNotEmpty ? state.driverName : 'Your Driver';
    final vehicleLine = [
      if (state.driverVehicle.isNotEmpty) state.driverVehicle,
      if (state.driverPlate.isNotEmpty) state.driverPlate,
    ].join('  •  ');

    return Row(
      children: [
        // Driver photo — network image with initials fallback
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: ClipOval(
            child: state.driverPhotoUrl.isNotEmpty
                ? Image.network(
                    state.driverPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _DriverInitialsAvatar(name: name),
                  )
                : _DriverInitialsAvatar(name: name),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (vehicleLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  vehicleLine,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Rating
        Row(
          children: [
            const Icon(PhosphorIconsFill.star,
                color: AppColors.starFilled, size: 18),
            const SizedBox(width: 3),
            Text(
              (state.driverRating > 0 ? state.driverRating : 4.5)
                  .toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        if (state.driverPhone.isNotEmpty) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final url = Uri.parse('tel:${state.driverPhone}');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  throw 'Could not launch dialer';
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not dial ${state.driverPhone}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsRegular.phone,
                  color: AppColors.primary, size: 18),
            ),
          ),
        ],
      ],
    );
  }
}

/// Renders initials of driver name as a coloured circle.
class _DriverInitialsAvatar extends StatelessWidget {
  final String name;
  const _DriverInitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String otp;
  final bool highlight;

  const _OtpBox({required this.otp, required this.highlight});

  @override
  Widget build(BuildContext context) {
    if (otp.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: otp));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP copied to clipboard'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(16),
          border: highlight
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              highlight ? 'Share this PIN with your driver' : 'Your ride PIN',
              style: TextStyle(
                fontSize: 13,
                color: highlight ? AppColors.primary : AppColors.textMedium,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              otp,
              style: TextStyle(
                fontSize: highlight ? 44 : 36,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primary : AppColors.textDark,
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to copy',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map back button ───────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textDark, size: 20),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/map_style.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../services/safety_service.dart';
import '../widgets/hold_to_activate_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class InTransitScreen extends StatefulWidget {
  const InTransitScreen({super.key});

  @override
  State<InTransitScreen> createState() => _InTransitScreenState();
}

class _InTransitScreenState extends State<InTransitScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _etaTimer;
  GoogleMapController? _mapController;
  CameraPosition? _currentCameraPosition;
  int _etaMinutes = 0;
  double _distanceKm = 0;
  double _progress = 0;
  int _originalEta = 0;
  final RideService _rideService = RideService();
  final SafetyService _safetyService = SafetyService();

  late AnimationController _pulseController;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _etaMinutes = state.etaMinutes;
    _originalEta = state.etaMinutes;
    _distanceKm = state.estimatedDistance;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _startPolling();
    _startEtaPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExactPath();
    });
  }

  // Poll ride status and track location every 5 s for real-time updates
  void _startPolling() {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // 1. Fetch live driver track coordinates for real-time marker updates
      try {
        final track = await _rideService.getTrack(rideId);
        if (mounted && track != null) {
          final loc = track['driverLocation'] as Map<String, dynamic>?;
          if (loc != null) {
            final lat = _toDouble(loc['lat'] ?? loc['latitude']);
            final lng = _toDouble(loc['lng'] ?? loc['longitude']);
            if (lat != 0 && lng != 0) {
              final state = context.read<AppState>();
              if (lat != state.driverLat || lng != state.driverLng) {
                state.updateDriverLocation(lat, lng, state.etaMinutes);
                _fetchExactPath(); // dynamic directions path recalculation
              }
            }
          }
        }
      } catch (_) {}

      // 2. Fetch ride details to check for status transitions (e.g. ride completed)
      final details = await _rideService.getRideDetails(rideId);
      if (!mounted || details == null) return;

      final d = details['ride'] ?? details['data'] ?? details;
      final status = (d['status'] as String?) ?? '';
      final isCompleted = status == 'ride_completed' || 
                          status == 'completed' || 
                          d['completedAt'] != null;

      if (isCompleted) {
        timer.cancel();
        _etaTimer?.cancel();
        context.read<AppState>().completeRide();
        if (mounted) Navigator.pushReplacementNamed(context, AppRouter.payment);
        return;
      }

      // 3. Fallback: Parse driver location from ride details if track update missed it
      final driver = d['driver'] as Map<String, dynamic>? ?? {};
      final lat = _toDouble(driver['lat'] ?? driver['latitude'] ?? d['driver_lat']);
      final lng = _toDouble(driver['lng'] ?? driver['longitude'] ?? d['driver_lng']);
      final state = context.read<AppState>();

      if (lat != 0 && lng != 0 && (lat != state.driverLat || lng != state.driverLng)) {
        state.updateDriverLocation(lat, lng, state.etaMinutes);
        _fetchExactPath();
      }
    });
  }

  // Poll dedicated ETA endpoint every 30 s (doc section 4.9)
  void _startEtaPolling() {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) return;

    _fetchEta(rideId); // immediate first fetch
    _etaTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchEta(rideId),
    );
  }

  Future<void> _fetchEta(String rideId) async {
    final eta = await _rideService.getEta(rideId);
    if (!mounted || eta == null) return;
    final mins = (eta['etaMinutes'] as num?)?.toInt() ?? _etaMinutes;
    final dist = (eta['distanceKm'] as num?)?.toDouble() ?? _distanceKm;
    if (_originalEta == 0 && mins > 0) _originalEta = mins;
    setState(() {
      _etaMinutes = mins;
      _distanceKm = dist;
      if (_originalEta > 0) {
        _progress = (1 - mins / _originalEta).clamp(0.0, 1.0);
      }
    });
  }

  Future<void> _fetchExactPath() async {
    final state = context.read<AppState>();
    if (state.pickupLat == 0 || state.destinationLat == 0) return;

    final routePoints = await _fetchRoute(
      LatLng(state.pickupLat, state.pickupLng),
      LatLng(state.destinationLat, state.destinationLng),
    );

    if (!mounted) return;
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints.isNotEmpty
              ? routePoints
              : [
                  LatLng(state.pickupLat, state.pickupLng),
                  LatLng(state.destinationLat, state.destinationLng),
                ],
          color: AppColors.primaryGreen,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
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
        final distanceVal = leg['distance']?['value'] as num?;

        if (durationVal != null && distanceVal != null) {
          final realTimeEta = (durationVal / 60).round();
          final realTimeDistance = distanceVal / 1000.0;

          if (mounted) {
            setState(() {
              _etaMinutes = realTimeEta > 0 ? realTimeEta : 1;
              _distanceKm = realTimeDistance;
              if (_originalEta == 0) {
                _originalEta = _etaMinutes;
              }
              if (_originalEta > 0) {
                _progress = (1 - _etaMinutes / _originalEta).clamp(0.0, 1.0);
              }
            });
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    _etaTimer?.cancel();
    _mapController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final state = context.read<AppState>();
    _currentCameraPosition = CameraPosition(
      target: LatLng(
        (state.pickupLat + state.destinationLat) / 2,
        (state.pickupLng + state.destinationLng) / 2,
      ),
      zoom: 12.5,
    );
    _fitCamera();
  }

  void _fitCamera() {
    if (_mapController == null) return;

    final state = context.read<AppState>();
    if (state.pickupLat == 0 && state.destinationLat == 0) return;

    final points = [
      LatLng(state.pickupLat, state.pickupLng),
      LatLng(state.destinationLat, state.destinationLng),
      if (state.driverLat != 0) LatLng(state.driverLat, state.driverLng),
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.004, minLng - 0.004),
          northeast: LatLng(maxLat + 0.004, maxLng + 0.004),
        ),
        80, // padding
      ),
    );
  }

  Future<void> _triggerSosAction() async {
    final state = context.read<AppState>();
    final ok = await _safetyService.triggerSos(
      rideId: state.rideId.isNotEmpty ? state.rideId : null,
      lat: state.driverLat != 0 ? state.driverLat : null,
      lng: state.driverLng != 0 ? state.driverLng : null,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '🆘 SOS activated — contacts alerted'
                : 'Failed to send SOS. Try again.',
          ),
          backgroundColor: ok ? AppColors.error : AppColors.textMedium,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Use polling values or fall back to state
    final displayEta = _etaMinutes > 0 ? _etaMinutes : state.etaMinutes;
    final displayDist = _distanceKm > 0 ? _distanceKm : state.estimatedDistance;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.home,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Map with route
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (state.pickupLat + state.destinationLat) / 2,
                  (state.pickupLng + state.destinationLng) / 2,
                ),
                zoom: 15,
              ),
              style: MapStyles.premiumStyle,
              polylines: _polylines,
              onCameraMove: (position) {
                _currentCameraPosition = position;
              },
              markers: {
                if (state.pickupLat != 0 && state.pickupLng != 0)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(state.pickupLat, state.pickupLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                if (state.destinationLat != 0 && state.destinationLng != 0)
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(
                      state.destinationLat,
                      state.destinationLng,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: const InfoWindow(title: 'Drop-off'),
                  ),
                if (state.driverLat != 0 && state.driverLng != 0)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: LatLng(state.driverLat, state.driverLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: state.driverName.isNotEmpty
                          ? state.driverName
                          : 'Driver',
                    ),
                  ),
              },
            ),

            // Back / Minimize button
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, AppRouter.home, (route) => false),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.caretDown,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
              ),
            ),

            // SOS button (floating top-right, aligned with Minimize button)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: HoldToActivateButton(
                onTriggered: _triggerSosAction,
                isCircular: true,
              ),
            ),

            // Floating map controls (Compass and Locate Me)
            Positioned(
              bottom: 370,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compass Button
                  GestureDetector(
                    onTap: () {
                      if (_mapController != null && _currentCameraPosition != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: _currentCameraPosition!.target,
                              zoom: _currentCameraPosition!.zoom,
                              bearing: 0,
                              tilt: 0,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.compass,
                        color: AppColors.textDark,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Locate Me Button
                  GestureDetector(
                    onTap: _fitCamera,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.navigationArrow,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Driver Card
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
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
                    // Drag Handle (matching searching_screen.dart)
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Elegant Trip Header (Hero-style dynamic arrival & ETA presentation)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$displayEta',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'min',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primaryGreen,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryGreen.withValues(
                                                alpha: _pulseController.value * 0.5,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: _pulseController.value * 4,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'On time  •  ${displayDist.toStringAsFixed(1)} km left',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Arrival Time Badge (matching premium capsule styling)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                PhosphorIconsRegular.clock,
                                color: AppColors.primaryGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'ARRIVAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryGreenDark,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    _formatArrivalTime(displayEta),
                                    style: const TextStyle(
                                      color: AppColors.primaryGreenDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.backgroundGrey,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Driver Details
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primaryGreen.withValues(
                            alpha: 0.12,
                          ),
                          backgroundImage: state.driverPhotoUrl.isNotEmpty
                              ? NetworkImage(state.driverPhotoUrl)
                              : null,
                          child: state.driverPhotoUrl.isEmpty
                              ? const Icon(
                                  PhosphorIconsRegular.user,
                                  color: AppColors.primaryGreen,
                                  size: 26,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.driverName.isNotEmpty ? state.driverName : 'Your Driver',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.driverVehicle}  •  ${state.driverPlate}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              PhosphorIconsFill.star,
                              color: AppColors.starFilled,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (state.driverRating > 0 ? state.driverRating : 4.5).toStringAsFixed(1),
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
                                }
                              } catch (_) {}
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsRegular.phone,
                                color: AppColors.primaryGreen,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, AppRouter.safety),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.shieldWarning,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Route Summary card (matching clean design language in searching_screen.dart)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGrey,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.white,
                                  border: Border.all(
                                    color: AppColors.primaryGreen,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 24,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: AppColors.divider,
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.pickupAddress,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  state.destinationAddress,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }

  String _formatArrivalTime(int minutes) {
    final arrivalTime = DateTime.now().add(Duration(minutes: minutes));
    final hour = arrivalTime.hour > 12
        ? arrivalTime.hour - 12
        : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
    final minuteStr = arrivalTime.minute.toString().padLeft(2, '0');
    final ampm = arrivalTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minuteStr $ampm';
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

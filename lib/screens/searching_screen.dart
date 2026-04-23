import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as lt;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/cancel_modal.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Searching for a driver screen.
///
/// Flow:
///   1. POST /ride/request → get rideId + OTP + estimatedFare
///   2. Poll GET /ride/:id every 4 s (Ably subscription is the real-time ideal,
///      but polling is used here as a fallback until Ably is wired up).
///   3. On driver assigned → navigate to DriverMatched.
///   4. Timeout after 2 min → cancel ride → back to Home.
class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  final RideService _rideService = RideService();

  late AnimationController _pulseCtrl;
  Timer? _elapsedTimer;
  Timer? _pollTimer;

  int _elapsed = 0;
  static const _timeout = 120; // seconds

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeout) _handleTimeout();
    });

    // Request the ride on first frame so context is stable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestRide());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Ride request ──────────────────────────────────────────────────────────

  Future<void> _requestRide() async {
    final state = context.read<AppState>();

    final res = await _rideService.requestRide(
      pickup: lt.LatLng(state.pickupLat, state.pickupLng),
      pickupAddress: state.pickupAddress,
      drop: lt.LatLng(state.destinationLat, state.destinationLng),
      dropAddress: state.destinationAddress,
      paymentMethod: 'cash',
    );

    if (!mounted) return;

    if (res == null) {
      _showError('Could not connect to server. Please try again.');
      return;
    }

    debugPrint('[RequestRide] response: $res');

    // Backend may wrap: { ride: {...} } or { data: {...} } or flat
    final r = res['ride'] ?? res['data'] ?? res;

    final rideId =
        (r['rideId'] ?? r['id'] ?? r['ride_id'])?.toString() ?? '';

    if (rideId.isEmpty) {
      _showError('Failed to create ride. Please try again.');
      return;
    }

    state.setRideId(rideId);

    // OTP — use ?.toString() so both String "1234" and int 1234 work
    final otp = (r['otp'] ?? r['rideOtp'] ?? r['ride_otp'])?.toString() ?? '';
    debugPrint('[RequestRide] rideId=$rideId  otp=$otp');
    if (otp.isNotEmpty) state.setOtp(otp);

    // Overwrite client-side estimate with the authoritative server fare.
    final fare =
        (r['estimatedFare'] ?? r['estimated_fare'] as num?)?.toDouble();
    if (fare != null && fare > 0) {
      state.setEstimatedFare(fare);
    }

    _startPolling(rideId);
  }

  // ── Polling (Ably fallback) ───────────────────────────────────────────────

  void _startPolling(String rideId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;

      final details = await _rideService.getRideDetails(rideId);
      if (!mounted || details == null) return;

      final actual =
          details['ride'] ?? details['data'] ?? details;
      final status = (actual['status'] as String?) ?? '';
      final driverId = actual['driver_id']?.toString() ??
          actual['driverId']?.toString() ??
          '';
      final driverObj =
          actual['driver'] as Map<String, dynamic>?;

      if (status == 'cancelled' || status == 'stale') {
        _pollTimer?.cancel();
        _elapsedTimer?.cancel();
        _showError(status == 'stale'
            ? 'No drivers found nearby. Please try again.'
            : 'Ride was cancelled.');
        return;
      }

      final driverAssigned = status == 'driver_assigned' ||
          status == 'driver_en_route' ||
          driverId.isNotEmpty ||
          (driverObj != null && driverObj.isNotEmpty);

      if (driverAssigned) {
        _pollTimer?.cancel();
        _elapsedTimer?.cancel();
        _onDriverAssigned(actual);
      }
    });
  }

  void _onDriverAssigned(Map<String, dynamic> d) {
    if (!mounted) return;
    final state = context.read<AppState>();

    debugPrint('[DriverAssigned] raw payload: $d');

    final driver = d['driver'] as Map<String, dynamic>? ?? {};
    debugPrint('[DriverAssigned] driver obj: $driver');

    // Name — try every common field name
    final name = (driver['name'] ??
            driver['fullName'] ??
            driver['full_name'] ??
            d['driverName'] ??
            d['driver_name'] ??
            'Driver')
        .toString();

    // Vehicle — backend may return string OR nested object {model, plate}
    final vehicleRaw = driver['vehicle'];
    final vehicleObj = vehicleRaw is Map<String, dynamic> ? vehicleRaw : null;
    final vehicle = vehicleObj != null
        ? (vehicleObj['model'] ?? vehicleObj['name'] ?? '').toString()
        : (vehicleRaw ?? driver['vehicleModel'] ?? driver['vehicle_model'] ??
                d['vehicle'] ?? d['vehicleModel'] ?? '')
            .toString();

    // Plate — may be in vehicle sub-object or at driver/root level
    final plate = (vehicleObj?['plate'] ??
            vehicleObj?['licensePlate'] ??
            vehicleObj?['number'] ??
            driver['plate'] ??
            driver['vehiclePlate'] ??
            driver['licensePlate'] ??
            d['plate'] ??
            '')
        .toString();

    // Rating — guard against String values from poorly typed backends
    final rating =
        ((driver['rating'] ?? driver['averageRating'] ?? d['driver_rating'] ??
                    d['driverRating']) as num?)
                ?.toDouble() ??
            4.5;

    // Phone
    final phone = (driver['phone'] ??
            driver['phoneNumber'] ??
            driver['phone_number'] ??
            d['driver_phone'] ??
            d['driverPhone'] ??
            '')
        .toString();

    // Location
    final lat =
        ((driver['lat'] ?? driver['latitude'] ?? d['driver_lat']) as num?)
                ?.toDouble() ??
            state.pickupLat;
    final lng =
        ((driver['lng'] ?? driver['longitude'] ?? d['driver_lng']) as num?)
                ?.toDouble() ??
            state.pickupLng;

    final eta =
        ((d['eta'] ?? d['etaMinutes'] ?? d['eta_minutes']) as num?)?.toInt() ??
            5;

    state.driverMatched(
      name: name,
      vehicle: vehicle,
      plate: plate,
      rating: rating,
      phone: phone,
      lat: lat,
      lng: lng,
      eta: eta,
    );

    // OTP — use ?.toString() so both String and int values work
    final otp =
        (d['otp'] ?? d['rideOtp'] ?? d['ride_otp'])?.toString() ?? '';
    debugPrint('[DriverAssigned] otp=$otp  name=$name  vehicle=$vehicle  plate=$plate  rating=$rating');
    if (otp.isNotEmpty) state.setOtp(otp);

    Navigator.pushReplacementNamed(context, AppRouter.driverMatched);
  }

  // ── Timeout / cancel ─────────────────────────────────────────────────────

  void _handleTimeout() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    if (!mounted) return;
    final state = context.read<AppState>();
    if (state.rideId.isNotEmpty) {
      _rideService.cancelRide(state.rideId, 'No drivers found');
    }
    state.cancelRide('No drivers found');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No drivers nearby. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  void _showCancelModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelModal(
        onCancel: () {
          final state = context.read<AppState>();
          _pollTimer?.cancel();
          _elapsedTimer?.cancel();
          if (state.rideId.isNotEmpty) {
            _rideService.cancelRide(state.rideId, 'User cancelled');
          }
          state.cancelRide('User cancelled');
          Navigator.of(context).pop(); // close modal
          Navigator.pushReplacementNamed(context, AppRouter.home);
        },
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  String _formatElapsed() {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          // Map background
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                state.pickupLat != 0 ? state.pickupLat : 12.9716,
                state.pickupLng != 0 ? state.pickupLng : 77.5946,
              ),
              zoom: 14,
            ),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: state.pickupLat != 0
                ? {
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: LatLng(state.pickupLat, state.pickupLng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                    )
                  }
                : {},
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pulse icon + status
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          alpha: 0.08 + _pulseCtrl.value * 0.08,
                        ),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Searching for drivers…',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usually within 5 min  •  ${_formatElapsed()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fare + payment row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${state.estimatedFare.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Text(
                                'Estimated fare',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(PhosphorIconsRegular.money,
                                  color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Cash',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Route summary
                  Row(
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
                              border: Border.all(color: AppColors.primary, width: 2.5),
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
                  const SizedBox(height: 24),

                  // Cancel
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _showCancelModal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Cancel request',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

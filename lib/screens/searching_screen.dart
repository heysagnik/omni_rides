import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as lt;
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/map_style.dart';
import '../widgets/cancel_modal.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
  static const _timeout = 120;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingId = context.read<AppState>().rideId;
      if (existingId.isNotEmpty) {
        _startPolling(existingId);
      } else {
        _requestRide();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestRide() async {
    final state = context.read<AppState>();
    final res = await _rideService.requestRide(
      pickup: lt.LatLng(state.pickupLat, state.pickupLng),
      pickupAddress: state.pickupAddress,
      drop: lt.LatLng(state.destinationLat, state.destinationLng),
      dropAddress: state.destinationAddress,
      rideType: state.selectedRideType,
      paymentMethod: state.paymentMethod.isEmpty ? 'cash' : state.paymentMethod,
      couponCode: state.appliedCoupon.isNotEmpty ? state.appliedCoupon : null,
    );

    if (!mounted) return;

    if (res == null) {
      _showError('Could not connect to server. Please try again.');
      return;
    }

    final r = res['ride'] ?? res['data'] ?? res;
    final rideId = (r['rideId'] ?? r['id'] ?? r['ride_id'])?.toString() ?? '';

    if (rideId.isEmpty) {
      _showError('Failed to create ride. Please try again.');
      return;
    }

    state.setRideId(rideId);

    final otp = (r['otp'] ?? r['rideOtp'] ?? r['ride_otp'])?.toString() ?? '';
    if (otp.isNotEmpty) state.setOtp(otp);

    final fare = _toDouble(r['estimatedFare'] ?? r['estimated_fare']);
    if (fare != null && fare > 0) state.setEstimatedFare(fare);

    _startPolling(rideId);
  }

  void _startPolling(String rideId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;

      final details = await _rideService.getRideDetails(rideId);
      if (!mounted || details == null) return;

      final actual = details['ride'] ?? details['data'] ?? details;
      final status = (actual['status'] as String?) ?? '';
      final driverId = actual['driver_id']?.toString() ?? actual['driverId']?.toString() ?? '';
      final driverObj = actual['driver'] as Map<String, dynamic>?;

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

    final driver = d['driver'] as Map<String, dynamic>? ?? {};

    final name = (driver['name'] ?? driver['fullName'] ?? driver['full_name'] ??
            d['driverName'] ?? d['driver_name'] ?? 'Driver').toString();

    final vehicleRaw = driver['vehicle'];
    final vehicleObj = vehicleRaw is Map<String, dynamic> ? vehicleRaw : null;
    final vehicle = vehicleObj != null
        ? (vehicleObj['model'] ?? vehicleObj['name'] ?? '').toString()
        : (vehicleRaw ?? driver['vehicleModel'] ?? driver['vehicle_model'] ??
                d['vehicle'] ?? d['vehicleModel'] ?? '').toString();

    final plate = (vehicleObj?['plate'] ?? vehicleObj?['licensePlate'] ?? vehicleObj?['number'] ??
            driver['plate'] ?? driver['vehiclePlate'] ?? driver['licensePlate'] ??
            d['plate'] ?? '').toString();

    final rating = _toDouble(driver['rating'] ?? driver['averageRating'] ??
                d['driver_rating'] ?? d['driverRating']) ?? 4.5;
 
    final phone = (driver['phone'] ?? driver['phoneNumber'] ?? driver['phone_number'] ??
            d['driver_phone'] ?? d['driverPhone'] ?? '').toString();
 
    final lat = _toDouble(driver['lat'] ?? driver['latitude'] ?? d['driver_lat']) ?? state.pickupLat;
    final lng = _toDouble(driver['lng'] ?? driver['longitude'] ?? d['driver_lng']) ?? state.pickupLng;

    final driverId = (driver['id'] ?? driver['driverId'] ?? d['driverId'] ?? d['driver_id'] ?? '').toString();
    if (driverId.isNotEmpty) {
      state.fetchAndSetDriverDetails(driverId);
    }

    final eta = ((d['eta'] ?? d['etaMinutes'] ?? d['eta_minutes']) as num?)?.toInt() ?? 5;

    state.driverMatched(name: name, vehicle: vehicle, plate: plate,
        rating: rating, phone: phone, lat: lat, lng: lng, eta: eta);

    final otp = (d['otp'] ?? d['rideOtp'] ?? d['ride_otp'])?.toString() ?? '';
    if (otp.isNotEmpty) state.setOtp(otp);

    Navigator.pushReplacementNamed(context, AppRouter.driverMatched);
  }

  void _handleTimeout() => _showTimeoutDialog();

  void _showTimeoutDialog() {
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('Still searching?', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'It is taking a bit longer than usual to find a driver nearby. Would you like us to keep looking for you?',
          style: TextStyle(color: AppColors.textDark, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _cancelRequestOnTimeout(); },
            child: const Text('Cancel request',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () { Navigator.pop(ctx); _extendSearch(); },
            child: const Text('Keep waiting', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _extendSearch() {
    if (!mounted) return;
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    setState(() => _elapsed = 0);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeout) _showTimeoutDialog();
    });
    final state = context.read<AppState>();
    if (state.rideId.isNotEmpty) {
      _rideService.retryMatching(state.rideId);
      _startPolling(state.rideId);
    } else {
      _requestRide();
    }
  }

  void _cancelRequestOnTimeout() {
    if (!mounted) return;
    final state = context.read<AppState>();
    if (state.rideId.isNotEmpty) _rideService.cancelRide(state.rideId, 'No drivers found');
    state.cancelRide('No drivers found');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search ended. No drivers found nearby.'), behavior: SnackBarBehavior.floating),
    );
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
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
          if (state.rideId.isNotEmpty) _rideService.cancelRide(state.rideId, 'User cancelled');
          state.cancelRide('User cancelled');
          Navigator.of(context).pop();
          Navigator.pushReplacementNamed(context, AppRouter.home);
        },
      ),
    );
  }

  String _getQueueMessage() {
    if (_elapsed < 12) return 'Requesting your ride…';
    if (_elapsed < 30) return 'Locating nearby drivers…';
    if (_elapsed < 60) return 'Matching with best options…';
    if (_elapsed < 90) return 'Negotiating fare details…';
    return 'Securing your cab driver…';
  }

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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                state.pickupLat != 0 ? state.pickupLat : 12.9716,
                state.pickupLng != 0 ? state.pickupLng : 77.5946,
              ),
              zoom: 16,
            ),
            style: MapStyles.premiumStyle,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: state.pickupLat != 0
                ? {
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: LatLng(state.pickupLat, state.pickupLng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    )
                  }
                : {},
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, -6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),

                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08 + _pulseCtrl.value * 0.08),
                      ),
                      child: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppColors.primary, size: 26),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _getQueueMessage(),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usually within 5 min  •  ${_formatElapsed()}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 16),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 140, height: 3,
                      child: LinearProgressIndicator(
                        value: (_elapsed / _timeout).clamp(0.0, 1.0),
                        backgroundColor: AppColors.divider,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.backgroundGrey, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${state.estimatedFare.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                              const Text('Final fare',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(PhosphorIconsRegular.money, color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text('Cash', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: AppColors.white,
                              border: Border.all(color: AppColors.primary, width: 2.5),
                            ),
                          ),
                          Container(width: 1.5, height: 24, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.divider),
                          Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.pickupAddress,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 18),
                            Text(state.destinationAddress,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton(
                      onPressed: _showCancelModal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }
}

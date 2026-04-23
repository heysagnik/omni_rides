import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../services/safety_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InTransitScreen extends StatefulWidget {
  const InTransitScreen({super.key});

  @override
  State<InTransitScreen> createState() => _InTransitScreenState();
}

class _InTransitScreenState extends State<InTransitScreen> {
  Timer? _pollTimer;
  Timer? _etaTimer;
  int _etaMinutes = 0;
  double _distanceKm = 0;
  double _progress = 0;
  int _originalEta = 0;
  final RideService _rideService = RideService();
  final SafetyService _safetyService = SafetyService();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _etaMinutes = state.etaMinutes;
    _originalEta = state.etaMinutes;
    _distanceKm = state.estimatedDistance;
    _startPolling();
    _startEtaPolling();
  }

  // Poll ride status every 5 s to detect ride_completed
  void _startPolling() {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) { timer.cancel(); return; }

      final details = await _rideService.getRideDetails(rideId);
      if (!mounted || details == null) return;

      final status = (details['status'] as String?) ?? '';
      if (status == 'ride_completed') {
        timer.cancel();
        _etaTimer?.cancel();
        context.read<AppState>().completeRide();
        if (mounted) Navigator.pushReplacementNamed(context, AppRouter.payment);
      }
    });
  }

  // Poll dedicated ETA endpoint every 30 s (doc section 4.9)
  void _startEtaPolling() {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) return;

    _fetchEta(rideId); // immediate first fetch
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchEta(rideId));
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

  void _showSosDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send SOS?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'This will alert your emergency contacts with your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final state = context.read<AppState>();
              final ok = await _safetyService.triggerSos(
                rideId: state.rideId.isNotEmpty ? state.rideId : null,
                lat: state.driverLat != 0 ? state.driverLat : null,
                lng: state.driverLng != 0 ? state.driverLng : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'SOS sent to emergency contacts.'
                        : 'Failed to send SOS. Try again.'),
                    backgroundColor: ok ? AppColors.error : AppColors.textMedium,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _etaTimer?.cancel();
    super.dispose();
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
              context, AppRouter.home, (route) => false);
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          // Map with route
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (state.pickupLat + state.destinationLat) / 2,
                (state.pickupLng + state.destinationLng) / 2,
              ),
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.omni.user_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(state.pickupLat, state.pickupLng),
                      LatLng(
                        state.pickupLat +
                            (state.destinationLat - state.pickupLat) * 0.3,
                        state.pickupLng +
                            (state.destinationLng - state.pickupLng) * 0.2,
                      ),
                      LatLng(
                        state.pickupLat +
                            (state.destinationLat - state.pickupLat) * 0.6,
                        state.pickupLng +
                            (state.destinationLng - state.pickupLng) * 0.8,
                      ),
                      LatLng(state.destinationLat, state.destinationLng),
                    ],
                    color: AppColors.primaryGreen,
                    strokeWidth: 5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(state.pickupLat, state.pickupLng),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                    ),
                  ),
                  Marker(
                    point: LatLng(state.destinationLat, state.destinationLng),
                    width: 28,
                    height: 28,
                    child: const Icon(
                      PhosphorIconsFill.mapPin,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  if (state.driverLat != 0)
                    Marker(
                      point: LatLng(state.driverLat, state.driverLng),
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.car,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top ETA / Distance bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 24,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.navigationArrow,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'In Transit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '~$displayEta min  •  ${displayDist.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$displayEta min',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SOS button (floating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 84,
            right: 16,
            child: GestureDetector(
              onTap: _showSosDialog,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppColors.primaryGreen.withValues(alpha: 0.15),
                        child: const Icon(
                          PhosphorIconsRegular.user,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.driverName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '${state.driverVehicle}  •  ${state.driverPlate}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(PhosphorIconsFill.star,
                              color: AppColors.starFilled, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            state.driverRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
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
                              border: Border.all(color: AppColors.primaryGreen, width: 2.5),
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
                ],
              ),
            ),
          ),
        ],
      ),
    ),   // Scaffold
    );   // PopScope
  }
}

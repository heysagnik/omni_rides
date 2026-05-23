import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../services/safety_service.dart';
import '../widgets/hold_to_activate_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InTransitScreen extends StatefulWidget {
  const InTransitScreen({super.key});

  @override
  State<InTransitScreen> createState() => _InTransitScreenState();
}

class _InTransitScreenState extends State<InTransitScreen> {
  Timer? _pollTimer;
  Timer? _etaTimer;
  GoogleMapController? _mapController;
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
      if (!mounted) {
        timer.cancel();
        return;
      }

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

  @override
  void dispose() {
    _pollTimer?.cancel();
    _etaTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
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
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
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
                zoom: 12.5,
              ),
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
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
                  width: 5,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
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

            // Top ETA / Distance bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                        horizontal: 14,
                        vertical: 8,
                      ),
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
              child: HoldToActivateButton(
                onTriggered: _triggerSosAction,
                isCircular: true,
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
                          backgroundColor: AppColors.primaryGreen.withValues(
                            alpha: 0.15,
                          ),
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
                            const Icon(
                              PhosphorIconsFill.star,
                              color: AppColors.starFilled,
                              size: 18,
                            ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }
}

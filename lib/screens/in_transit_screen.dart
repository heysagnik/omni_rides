import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';

class InTransitScreen extends StatefulWidget {
  const InTransitScreen({super.key});

  @override
  State<InTransitScreen> createState() => _InTransitScreenState();
}

class _InTransitScreenState extends State<InTransitScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Simulate ride progress
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
        // Simulate ride completion after 10 seconds
        if (_elapsedSeconds >= 10) {
          timer.cancel();
          context.read<AppState>().completeRide();
          Navigator.pushReplacementNamed(context, '/payment');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Simulate moving position along route
    double progress = (_elapsedSeconds / 10).clamp(0.0, 1.0);
    double carLat =
        state.pickupLat + (state.destinationLat - state.pickupLat) * progress;
    double carLng =
        state.pickupLng + (state.destinationLng - state.pickupLng) * progress;
    int remainingMin = ((1 - progress) * state.etaMinutes).ceil().clamp(0, 99);

    return Scaffold(
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
                userAgentPackageName: 'com.rideapp.user_app',
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
                  // Pickup marker
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
                  // Destination marker
                  Marker(
                    point: LatLng(state.destinationLat, state.destinationLng),
                    width: 28,
                    height: 28,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  // Car marker (moving)
                  Marker(
                    point: LatLng(carLat, carLng),
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
                        Icons.directions_car,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top ETA Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
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
                      Icons.navigation_rounded,
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
                          'Arriving in ~$remainingMin min',
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
                      '$remainingMin min',
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
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
                      value: progress,
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
                          Icons.person,
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
                            Icons.star_rounded,
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: AppColors.primaryGreen,
                        size: 10,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.pickupAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.destinationAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

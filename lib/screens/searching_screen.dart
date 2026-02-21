import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/cancel_modal.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with TickerProviderStateMixin {
  int _searchSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _searchSeconds++);
        // Simulate driver match after 5 seconds
        if (_searchSeconds >= 5) {
          _timer?.cancel();
          _simulateDriverMatch();
        }
      }
    });
  }

  void _simulateDriverMatch() {
    final state = context.read<AppState>();
    state.driverMatched(
      name: 'Rajesh Kumar',
      vehicle: 'Honda Activa',
      plate: 'DL 14 AB 1234',
      rating: 4.7,
      phone: '+91 98765 43210',
      lat: state.pickupLat + 0.005,
      lng: state.pickupLng + 0.003,
      eta: 4,
    );
    Navigator.pushReplacementNamed(context, '/driver-matched');
  }

  void _showCancelModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CancelModal(
        onCancel: () {
          context.read<AppState>().cancelRide('User cancelled during search');
          Navigator.of(ctx).pop();
          Navigator.pushReplacementNamed(context, '/home');
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(state.pickupLat, state.pickupLng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rideapp.user_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(state.pickupLat, state.pickupLng),
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Bottom Sheet
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search animation
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withValues(
                            alpha: 0.1 + (_pulseCtrl.value * 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryGreen,
                          size: 28,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Searching for drivers',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Drivers respond within 5 min  •  ${_formatTime(_searchSeconds)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fare display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      borderRadius: BorderRadius.circular(16),
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '1 passenger  •  Cash',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Fare Adjust
                        Row(
                          children: [
                            _FareAdjustButton(
                              icon: Icons.remove,
                              onTap: () => state.adjustFare(-10),
                            ),
                            const SizedBox(width: 8),
                            _FareAdjustButton(
                              icon: Icons.add,
                              onTap: () => state.adjustFare(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Route summary
                  _RouteSummaryRow(
                    icon: Icons.circle,
                    iconColor: AppColors.primaryGreen,
                    iconSize: 10,
                    text: state.pickupAddress,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      width: 2,
                      height: 20,
                      color: AppColors.divider,
                    ),
                  ),
                  _RouteSummaryRow(
                    icon: Icons.location_on,
                    iconColor: AppColors.error,
                    iconSize: 18,
                    text: state.destinationAddress,
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _showCancelModal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                          color: AppColors.error,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _FareAdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FareAdjustButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textDark, size: 20),
      ),
    );
  }
}

class _RouteSummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String text;

  const _RouteSummaryRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/ride_service.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    setState(() => _isLoading = true);

    final rideService = RideService();
    final rides = await rideService.getRideHistory();

    if (mounted) {
      if (rides != null && rides.isNotEmpty) {
        context.read<AppState>().setRideHistory(rides);
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textDark,
        ),
        title: const Text(
          'Activity',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.6,
          ),
        ),
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.rideHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_outlined,
                      size: 40,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No rides yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your ride history will appear here',
                    style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: state.rideHistory.length,
              itemBuilder: (_, i) => _RideHistoryCard(ride: state.rideHistory[i]),
            ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  final Map<String, dynamic> ride;

  const _RideHistoryCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        ride['status'] == 'cancelled' || ride['status'] == 'stale';
    final isCompleted = ride['status'] == 'ride_completed';
    // Use completed_at if completed, otherwise created_at (or just created_at)
    final dateStr = _formatDate(ride['created_at'] ?? '');
    final timeStr = _formatTime(ride['created_at'] ?? '');
    final double distance = _parseDouble(ride['distance']);
    final double fare = _parseDouble(
      ride['final_fare'] ??
      ride['finalFare'] ??
      ride['estimated_fare'] ??
      ride['estimatedFare']
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date, time, distance + Status badge + Fare
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & time/distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$timeStr • ${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.error.withValues(alpha: 0.08)
                        : (isCompleted
                              ? AppColors.primaryGreen.withValues(alpha: 0.08)
                              : Colors.orange.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCancelled
                        ? 'Cancelled'
                        : (isCompleted ? 'Completed' : 'Unknown'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCancelled
                          ? AppColors.error
                          : (isCompleted
                                ? AppColors.primaryGreen
                                : Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Fare
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
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
                        ride['pickup_address'] ?? ride['pickupAddress'] ?? 'Unknown Pickup',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 18),
                      // Divider(height: 24, color: AppColors.divider),
                      Text(
                        ride['drop_address'] ?? ride['dropAddress'] ?? 'Unknown Drop',
                        style: const TextStyle(
                          fontSize: 14,
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
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatTime(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $amPm';
    } catch (_) {
      return '';
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

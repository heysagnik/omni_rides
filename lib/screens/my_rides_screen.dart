import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

  String _getGroupHeader(String isoDate) {
    if (isoDate.isEmpty) return 'Other';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final rideDate = DateTime(dt.year, dt.month, dt.day);
      
      if (rideDate == today) {
        return 'Today';
      } else if (rideDate == yesterday) {
        return 'Yesterday';
      } else {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
      }
    } catch (_) {
      return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Group rides by date header dynamically
    final Map<String, List<Map<String, dynamic>>> groupedRides = {};
    for (final rawRide in state.rideHistory) {
      final createdAt = rawRide['created_at'] ?? rawRide['createdAt'] ?? '';
      final header = _getGroupHeader(createdAt.toString());
      if (!groupedRides.containsKey(header)) {
        groupedRides[header] = [];
      }
      groupedRides[header]!.add(rawRide);
    }

    final List<dynamic> listItems = [];
    groupedRides.forEach((header, rides) {
      listItems.add(header);
      listItems.addAll(rides);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(PhosphorIconsRegular.caretLeft, size: 24),
            color: AppColors.textDark,
          ),
        ),
        title: const Text('Activity'),
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
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3EC),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.carProfile,
                      size: 44,
                      color: Color(0xFF1C683C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No rides yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your ride history will appear here\nonce you complete a trip.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                final item = listItems[index];
                if (item is String) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
                    child: Text(
                      item.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMedium,
                        letterSpacing: 0.8,
                      ),
                    ),
                  );
                } else {
                  return _RideHistoryCard(ride: item as Map<String, dynamic>);
                }
              },
            ),
    );
  }
}

class _RideHistoryCard extends StatefulWidget {
  final Map<String, dynamic> ride;

  const _RideHistoryCard({required this.ride});

  @override
  State<_RideHistoryCard> createState() => _RideHistoryCardState();
}

class _RideHistoryCardState extends State<_RideHistoryCard> {
  Map<String, dynamic>? _driverDetails;
  bool _loadingDriver = false;

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();
  }

  Future<void> _fetchDriverDetails() async {
    final driverId = (widget.ride['driverId'] ?? widget.ride['driver_id'] ?? '').toString();
    if (driverId.isEmpty) return;

    setState(() => _loadingDriver = true);
    final details = await RideService().getDriverDetails(driverId);
    if (mounted) {
      setState(() {
        _driverDetails = details;
        _loadingDriver = false;
      });
      debugPrint('[DriverDetails] Raw response for driver $driverId: $details');
    }
  }

  double _approxDistanceKm(double pLat, double pLng, double dLat, double dLng) {
    final dLatDiff = (dLat - pLat).abs();
    final dLngDiff = (dLng - pLng).abs();
    return ((dLatDiff + dLngDiff) * 111).clamp(1.0, 500.0);
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        widget.ride['status'] == 'cancelled' || widget.ride['status'] == 'stale';
    final isCompleted = widget.ride['status'] == 'ride_completed';
    // Use completed_at if completed, otherwise created_at (or just created_at)
    final timeStr = _formatTime(widget.ride['created_at'] ?? '');

    // Parse coordinates robustly (handling nested maps or flat keys)
    final double pLat = _parseDouble(
      widget.ride['pickupLat'] ??
      widget.ride['pickup_lat'] ??
      widget.ride['pickupLatitude'] ??
      widget.ride['pickup_latitude'] ??
      (widget.ride['pickup'] is Map ? (widget.ride['pickup']['lat'] ?? widget.ride['pickup']['latitude']) : 0.0)
    );
    final double pLng = _parseDouble(
      widget.ride['pickupLng'] ??
      widget.ride['pickup_lng'] ??
      widget.ride['pickupLongitude'] ??
      widget.ride['pickup_longitude'] ??
      (widget.ride['pickup'] is Map ? (widget.ride['pickup']['lng'] ?? widget.ride['pickup']['longitude']) : 0.0)
    );
    final double dLat = _parseDouble(
      widget.ride['dropLat'] ??
      widget.ride['drop_lat'] ??
      widget.ride['dropLatitude'] ??
      widget.ride['drop_latitude'] ??
      (widget.ride['drop'] is Map ? (widget.ride['drop']['lat'] ?? widget.ride['drop']['latitude']) : 0.0)
    );
    final double dLng = _parseDouble(
      widget.ride['dropLng'] ??
      widget.ride['drop_lng'] ??
      widget.ride['dropLongitude'] ??
      widget.ride['drop_longitude'] ??
      (widget.ride['drop'] is Map ? (widget.ride['drop']['lng'] ?? widget.ride['drop']['longitude']) : 0.0)
    );

    // Safely extract distance or fall back to calculation
    double distance = _parseDouble(
      widget.ride['distance'] ??
      widget.ride['estimatedDistance'] ??
      widget.ride['estimated_distance'] ??
      widget.ride['distanceKm'] ??
      widget.ride['distance_km'] ??
      widget.ride['distance_in_km'],
    );
    if (distance == 0.0 && pLat != 0.0 && dLat != 0.0) {
      distance = _approxDistanceKm(pLat, pLng, dLat, dLng);
    }

    // Diagnostic print to verify distance and coordinates parsing in runtime logs
    debugPrint('[ActivityHistory] Ride ID: ${widget.ride['id']} Status: ${widget.ride['status']} Coordinates: pickup($pLat, $pLng), drop($dLat, $dLng), distance: $distance km');

    final double fare = _parseDouble(
      widget.ride['final_fare'] ??
          widget.ride['finalFare'] ??
          widget.ride['estimated_fare'] ??
          widget.ride['estimatedFare'],
    );

    // Robust parsing for driver details returned from the GET /api/ride/driver/:driverId endpoint
    final driverName = (_driverDetails?['fullName'] ?? _driverDetails?['name'] ?? '').toString().trim();
    final driverPhoto = (_driverDetails?['photoUrl'] ?? _driverDetails?['photo_url'] ?? '').toString();
    final driverRating = _parseDouble(
      _driverDetails?['rating'] ??
      _driverDetails?['averageRating'] ??
      _driverDetails?['average_rating'] ??
      _driverDetails?['avg_rating'] ??
      _driverDetails?['driverRating'] ??
      _driverDetails?['driver_rating'] ??
      _driverDetails?['stars'],
    );
    final bool hasRating = _driverDetails != null && (
      _driverDetails!.containsKey('rating') ||
      _driverDetails!.containsKey('averageRating') ||
      _driverDetails!.containsKey('average_rating') ||
      _driverDetails!.containsKey('avg_rating') ||
      _driverDetails!.containsKey('driverRating') ||
      _driverDetails!.containsKey('driver_rating') ||
      _driverDetails!.containsKey('stars')
    ) && driverRating > 0;

    // Map payment method labels
    final String paymentMethod = (widget.ride['paymentMethod'] ?? widget.ride['payment_method'] ?? 'cash').toString().toLowerCase();
    String paymentLabel = 'Cash';
    if (paymentMethod == 'upi') {
      paymentLabel = 'UPI';
    } else if (paymentMethod == 'card') {
      paymentLabel = 'Card';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status badge (left) | Price (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(widget.ride['status'] ?? ''),
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Time — full width, left-aligned
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            if (distance > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${distance.toStringAsFixed(1)} km • Paid via $paymentLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Simplistic Timeline (Pickup -> Drop)
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      color: AppColors.divider,
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ride['pickup_address'] ??
                            widget.ride['pickupAddress'] ??
                            'Unknown Pickup',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.ride['drop_address'] ??
                            widget.ride['dropAddress'] ??
                            'Unknown Destination',
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

            // Inline Driver and Rebook section (very simple, single line)
            if (_loadingDriver || driverName.isNotEmpty || isCompleted || isCancelled) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 0.8, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_loadingDriver) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textMedium),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Loading driver…',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ] else if (driverName.isNotEmpty) ...[
                    // Compact Driver details
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.backgroundGrey,
                      ),
                      child: ClipOval(
                        child: driverPhoto.isNotEmpty
                            ? Image.network(
                                driverPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _DriverInitials(name: driverName),
                              )
                            : _DriverInitials(name: driverName),
                      ),
                    ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Expanded(
                             child: Text(
                               driverName,
                               style: const TextStyle(
                                 fontSize: 13,
                                 fontWeight: FontWeight.w600,
                                 color: AppColors.textDark,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           if (hasRating) ...[
                             const SizedBox(width: 8),
                             const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                             const SizedBox(width: 2),
                             Text(
                               driverRating.toStringAsFixed(1),
                               style: const TextStyle(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w700,
                                 color: AppColors.textDark,
                               ),
                             ),
                           ],
                         ],
                       ),
                     ),
                   ] else ...[
                    const Spacer(),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isCancelled = status == 'cancelled' || status == 'stale';
    final isCompleted = status == 'ride_completed';

    String text = 'Active';
    Color color = const Color(0xFF1C683C);
    Color bgColor = const Color(0xFFE8F3EC);

    if (isCompleted) {
      text = 'Completed';
      color = AppColors.primaryDark;
      bgColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (isCancelled) {
      text = 'Cancelled';
      color = AppColors.error;
      bgColor = AppColors.error.withValues(alpha: 0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
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

class _DriverInitials extends StatelessWidget {
  final String name;
  const _DriverInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

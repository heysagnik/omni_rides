import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ServiceSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const ServiceSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const List<Map<String, dynamic>> services = [
    {
      'id': 'ride',
      'label': 'Passenger\nRide',
      'icon': Icons.directions_car_rounded,
    },
    {'id': 'food', 'label': 'Food\nDelivery', 'icon': Icons.restaurant_rounded},
    {
      'id': 'parcel',
      'label': 'Home\nParcel',
      'icon': Icons.inventory_2_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = services[index];
          final isActive = selected == service['id'];
          return GestureDetector(
            onTap: () => onSelected(service['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 105,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? AppColors.primaryGreen : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    service['icon'] as IconData,
                    size: 32,
                    color: isActive
                        ? AppColors.primaryGreen
                        : AppColors.textMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? AppColors.primaryGreen
                          : AppColors.textMedium,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

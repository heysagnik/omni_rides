import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PlaceItem {
  final String name;
  final String subtitle;
  final IconData icon;
  const PlaceItem(this.name, this.subtitle, this.icon);
}

class LocateFab extends StatelessWidget {
  final VoidCallback onTap;
  const LocateFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x28000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: AppColors.primary, size: 20),
      ),
    );
  }
}

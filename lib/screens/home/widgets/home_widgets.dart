import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PlaceItem {
  final String name;
  final String subtitle;
  final IconData icon;
  final double? lat;
  final double? lng;

  const PlaceItem(
    this.name,
    this.subtitle,
    this.icon, {
    this.lat,
    this.lng,
  });
}

class LocateFab extends StatefulWidget {
  final VoidCallback onTap;
  const LocateFab({super.key, required this.onTap});

  @override
  State<LocateFab> createState() => _LocateFabState();
}

class _LocateFabState extends State<LocateFab> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) {
        setState(() => _isTapped = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isTapped = false),
      child: AnimatedScale(
        scale: _isTapped ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF111111).withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

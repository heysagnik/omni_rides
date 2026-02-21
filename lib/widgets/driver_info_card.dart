import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DriverInfoCard extends StatelessWidget {
  final String name;
  final String vehicle;
  final String plate;
  final double rating;
  final String? otp;
  final VoidCallback? onCall;

  const DriverInfoCard({
    super.key,
    required this.name,
    required this.vehicle,
    required this.plate,
    required this.rating,
    this.otp,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$vehicle  •  $plate',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.starFilled,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  if (onCall != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onCall,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (otp != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Share this OTP with your driver',
                    style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    otp!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                      letterSpacing: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

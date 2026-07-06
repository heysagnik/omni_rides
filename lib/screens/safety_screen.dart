import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            PhosphorIconsRegular.caretLeft,
            color: AppColors.textDark,
          ),
        ),
        title: const Text('Safety'),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Assistance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quick access to emergency services',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // ── Quick Actions ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_police_rounded,
                    label: 'Call Police',
                    subtitle: '112',
                    color: AppColors.error,
                    onTap: () => _showCallSnack(context, 'Police', '112'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_hospital_rounded,
                    label: 'Ambulance',
                    subtitle: '108',
                    color: AppColors.warning,
                    onTap: () => _showCallSnack(context, 'Ambulance', '108'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Safety Tips ───────────────────────────────────────────────
            const Text(
              'Safety Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            const _SafetyTip(
              icon: Icons.pin_rounded,
              title: 'Verify OTP',
              description:
                  'Always match the 4-digit OTP with your driver before boarding.',
            ),
            const _SafetyTip(
              icon: Icons.share_rounded,
              title: 'Share your ride details',
              description:
                  'Share your vehicle number and driver info with family or friends.',
            ),
            const _SafetyTip(
              icon: Icons.route_rounded,
              title: 'Follow the route',
              description:
                  'Monitor the route on your map to ensure the driver stays on track.',
            ),
            const _SafetyTip(
              icon: Icons.nightlight_round,
              title: 'Night safety',
              description:
                  'Prefer well-lit pickup/drop points and sit in the back seat at night.',
            ),
          ],
        ),
      ),
    );
  }

  void _showCallSnack(
    BuildContext context,
    String service,
    String number,
  ) async {
    final url = Uri.parse('tel:$number');
    try {
      await launchUrl(url);
    } catch (_) {
      // Ignored
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SafetyTip({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

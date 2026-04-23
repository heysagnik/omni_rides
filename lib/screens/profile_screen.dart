import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../routes/app_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final data = await _authService.getCustomerProfile();
    if (!mounted || data == null) return;
    final state = context.read<AppState>();
    final name = data['full_name'] as String? ?? data['fullName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    if (name.isNotEmpty || email.isNotEmpty || phone.isNotEmpty) {
      state.setUserInfo(
        name: name.isNotEmpty ? name : state.userName,
        phone: phone.isNotEmpty ? phone : state.userPhone,
        email: email.isNotEmpty ? email : state.userEmail,
      );
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
          'Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.6,
          ),
        ),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.user,
                            size: 30,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.userName.isNotEmpty ? state.userName : 'Your Name',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                state.userEmail.isNotEmpty
                                    ? state.userEmail
                                    : state.userPhone.isNotEmpty
                                        ? state.userPhone
                                        : 'Tap to edit profile',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.star, color: AppColors.starFilled, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          state.userRating.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Rider rating',
                          style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Activity + other menu items
            _buildSection([
              _MenuItem(
                icon: PhosphorIconsRegular.clockCounterClockwise,
                label: 'Activity',
                iconColor: const Color(0xFF6C63FF),
                onTap: () => Navigator.pushNamed(context, AppRouter.myRides),
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.shield,
                label: 'Safety center',
                iconColor: AppColors.primary,
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.question,
                label: 'Help & support',
                iconColor: AppColors.info,
              ),
              _MenuItem(
                icon: PhosphorIconsRegular.info,
                label: 'About Omni',
                iconColor: AppColors.textMedium,
              ),
            ]),

            const SizedBox(height: 16),

            // Logout
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: _buildMenuTile(
                icon: PhosphorIconsRegular.signOut,
                label: 'Sign out',
                iconColor: AppColors.error,
                textColor: AppColors.error,
                showChevron: false,
                onTap: () async {
                  final authService = AuthService();
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppRouter.authOptions, (route) => false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: AppColors.divider),
            _buildMenuTile(
              icon: items[i].icon,
              label: items[i].label,
              iconColor: items[i].iconColor,
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    Color textColor = AppColors.textDark,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (showChevron)
              const Icon(PhosphorIconsRegular.caretRight, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.onTap,
  });
}

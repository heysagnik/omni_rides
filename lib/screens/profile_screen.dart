import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String _version = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  Future<void> _loadProfile() async {
    final data = await _authService.getCustomerProfile();
    if (!mounted || data == null) return;
    final state = context.read<AppState>();
    final name =
        data['full_name'] as String? ?? data['fullName'] as String? ?? '';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.home,
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.home,
                (route) => false,
              ),
              icon: const Icon(PhosphorIconsRegular.caretLeft, size: 24),
              color: AppColors.textDark,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: () {}, // Edit action
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          child: Column(
            children: [
              // Profile Card
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                            AppColors.accent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: Consumer<AppState>(
                            builder: (_, s, __) => s.userPhotoUrl.isNotEmpty
                                ? Image.network(
                                    s.userPhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _AvatarFallback(name: s.userName),
                                  )
                                : _AvatarFallback(name: s.userName),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.userName.isNotEmpty ? state.userName : 'Your Name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.userEmail.isNotEmpty
                          ? state.userEmail
                          : state.userPhone.isNotEmpty
                          ? state.userPhone
                          : 'Add profile details',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Activity + other menu items
              _buildSection([
                _MenuItem(
                  icon: PhosphorIconsRegular.clockCounterClockwise,
                  label: 'Activity',
                  iconColor: const Color(0xFF1C683C),
                  bgColor: const Color(0xFFE8F3EC),
                  onTap: () => Navigator.pushNamed(context, AppRouter.myRides),
                ),
                _MenuItem(
                  icon: PhosphorIconsRegular.shieldCheck,
                  label: 'Safety center',
                  iconColor: const Color(0xFF00B4D8),
                  bgColor: const Color(0xFFE5F7FA),
                  onTap: () => Navigator.pushNamed(context, AppRouter.safety),
                ),
                _MenuItem(
                  icon: PhosphorIconsRegular.headset,
                  label: 'Help & support',
                  iconColor: const Color(0xFFFF9F1C),
                  bgColor: const Color(0xFFFFF5E5),
                ),
                _MenuItem(
                  icon: PhosphorIconsRegular.info,
                  label: 'About Omni',
                  iconColor: const Color(0xFF1C683C),
                  bgColor: const Color(0xFFE8F3EC),
                ),
              ]),

              const SizedBox(height: 24),

              // Logout
              _buildSection([
                _MenuItem(
                  icon: PhosphorIconsRegular.signOut,
                  label: 'Sign out',
                  iconColor: const Color(0xFFFF4D4D),
                  bgColor: const Color(0xFFFFECEC),
                  showChevron: false,
                  onTap: () async {
                    final authService = AuthService();
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.authOptions,
                        (route) => false,
                      );
                    }
                  },
                ),
              ]),

              if (_version.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  _version,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 72,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            _buildMenuTile(
              icon: items[i].icon,
              label: items[i].label,
              iconColor: items[i].iconColor,
              bgColor: items[i].bgColor,
              showChevron: items[i].showChevron,
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
    required Color bgColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (showChevron)
              const Icon(
                PhosphorIconsRegular.caretRight,
                color: AppColors.textLight,
                size: 20,
              ),
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
  final Color bgColor;
  final bool showChevron;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    this.showChevron = true,
    this.onTap,
  });
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

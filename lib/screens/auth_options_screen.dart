import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthOptionsScreen extends StatefulWidget {
  const AuthOptionsScreen({super.key});

  @override
  State<AuthOptionsScreen> createState() => _AuthOptionsScreenState();
}

class _AuthOptionsScreenState extends State<AuthOptionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  bool _isLoading = false;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animCtrl,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final authService = AuthService();
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (result == null) {
      // User cancelled or sign-in failed
      setState(() => _isLoading = false);
      return;
    }

    // Sync with backend and route based on isNewUser
    final appState = context.read<AppState>();
    final route = await appState.syncWithBackend();

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (route) {
      case 'new_user':
        Navigator.pushNamedAndRemoveUntil(
            context, AppRouter.login, (r) => false);
        break;
      case 'home':
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (r) => false);
        break;
      default:
        // Backend unreachable but Firebase auth succeeded — go home
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // Brand mark
              FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_taxi_rounded,
                        size: 30,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Get in,\nlet\'s ride.',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1.1,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fair fares, no surge pricing.\nChoose rides that are right for you.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMedium,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // CTA buttons
              SlideTransition(
                position: _slideUp,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    children: [
                      // Google Sign-In
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textDark,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.network(
                                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                      width: 20,
                                      height: 20,
                                      placeholderBuilder: (BuildContext context) => const Icon(
                                        Icons.g_mobiledata_rounded,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
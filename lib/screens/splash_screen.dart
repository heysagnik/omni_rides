import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../services/update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppState>();

    final results = await Future.wait([
      appState.syncWithBackend(),
      Future.delayed(const Duration(milliseconds: 1800)),
      _prefetchLocation(appState),
    ]);

    if (!mounted) return;

    // Check for app updates — blocks navigation if force update is required
    final canContinue = await UpdateService.checkAndPrompt(context);
    if (!canContinue || !mounted) return;

    final route = results[0] as String;

    if (route == 'needs_phone') {
      Navigator.pushReplacementNamed(context, AppRouter.addPhone);
      return;
    }

    if (route == 'home') {
      final activeRideRoute = await appState.checkAndRestoreActiveRide();
      if (!mounted) return;
      switch (activeRideRoute) {
        case 'searching':
          Navigator.pushReplacementNamed(context, AppRouter.searching);
          return;
        case 'driverMatched':
          Navigator.pushReplacementNamed(context, AppRouter.driverMatched);
          return;
        case 'inTransit':
          Navigator.pushReplacementNamed(context, AppRouter.inTransit);
          return;
      }
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } else if (route == 'new_user') {
      Navigator.pushReplacementNamed(context, AppRouter.login);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.authOptions);
    }
  }

  Future<void> _prefetchLocation(AppState appState) async {
    try {
      if (appState.currentLat != 0) return;
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) return;
      final addr = await LocationService.getAddressFromLatLng(pos.latitude, pos.longitude);
      appState.updateCurrentLocation(pos.latitude, pos.longitude, addr.isNotEmpty ? addr : 'Current Location');
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const OmniLogoMark(size: 180),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    Opacity(
                      opacity: _taglineFade.value,
                      child: Text(
                        'Fair rides, every time.',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom loader
              Positioned(
                bottom: 56,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _taglineFade.value,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reusable Omni logo mark — pill outline + "Omni" wordmark.
/// Matches logo_user_final.svg exactly.
class OmniLogoMark extends StatelessWidget {
  final double size;
  const OmniLogoMark({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final pillWidth = size;
    final pillHeight = size * 0.34;
    final pillRadius = pillHeight / 2;
    final strokeWidth = size * 0.085;
    final wordmarkSize = size * 0.28;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: pillWidth,
          height: pillHeight,
          child: CustomPaint(
            painter: _PillPainter(
              strokeWidth: strokeWidth,
              radius: pillRadius,
            ),
          ),
        ),
        SizedBox(height: size * 0.12),
        Text(
          'Omni',
          style: GoogleFonts.dmSans(
            fontSize: wordmarkSize,
            fontWeight: FontWeight.w400,
            color: AppColors.white,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _PillPainter extends CustomPainter {
  final double strokeWidth;
  final double radius;

  _PillPainter({required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _PillPainter old) =>
      old.strokeWidth != strokeWidth || old.radius != radius;
}


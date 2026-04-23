import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';

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

    // Run auth + location fetch in parallel; minimum 1.8s for the animation
    final results = await Future.wait([
      appState.syncWithBackend(),
      Future.delayed(const Duration(milliseconds: 1800)),
      _prefetchLocation(appState),
    ]);
    if (!mounted) return;

    final route = results[0] as String;

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
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // Background pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.06,
                  child: CustomPaint(painter: _DotPatternPainter()),
                ),
              ),

              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Column(
                          children: [
                            const OmniLogoMark(size: 96),
                            const SizedBox(height: 24),
                            const Text(
                              'OMNI',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: AppColors.white,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tagline
                    Opacity(
                      opacity: _taglineFade.value,
                      child: Text(
                        'Fair rides, every time.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.primary.withValues(alpha: 0.9),
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
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary.withValues(alpha: 0.7),
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

// Reusable logo mark — white hexagon + green "O" ring — used on splash & app icon
class OmniLogoMark extends StatelessWidget {
  final double size;
  const OmniLogoMark({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoMarkPainter()),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // White circle background
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // Green ring
    final ringPaint = Paint()
      ..color = const Color(0xFF00A86B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r * 0.55, ringPaint);

    // Green dot at top of ring (speed notch — like a car nav arrow)
    final dotPaint = Paint()..color = const Color(0xFF00A86B);
    canvas.drawCircle(Offset(cx, cy - r * 0.55), r * 0.12, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
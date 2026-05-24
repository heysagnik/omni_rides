import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/star_rating.dart';
import '../widgets/primary_button.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with TickerProviderStateMixin {
  int _rating = 0;
  bool _submitted = false;
  final TextEditingController _commentController = TextEditingController();

  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _checkCtrl.forward();
        _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _fadeCtrl.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_rating == 0) return;
    
    setState(() => _submitted = true);
    
    final state = context.read<AppState>();
    final rideService = RideService();
    
    final rideId = state.rideId;
    if (rideId.isNotEmpty) {
      final fullComment = _commentController.text.trim();
      await rideService.rateRide(rideId, _rating, fullComment);
    }
    
    // Also save locally
    state.submitRating(_rating);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
      }
    });
  }

  void _skip() {
    context.read<AppState>().resetRide();
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPositive = _rating >= 4;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Top App Bar / Skip Row
                      if (!_submitted)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textMedium,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 48),

                      const Spacer(flex: 1),

                      // Animated Checkmark or Driver Profile Card
                      if (_submitted) ...[
                        ScaleTransition(
                          scale: _checkScale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryGreen,
                                  AppColors.primaryGreenLight,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 56,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        // Driver Info Card Redesign
                        FadeTransition(
                          opacity: _fadeCtrl,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.textDark.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Avatar Frame
                                    Container(
                                      width: 64,
                                      height: 64,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [AppColors.primary, AppColors.accent],
                                        ),
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: ClipOval(
                                          child: state.driverPhotoUrl.isNotEmpty
                                              ? Image.network(
                                                  state.driverPhotoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _DriverAvatarFallback(name: state.driverName),
                                                )
                                              : _DriverAvatarFallback(name: state.driverName),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Driver Text Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            state.driverName.isNotEmpty ? state.driverName : 'Your Driver',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${state.driverVehicle} • ${state.driverPlate}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMedium,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Driver Rating Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                                          const SizedBox(width: 4),
                                          Text(
                                            state.driverRating > 0 ? state.driverRating.toStringAsFixed(1) : '4.8',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.accentDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Rating Header Label
                      FadeTransition(
                        opacity: _fadeCtrl,
                        child: Text(
                          _submitted ? 'Thank You!' : 'Ride Complete',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _fadeCtrl,
                        child: Text(
                          _submitted
                              ? 'Your feedback helps improve the community.'
                              : 'How was your trip today?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const Spacer(flex: 1),

                      if (!_submitted) ...[
                        // Star Rating Input
                        FadeTransition(
                          opacity: _fadeCtrl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                StarRating(
                                  rating: _rating,
                                  size: 46,
                                  onRatingChanged: (r) {
                                    setState(() {
                                      _rating = r;
                                    });
                                  },
                                ),
                                if (_rating > 0) ...[
                                  const SizedBox(height: 12),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      _getRatingText(_rating),
                                      key: ValueKey(_rating),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isPositive ? AppColors.primaryDark : AppColors.accentDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Custom Comments Field (Visible only when rating > 0)
                        if (_rating > 0) ...[
                          const SizedBox(height: 16),
                          FadeTransition(
                            opacity: _fadeCtrl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Additional feedback (optional)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _commentController,
                                    maxLines: 3,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Tell us more about your experience...',
                                      hintStyle: const TextStyle(
                                        color: AppColors.textMedium,
                                        fontSize: 13,
                                      ),
                                      contentPadding: const EdgeInsets.all(14),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                        Icons.rate_review_outlined,
                                        color: AppColors.textMedium.withValues(alpha: 0.6),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      const Spacer(flex: 2),

                      // Actions Button
                      if (!_submitted)
                        FadeTransition(
                          opacity: _fadeCtrl,
                          child: PrimaryButton(
                            text: 'Submit Feedback',
                            onPressed: _rating > 0 ? _submit : () {},
                            backgroundColor: _rating > 0 ? null : AppColors.border,
                            textColor: _rating > 0 ? null : AppColors.textMedium.withValues(alpha: 0.5),
                          ),
                        )
                      else ...[
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Redirecting home...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor 😞';
      case 2:
        return 'Below Average 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Very Good 😊';
      case 5:
        return 'Excellent! 🌟';
      default:
        return '';
    }
  }
}

class _DriverAvatarFallback extends StatelessWidget {
  final String name;
  const _DriverAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

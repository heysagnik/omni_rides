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
    super.dispose();
  }

  void _submit() async {
    if (_rating == 0) return;
    
    // Show a loading state if we want, or just wait locally
    setState(() => _submitted = true);
    
    final state = context.read<AppState>();
    final rideService = RideService();
    
    // Use the live rideId from state — this is the real backend UUID
    final rideId = state.rideId;
    if (rideId.isNotEmpty) {
      rideService.rateRide(rideId, _rating, null);
    }
    
    // Also save locally
    state.submitRating(_rating);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Success Checkmark
                    ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
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
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 64,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _fadeCtrl,
                      child: Column(
                        children: [
                          Text(
                            _submitted ? 'Thanks!' : 'Ride complete',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _submitted
                                ? 'Redirecting to home...'
                                : 'How was your ride with ${state.driverName.isNotEmpty ? state.driverName : "your driver"}?',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (!_submitted) ...[
                      // Star Rating
                      FadeTransition(
                        opacity: _fadeCtrl,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGrey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Rate your driver',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              StarRating(
                                rating: _rating,
                                size: 40,
                                onRatingChanged: (r) =>
                                    setState(() => _rating = r),
                              ),
                              if (_rating > 0) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _getRatingText(_rating),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    if (!_submitted)
                      FadeTransition(
                        opacity: _fadeCtrl,
                        child: PrimaryButton(
                          text: 'Submit',
                          onPressed: _submit,
                        ),
                      ),
                    if (_submitted)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
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

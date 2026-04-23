import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  bool _isConfirming = false;
  bool _isPaid = false;
  double _finalFare = 0; // authoritative amount from GET /payment/:rideId

  late AnimationController _animCtrl;
  final RideService _rideService = RideService();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fetchPaymentDetails();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentDetails() async {
    final state = context.read<AppState>();
    final rideId = state.rideId;
    if (rideId.isEmpty) return;

    final payment = await _rideService.getPaymentDetails(rideId);
    if (!mounted || payment == null) return;

    final paymentId = payment['id'] as String? ?? '';
    if (paymentId.isNotEmpty) state.setPaymentId(paymentId);

    // Use the authoritative amount from the payment record
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    if (amount > 0 && mounted) {
      setState(() => _finalFare = amount);
    }
  }

  Future<void> _confirmCashPayment() async {
    setState(() => _isConfirming = true);

    final state = context.read<AppState>();
    state.setPaymentMethod('cash');

    final paymentId = state.paymentId;
    if (paymentId.isNotEmpty) {
      await _rideService.confirmPayment(paymentId);
    }

    if (!mounted) return;
    setState(() {
      _isConfirming = false;
      _isPaid = true;
    });

    // Brief pause then go to rating
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Prefer the authoritative backend amount; fall back to estimated while loading
    final displayFare = _finalFare > 0 ? _finalFare : state.estimatedFare;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _animCtrl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            size: 40,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          "You've arrived!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Please pay the driver',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Fare Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ride Fare',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMedium)),
                                Text(
                                  '₹${displayFare.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Distance',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMedium)),
                                Text(
                                  '${state.estimatedDistance.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  '₹${displayFare.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Payment method — Cash only
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primaryGreen, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.money_rounded,
                                  color: AppColors.primaryGreen, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cash Payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Pay cash directly to your driver',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle,
                                color: AppColors.primaryGreen, size: 24),
                          ],
                        ),
                      ),

                      const Spacer(),

                      if (_isConfirming)
                        const Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Confirming payment...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_isPaid)
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primaryGreen, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'Payment confirmed!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _confirmCashPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'I\'ve paid  ₹${state.estimatedFare.toStringAsFixed(0)} cash',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }
}

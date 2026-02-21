import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/otp_input.dart';
import '../widgets/primary_button.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen>
    with SingleTickerProviderStateMixin {
  int _resendCountdown = 30;
  Timer? _timer;
  bool _isVerifying = false;
  bool _canResend = false;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _startCountdown();
  }

  void _startCountdown() {
    _resendCountdown = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _onOtpCompleted(String code) {
    setState(() => _isVerifying = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/location-permission');
      }
    });
  }

  void _resendCode() {
    if (!_canResend) return;
    setState(() {
      _canResend = false;
      _startCountdown();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code resent via WhatsApp'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _animCtrl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.sms_rounded,
                    color: AppColors.primaryGreen,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter the code',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent your code via WhatsApp\nto +91 XXXXX XXXXX',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                OtpInput(length: 6, onCompleted: _onOtpCompleted),
                const SizedBox(height: 28),
                if (_isVerifying)
                  const Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Verifying...',
                          style: TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Center(
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('Open WhatsApp'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _canResend
                        ? TextButton(
                            onPressed: _resendCode,
                            child: const Text(
                              'Resend code',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : Text(
                            'Resend code in ${_resendCountdown}s',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMedium,
                            ),
                          ),
                  ),
                ],
                const Spacer(),
                if (_isVerifying)
                  PrimaryButton(
                    text: 'Verifying...',
                    isLoading: true,
                    onPressed: () {},
                  )
                else
                  PrimaryButton(
                    text: 'Verify',
                    onPressed: () => _onOtpCompleted('000000'),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

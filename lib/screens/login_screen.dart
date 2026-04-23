import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ok = await AuthService().updateCustomerProfile(
      fullName: _nameCtrl.text.trim(),
      phone: '+91${_phoneCtrl.text.trim()}',
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not save profile. Please try again.';
      });
      return;
    }

    context.read<AppState>().setUserInfo(
          name: _nameCtrl.text.trim(),
          phone: '+91${_phoneCtrl.text.trim()}',
          email: context.read<AppState>().userEmail,
        );

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.locationPermission, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _anim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 44),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 30),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Complete your profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Just your name and phone — you\'re good to go.',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 36),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                              hint: 'e.g. Priya Sharma',
                              icon: Icons.person_rounded),
                          validator: (v) =>
                              v?.trim().isEmpty == true ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            hint: '9876543210',
                            icon: Icons.phone_rounded,
                            prefix: '+91',
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty == true) {
                              return 'Phone is required';
                            }
                            if ((v?.trim().length ?? 0) < 10) {
                              return 'Enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorMessage!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.border,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.white),
                                  )
                                : const Text('Save & continue',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.white)),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.backgroundGrey,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIcon: prefix != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.textMedium, size: 18),
                  const SizedBox(width: 8),
                  Text(prefix,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(width: 6),
                  const Text('|',
                      style: TextStyle(
                          color: AppColors.divider, fontSize: 20)),
                ],
              ),
            )
          : Icon(icon, color: AppColors.textMedium, size: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

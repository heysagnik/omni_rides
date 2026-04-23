import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../routes/app_router.dart';
import '../services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _enableLocation() async {
    setState(() => _isLoading = true);
    final granted = await LocationService.requestPermission();
    if (!mounted) return;

    if (granted) {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        final address = await LocationService.getAddressFromLatLng(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          final displayAddress =
              address.isNotEmpty ? address : 'Current Location';
          context.read<AppState>().updateCurrentLocation(
                position.latitude,
                position.longitude,
                displayAddress,
              );
        }
      }
    }

    if (mounted) {
      context.read<AppState>().enableLocation();
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.home, (route) => false);
    }
  }

  void _skip() {
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _animCtrl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(70),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 72,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Enable location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'We use your location to find nearby drivers and set your pickup point.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      height: 1.6,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  text: 'Enable location services',
                  icon: Icons.my_location_rounded,
                  isLoading: _isLoading,
                  onPressed: () => _enableLocation(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';

/// Mix this into any [State] that requires location to be active.
/// It listens to [Geolocator.getServiceStatusStream] and shows a
/// non-dismissible dialog whenever the user disables location services,
/// auto-dismissing it the moment location is turned back on.
mixin LocationGuardMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<ServiceStatus>? _locationStatusSub;
  bool _locationDialogShowing = false;

  void initLocationGuard() {
    _locationStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      if (status == ServiceStatus.disabled && !_locationDialogShowing) {
        _showLocationDialog();
      } else if (status == ServiceStatus.enabled && _locationDialogShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        _locationDialogShowing = false;
      }
    });
  }

  void disposeLocationGuard() {
    _locationStatusSub?.cancel();
  }

  void _showLocationDialog() {
    _locationDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Required'),
          content: const Text(
            'Omni needs your location to show nearby drivers and '
            'get accurate pickup points. Please turn on location services.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Geolocator.openLocationSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

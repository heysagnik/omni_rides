import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Handles FCM token registration and deregistration.
/// Call [registerToken] once after every successful sync-profile.
class NotificationService {
  final ApiService _apiService = ApiService();

  Future<void> registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (required on iOS; no-op on Android)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token == null) return;

      await _sendToken(token);

      // Re-register whenever FCM rotates the token
      messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      debugPrint('NotificationService.registerToken error: $e');
    }
  }

  Future<void> deregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _apiService.delete('/notification/token', body: {'token': token});
    } catch (e) {
      debugPrint('NotificationService.deregisterToken error: $e');
    }
  }

  Future<void> _sendToken(String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await _apiService.post('/notification/token', body: {
      'token': token,
      'platform': platform,
    });
  }
}

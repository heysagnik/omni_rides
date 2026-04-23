import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> syncProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      final res = await _api.postWithFirebaseToken(
        '/auth/sync-profile',
        body: {
          'role': 'customer',
          if (user.displayName?.isNotEmpty == true) 'fullName': user.displayName,
          if (user.email?.isNotEmpty == true) 'email': user.email,
          if (user.photoURL?.isNotEmpty == true) 'photoUrl': user.photoURL,
          if (fcmToken != null) 'fcmToken': fcmToken,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sessionToken = data['sessionToken'] as String?;
        if (sessionToken?.isNotEmpty == true) {
          await ApiService.saveSessionToken(sessionToken!);
        }
        return data;
      }
      debugPrint('[AuthService] syncProfile ${res.statusCode}: ${res.body}');
      return null;
    } catch (e) {
      debugPrint('[AuthService] syncProfile: $e');
      return null;
    }
  }

  Future<bool> updateCustomerProfile({
    required String fullName,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final res = await _api.post('/customer/profile', body: {
        'fullName': fullName,
        if (phone?.isNotEmpty == true) 'phone': phone,
        if (photoUrl?.isNotEmpty == true) 'photoUrl': photoUrl,
      });
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AuthService] updateCustomerProfile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final res = await _api.get('/auth/me');
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      debugPrint('[AuthService] getMe: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCustomerProfile() async {
    try {
      final res = await _api.get('/customer/profile');
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      debugPrint('[AuthService] getCustomerProfile: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[AuthService] signInWithGoogle: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _api.delete('/notification/token', body: {'token': token});
      }
    } catch (_) {}

    await ApiService.clearSessionToken();
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}

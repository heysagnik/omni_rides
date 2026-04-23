import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => '${dotenv.env['BACKEND_URL']}/api';

  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'sessionToken';

  static Future<void> saveSessionToken(String token) =>
      _storage.write(key: _sessionKey, value: token);

  static Future<String?> getSessionToken() => _storage.read(key: _sessionKey);

  static Future<void> clearSessionToken() =>
      _storage.delete(key: _sessionKey);

  Future<Map<String, String>> _headers({bool useFirebaseToken = false}) async {
    String? token;
    try {
      if (useFirebaseToken) {
        token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } else {
        token = await getSessionToken();
        token ??= await FirebaseAuth.instance.currentUser?.getIdToken();
      }
    } catch (e) {
      debugPrint('[ApiService] header error: $e');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshSessionToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final firebaseToken = await user.getIdToken(true);
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      final res = await http.post(
        Uri.parse('$baseUrl/auth/sync-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseToken',
        },
        body: jsonEncode({
          'role': 'customer',
          if (user.displayName?.isNotEmpty == true) 'fullName': user.displayName,
          if (user.email?.isNotEmpty == true) 'email': user.email,
          if (fcmToken != null) 'fcmToken': fcmToken,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newToken = data['sessionToken'] as String?;
        if (newToken?.isNotEmpty == true) {
          await saveSessionToken(newToken!);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ApiService] refresh error: $e');
    }
    return false;
  }

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool useFirebaseToken = false,
    bool isRetry = false,
  }) async {
    final hdrs = await _headers(useFirebaseToken: useFirebaseToken);
    final url = Uri.parse('$baseUrl$endpoint');
    final encoded = body != null ? jsonEncode(body) : null;

    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(url, headers: hdrs);
        case 'POST':
          res = await http.post(url, headers: hdrs, body: encoded);
        case 'PUT':
          res = await http.put(url, headers: hdrs, body: encoded);
        case 'DELETE':
          res = await http.delete(url, headers: hdrs, body: encoded);
        default:
          throw UnsupportedError('Method $method unsupported');
      }
    } catch (e) {
      debugPrint('[ApiService] $method $endpoint: $e');
      rethrow;
    }

    if (res.statusCode == 401 && !isRetry && !useFirebaseToken) {
      final refreshed = await _refreshSessionToken();
      if (refreshed) {
        return _request(method, endpoint, body: body, isRetry: true);
      }
    }

    return res;
  }

  Future<http.Response> get(String endpoint) => _request('GET', endpoint);

  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) =>
      _request('POST', endpoint, body: body);

  Future<http.Response> postWithFirebaseToken(
    String endpoint, {
    Map<String, dynamic>? body,
  }) =>
      _request('POST', endpoint, body: body, useFirebaseToken: true);

  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) =>
      _request('PUT', endpoint, body: body);

  Future<http.Response> delete(String endpoint,
          {Map<String, dynamic>? body}) =>
      _request('DELETE', endpoint, body: body);
}

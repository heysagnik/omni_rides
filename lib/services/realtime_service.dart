import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class RealtimeService {
  final ApiService _apiService = ApiService();

  // Get Ably token wrapper
  Future<String?> getAblyToken() async {
    try {
      final response = await _apiService.get('/ably/auth');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching Ably token: $e');
      return null;
    }
  }

  // Live Location Sync
  Future<bool> updateLocation(LatLng location) async {
    try {
      final response = await _apiService.post('/users/location', body: {
        'lat': location.latitude,
        'lng': location.longitude
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating location: $e');
      return false;
    }
  }
}

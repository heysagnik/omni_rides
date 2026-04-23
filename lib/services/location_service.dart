import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {

  /// Returns true if location permission is granted (fine or coarse).
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Gets current GPS position. Returns null if permission denied or error.
  static Future<Position?> getCurrentPosition() async {
    try {
      final granted = await requestPermission();
      if (!granted) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  /// Reverse geocodes lat/lng to a human-readable address using Google Maps API.
  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final String? mapsKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (mapsKey == null || mapsKey.isEmpty) return '';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$mapsKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['formatted_address'] as String? ?? '';
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return '';
  }
}

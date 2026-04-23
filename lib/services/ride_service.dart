import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class RideService {
  final ApiService _apiService = ApiService();

  // GET /ride/:rideId/track — returns initial driver location and Ably channel name
  Future<Map<String, dynamic>?> getTrack(String rideId) async {
    try {
      final response = await _apiService.get('/ride/$rideId/track');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ride track: $e');
      return null;
    }
  }

  // GET /ride/:rideId/eta — returns { phase, etaMinutes, distanceKm }
  Future<Map<String, dynamic>?> getEta(String rideId) async {
    try {
      final response = await _apiService.get('/ride/$rideId/eta');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ride ETA: $e');
      return null;
    }
  }

  // Search Locations
  Future<List<Map<String, dynamic>>?> searchLocations(
    String query, {
    double? lat,
    double? lng,
  }) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) return null;

      String urlStr = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$apiKey';
      if (lat != null && lng != null) {
        urlStr += '&location=$lat,$lng&radius=50000'; // 50km radius
      }

      final url = Uri.parse(urlStr);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results.map((e) {
            final loc = e['geometry']['location'];
            return {
              'name': e['name'] ?? '',
              'address': e['formatted_address'] ?? '',
              'lat': loc['lat'],
              'lng': loc['lng'],
            };
          }).toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error searching locations: $e');
      return null;
    }
  }

  // Request Ride — returns { rideId, estimatedFare, ... }
  Future<Map<String, dynamic>?> requestRide({
    required LatLng pickup,
    required String pickupAddress,
    required LatLng drop,
    required String dropAddress,
    String rideType = 'human',
    String paymentMethod = 'cash',
  }) async {
    try {
      final response = await _apiService.post('/ride/request', body: {
        'pickup': {
          'lat': pickup.latitude,
          'lng': pickup.longitude,
          'address': pickupAddress,
        },
        'drop': {
          'lat': drop.latitude,
          'lng': drop.longitude,
          'address': dropAddress,
        },
        'rideType': rideType,
        'paymentMethod': paymentMethod,
      });
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        return jsonDecode(response.body);
      }
      debugPrint('requestRide failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error requesting ride: $e');
      return null;
    }
  }

  // Get Ride Details — polls status
  Future<Map<String, dynamic>?> getRideDetails(String rideId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _apiService.get('/ride/$rideId?_t=$timestamp');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ride details: $e');
      return null;
    }
  }

  // Get Payment Details
  Future<Map<String, dynamic>?> getPaymentDetails(String rideId) async {
    try {
      final response = await _apiService.get('/payment/$rideId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting payment details: $e');
      return null;
    }
  }

  // Confirm Cash Payment
  Future<bool> confirmPayment(String paymentId) async {
    try {
      final response = await _apiService.post('/payment/confirm', body: {
        'paymentId': paymentId,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error confirming payment: $e');
      return false;
    }
  }

  // Cancel Ride
  Future<bool> cancelRide(String rideId, String reason) async {
    try {
      final response = await _apiService.post('/ride/$rideId/cancel', body: {
        'reason': reason,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error cancelling ride: $e');
      return false;
    }
  }

  // Rate Ride
  Future<bool> rateRide(String rideId, int rating, String? comment) async {
    try {
      final response = await _apiService.post('/ride/$rideId/rate', body: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error rating ride: $e');
      return false;
    }
  }

  // Get Ride History
  Future<List<dynamic>?> getRideHistory() async {
    try {
      final response = await _apiService.get('/ride/history');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Response is a list directly per the doc
        if (data is List) return data;
        return data['rides'];
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching ride history: $e');
      return null;
    }
  }

  // Returns the most recent ride that is still active (not completed/cancelled)
  // 'searching' is intentionally excluded — on cold app launch a lingering
  // searching ride is stale and should NOT be resumed.
  static const _activeStatuses = [
    'driver_assigned',
    'driver_en_route',
    'driver_arrived',
    'ride_started',
    'in_progress',
  ];

  Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final response = await _apiService.get('/ride/history');
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final List rides = data is List ? data : (data['rides'] ?? []);
      for (final ride in rides) {
        if (_activeStatuses.contains(ride['status'])) {
          return ride as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active ride: $e');
      return null;
    }
  }
}

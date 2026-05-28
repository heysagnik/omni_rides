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

  // Fetch fare estimates for all ride types in one call.
  // Returns { distanceKm, durationMin, options: { human: {...}, parcel: {...} } }
  Future<Map<String, dynamic>?> getFareEstimates({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    try {
      final response = await _apiService.get(
        '/ride/fare-estimate?pickupLat=$pickupLat&pickupLng=$pickupLng&dropLat=$dropLat&dropLng=$dropLng',
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      debugPrint('Error fetching fare estimates: $e');
      return null;
    }
  }

  // GET /ride/offers — returns list of available promotional offers
  Future<List<dynamic>?> getOffers() async {
    try {
      final response = await _apiService.get('/ride/offers');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['offers'] as List<dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      return null;
    }
  }

  // POST /ride/validate-coupon — validates code and returns { code, discount, finalFare }
  Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required int fare,
  }) async {
    try {
      final response = await _apiService.post('/ride/validate-coupon', body: {
        'code': code,
        'fare': fare,
      });
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 404) {
        final body = jsonDecode(response.body);
        return {'error': body['error'] ?? 'Invalid coupon'};
      }
      return null;
    } catch (e) {
      debugPrint('Error validating coupon: $e');
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
    String? couponCode,
  }) async {
    try {
      final body = <String, dynamic>{
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
      };
      if (couponCode != null && couponCode.isNotEmpty) {
        body['couponCode'] = couponCode;
      }
      final response = await _apiService.post('/ride/request', body: body);
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

  Future<void> retryMatching(String rideId) async {
    try {
      await _apiService.post('/ride/$rideId/retry-matching', body: {});
    } catch (e) {
      debugPrint('Error retrying matching: $e');
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

  Future<Map<String, dynamic>?> getDriverDetails(String driverId) async {
    try {
      final response = await _apiService.get('/ride/driver/$driverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting driver details: $e');
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

  // Initialize Payment row explicitly if missing or starting non-cash payment
  Future<Map<String, dynamic>?> initializePayment(String rideId, String method) async {
    try {
      final response = await _apiService.post('/payment/initialize', body: {
        'rideId': rideId,
        'method': method,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error initializing payment: $e');
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
        'comment': comment ?? '',
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
    'searching',
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
      debugPrint('Diagnostic: Fetched ${rides.length} rides from history.');
      for (final ride in rides) {
        debugPrint('Checking ride ID=${ride['id']} with status=${ride['status']}');
        if (_activeStatuses.contains(ride['status'])) {
          debugPrint('Active ride match found! ID=${ride['id']}, status=${ride['status']}');
          return ride as Map<String, dynamic>;
        }
      }
      debugPrint('Diagnostic: No active ride match found in history.');
      return null;
    } catch (e) {
      debugPrint('Error getting active ride: $e');
      return null;
    }
  }
}

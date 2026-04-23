import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class SafetyService {
  final ApiService _apiService = ApiService();

  // GET /safety/contacts
  Future<List<Map<String, dynamic>>?> getContacts() async {
    try {
      final response = await _apiService.get('/safety/contacts');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['contacts'] as List<dynamic>?;
        return list?.map((e) => e as Map<String, dynamic>).toList();
      }
      return null;
    } catch (e) {
      debugPrint('SafetyService.getContacts error: $e');
      return null;
    }
  }

  // POST /safety/contacts
  Future<Map<String, dynamic>?> addContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      final response = await _apiService.post('/safety/contacts', body: {
        'name': name,
        'phone': phone,
        if (relationship != null && relationship.isNotEmpty)
          'relationship': relationship,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['contact'] as Map<String, dynamic>?;
      }
      debugPrint('addContact failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('SafetyService.addContact error: $e');
      return null;
    }
  }

  // DELETE /safety/contacts/:contactId
  Future<bool> deleteContact(String contactId) async {
    try {
      final response = await _apiService.delete('/safety/contacts/$contactId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SafetyService.deleteContact error: $e');
      return false;
    }
  }

  // POST /safety/sos
  Future<bool> triggerSos({
    String? rideId,
    double? lat,
    double? lng,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (rideId != null && rideId.isNotEmpty) body['rideId'] = rideId;
      if (lat != null && lng != null) {
        body['location'] = {'lat': lat, 'lng': lng};
      }
      final response = await _apiService.post('/safety/sos', body: body);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SafetyService.triggerSos error: $e');
      return false;
    }
  }

  // POST /safety/share-trip
  Future<Map<String, dynamic>?> shareTrip(String rideId) async {
    try {
      final response = await _apiService.post('/safety/share-trip', body: {
        'rideId': rideId,
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('shareTrip failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('SafetyService.shareTrip error: $e');
      return null;
    }
  }
}

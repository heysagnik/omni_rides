import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  String _userName = '';
  String _userPhone = '';
  String _userEmail = '';
  String _userPhotoUrl = '';
  final double _userRating = 4.8;
  bool _isLoggedIn = false;
  bool _locationEnabled = false;

  double _currentLat = 0.0;
  double _currentLng = 0.0;
  String _currentAddress = '';

  String _rideStatus = 'idle';
  String _pickupAddress = '';
  String _destinationAddress = '';
  double _pickupLat = 0;
  double _pickupLng = 0;
  double _destinationLat = 0;
  double _destinationLng = 0;
  double _estimatedFare = 0;
  double _estimatedDistance = 0;
  String _rideOtp = '';
  String _paymentMethod = '';
  String _rideId = '';
  String _paymentId = '';

  String _driverName = '';
  String _driverVehicle = '';
  String _driverPlate = '';
  double _driverRating = 0;
  String _driverPhone = '';
  double _driverLat = 0;
  double _driverLng = 0;
  int _etaMinutes = 0;

  final List<Map<String, dynamic>> _rideHistory = [];

  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;
  String get userPhotoUrl => _userPhotoUrl;
  double get userRating => _userRating;
  bool get isLoggedIn => _isLoggedIn;
  bool get locationEnabled => _locationEnabled;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  String get currentAddress => _currentAddress;
  String get rideStatus => _rideStatus;
  String get pickupAddress => _pickupAddress;
  String get destinationAddress => _destinationAddress;
  double get pickupLat => _pickupLat;
  double get pickupLng => _pickupLng;
  double get destinationLat => _destinationLat;
  double get destinationLng => _destinationLng;
  double get estimatedFare => _estimatedFare;
  double get estimatedDistance => _estimatedDistance;
  String get rideOtp => _rideOtp;
  String get paymentMethod => _paymentMethod;
  String get rideId => _rideId;
  String get paymentId => _paymentId;
  String get driverName => _driverName;
  String get driverVehicle => _driverVehicle;
  String get driverPlate => _driverPlate;
  double get driverRating => _driverRating;
  String get driverPhone => _driverPhone;
  double get driverLat => _driverLat;
  double get driverLng => _driverLng;
  int get etaMinutes => _etaMinutes;
  List<Map<String, dynamic>> get rideHistory => _rideHistory;

  void setUserInfo({
    required String name,
    required String phone,
    required String email,
    String photoUrl = '',
  }) {
    _userName = name;
    _userPhone = phone;
    _userEmail = email;
    _userPhotoUrl = photoUrl;
    _isLoggedIn = true;
    notifyListeners();
  }

  void setLoginStatus(bool status) {
    _isLoggedIn = status;
    notifyListeners();
  }

  Future<String> syncWithBackend() async {
    final profile = await AuthService().syncProfile();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (profile != null) {
      _userName = firebaseUser?.displayName ??
          profile['fullName'] as String? ??
          profile['name'] as String? ??
          '';
      _userEmail = firebaseUser?.email ?? profile['email'] as String? ?? '';
      _userPhone = firebaseUser?.phoneNumber ??
          profile['phoneNumber'] as String? ??
          '';
      _userPhotoUrl =
          firebaseUser?.photoURL ?? profile['photoUrl'] as String? ?? '';
      _isLoggedIn = true;
      notifyListeners();
      NotificationService().registerToken();
      if (profile['isNewUser'] == true) return 'new_user';
      return 'home';
    }

    _isLoggedIn = false;
    notifyListeners();
    return 'auth';
  }

  void enableLocation() {
    _locationEnabled = true;
    notifyListeners();
  }

  void updateCurrentLocation(double lat, double lng, String address) {
    _currentLat = lat;
    _currentLng = lng;
    _currentAddress = address;
    _pickupLat = lat;
    _pickupLng = lng;
    _pickupAddress = address;
    notifyListeners();
  }

  void setPickup(String address, double lat, double lng) {
    _pickupAddress = address;
    _pickupLat = lat;
    _pickupLng = lng;
    notifyListeners();
  }

  void setDestination(String address, double lat, double lng) {
    _destinationAddress = address;
    _destinationLat = lat;
    _destinationLng = lng;
    _estimatedDistance = _approxDistanceKm(lat, lng);
    _estimatedFare = 0;
    notifyListeners();
  }

  void setEstimatedFare(double fare) {
    _estimatedFare = fare;
    notifyListeners();
  }

  void startSearching() {
    _rideStatus = 'searching';
    notifyListeners();
  }

  void setRideId(String id) {
    _rideId = id;
    notifyListeners();
  }

  void setOtp(String otp) {
    _rideOtp = otp;
    notifyListeners();
  }

  void setPaymentId(String id) {
    _paymentId = id;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void driverMatched({
    required String name,
    required String vehicle,
    required String plate,
    required double rating,
    required String phone,
    required double lat,
    required double lng,
    required int eta,
  }) {
    _rideStatus = 'matched';
    _driverName = name;
    _driverVehicle = vehicle;
    _driverPlate = plate;
    _driverRating = rating;
    _driverPhone = phone;
    _driverLat = lat;
    _driverLng = lng;
    _etaMinutes = eta;
    notifyListeners();
  }

  void updateDriverLocation(double lat, double lng, int eta) {
    _driverLat = lat;
    _driverLng = lng;
    _etaMinutes = eta;
    notifyListeners();
  }

  void startRide() {
    _rideStatus = 'in_transit';
    notifyListeners();
  }

  void completeRide() {
    _rideStatus = 'completed';
    notifyListeners();
  }

  void submitRating(int stars) {
    _rideHistory.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'pickup_address': _pickupAddress,
      'drop_address': _destinationAddress,
      'final_fare': _estimatedFare,
      'distance': _estimatedDistance,
      'driverName': _driverName,
      'userRating': stars,
      'payment_method': _paymentMethod,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'ride_completed',
    });
    resetRide();
  }

  void cancelRide(String reason) {
    if (_pickupAddress.isNotEmpty) {
      _rideHistory.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'pickup_address': _pickupAddress,
        'drop_address': _destinationAddress,
        'final_fare': 0,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'cancelled',
      });
    }
    resetRide();
  }

  void resetRide() {
    _rideStatus = 'idle';
    _destinationAddress = '';
    _destinationLat = 0;
    _destinationLng = 0;
    _estimatedFare = 0;
    _estimatedDistance = 0;
    _rideOtp = '';
    _driverName = '';
    _driverVehicle = '';
    _driverPlate = '';
    _driverRating = 0;
    _driverPhone = '';
    _driverLat = 0;
    _driverLng = 0;
    _etaMinutes = 0;
    _paymentMethod = '';
    _rideId = '';
    _paymentId = '';
    notifyListeners();
  }

  void setRideHistory(List<dynamic> rides) {
    _rideHistory.clear();
    for (final r in rides) {
      if (r is Map<String, dynamic>) _rideHistory.add(r);
    }
    notifyListeners();
  }

  Future<String?> checkAndRestoreActiveRide() async {
    final ride = await RideService().getActiveRide();
    if (ride == null) return null;

    final id = ride['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    _rideId = id;
    _pickupAddress = ride['pickup_address'] as String? ??
        ride['pickup']?['address'] as String? ??
        '';
    _destinationAddress = ride['drop_address'] as String? ??
        ride['drop']?['address'] as String? ??
        '';
    _pickupLat = (ride['pickup_lat'] ?? ride['pickup']?['lat'] ?? 0).toDouble();
    _pickupLng = (ride['pickup_lng'] ?? ride['pickup']?['lng'] ?? 0).toDouble();
    _destinationLat =
        (ride['drop_lat'] ?? ride['drop']?['lat'] ?? 0).toDouble();
    _destinationLng =
        (ride['drop_lng'] ?? ride['drop']?['lng'] ?? 0).toDouble();
    _estimatedFare =
        (ride['estimated_fare'] ?? ride['estimatedFare'] ?? 0).toDouble();
    _rideOtp = ride['otp']?.toString() ?? '';

    final status = ride['status'] as String? ?? '';
    final driver = ride['driver'] as Map<String, dynamic>? ?? {};

    void restoreDriver() {
      _driverName =
          driver['name'] as String? ?? ride['driver_name'] as String? ?? '';
      _driverVehicle =
          driver['vehicle'] as String? ?? '';
      _driverPlate = driver['plate'] as String? ??
          driver['vehiclePlate'] as String? ??
          '';
      _driverRating = (driver['rating'] ?? 4.5).toDouble();
      _driverPhone = driver['phone'] as String? ?? '';
      _driverLat = (driver['lat'] ?? driver['latitude'] ?? 0).toDouble();
      _driverLng = (driver['lng'] ?? driver['longitude'] ?? 0).toDouble();
    }

    if (status == 'searching') {
      RideService().cancelRide(id, 'App relaunch');
      _rideId = '';
      return null;
    }

    if (status == 'driver_assigned' ||
        status == 'driver_en_route' ||
        status == 'driver_arrived') {
      restoreDriver();
      _rideStatus = 'matched';
      notifyListeners();
      return 'driverMatched';
    }

    if (status == 'ride_started' || status == 'in_progress') {
      restoreDriver();
      _rideStatus = 'in_transit';
      notifyListeners();
      return 'inTransit';
    }

    return null;
  }

  double _approxDistanceKm(double destLat, double destLng) {
    final dLat = (destLat - _pickupLat).abs();
    final dLng = (destLng - _pickupLng).abs();
    return ((dLat + dLng) * 111).clamp(1.0, 500.0);
  }
}

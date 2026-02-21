import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  // User Info
  String _userName = '';
  String _userPhone = '';
  String _userEmail = '';
  double _userRating = 4.8;
  bool _isLoggedIn = false;
  bool _locationEnabled = false;

  // Current Location
  double _currentLat = 28.6139;
  double _currentLng = 77.2090;
  String _currentAddress = 'Current Location';

  // Ride State
  String _rideStatus =
      'idle'; // idle, searching, matched, in_transit, completed
  String _pickupAddress = '';
  String _destinationAddress = '';
  double _pickupLat = 0;
  double _pickupLng = 0;
  double _destinationLat = 0;
  double _destinationLng = 0;
  double _estimatedFare = 0;
  double _estimatedDistance = 0;
  String _selectedService = 'ride'; // ride, food, parcel
  String _rideOtp = '';
  String _paymentMethod = '';

  // Driver Info
  String _driverName = '';
  String _driverVehicle = '';
  String _driverPlate = '';
  double _driverRating = 0;
  String _driverPhone = '';
  double _driverLat = 0;
  double _driverLng = 0;
  int _etaMinutes = 0;

  // Ride History
  List<Map<String, dynamic>> _rideHistory = [];

  // Notifications
  List<Map<String, dynamic>> _notifications = [];

  // Getters
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;
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
  String get selectedService => _selectedService;
  String get rideOtp => _rideOtp;
  String get paymentMethod => _paymentMethod;
  String get driverName => _driverName;
  String get driverVehicle => _driverVehicle;
  String get driverPlate => _driverPlate;
  double get driverRating => _driverRating;
  String get driverPhone => _driverPhone;
  double get driverLat => _driverLat;
  double get driverLng => _driverLng;
  int get etaMinutes => _etaMinutes;
  List<Map<String, dynamic>> get rideHistory => _rideHistory;
  List<Map<String, dynamic>> get notifications => _notifications;

  // User Actions
  void setUserInfo({
    required String name,
    required String phone,
    required String email,
  }) {
    _userName = name;
    _userPhone = phone;
    _userEmail = email;
    _isLoggedIn = true;
    notifyListeners();
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

  // Service Selection
  void setSelectedService(String service) {
    _selectedService = service;
    notifyListeners();
  }

  // Ride Flow
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
    _estimatedDistance = _calculateDistance(lat, lng);
    _estimatedFare = _calculateFare(_estimatedDistance);
    notifyListeners();
  }

  void adjustFare(double amount) {
    _estimatedFare = (_estimatedFare + amount).clamp(50, 99999);
    notifyListeners();
  }

  void startSearching() {
    _rideStatus = 'searching';
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
    _rideOtp = _generateOtp();
    notifyListeners();
  }

  void startRide() {
    _rideStatus = 'in_transit';
    notifyListeners();
  }

  void updateDriverLocation(double lat, double lng, int etaMinutes) {
    _driverLat = lat;
    _driverLng = lng;
    _etaMinutes = etaMinutes;
    notifyListeners();
  }

  void completeRide() {
    _rideStatus = 'completed';
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void submitRating(int stars) {
    _rideHistory.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'pickup': _pickupAddress,
      'destination': _destinationAddress,
      'fare': _estimatedFare,
      'distance': _estimatedDistance,
      'driverName': _driverName,
      'driverRating': _driverRating,
      'userRating': stars,
      'service': _selectedService,
      'paymentMethod': _paymentMethod,
      'date': DateTime.now().toIso8601String(),
      'status': 'completed',
    });
    resetRide();
  }

  void cancelRide(String reason) {
    _rideHistory.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'pickup': _pickupAddress,
      'destination': _destinationAddress,
      'fare': _estimatedFare,
      'service': _selectedService,
      'date': DateTime.now().toIso8601String(),
      'status': 'cancelled',
      'cancelReason': reason,
    });
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
    notifyListeners();
  }

  // Notifications
  void addNotification(String title, String message, String type) {
    _notifications.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'message': message,
      'type': type,
      'time': DateTime.now().toIso8601String(),
      'read': false,
    });
    notifyListeners();
  }

  // Demo data initialization
  void loadDemoData() {
    _pickupAddress = 'Connaught Place, New Delhi';
    _pickupLat = 28.6315;
    _pickupLng = 77.2167;
    _currentAddress = 'Connaught Place, New Delhi';

    _rideHistory = [
      {
        'id': '1',
        'pickup': 'Connaught Place, New Delhi',
        'destination': 'India Gate, New Delhi',
        'fare': 120.0,
        'distance': 3.2,
        'driverName': 'Rajesh Kumar',
        'driverRating': 4.7,
        'userRating': 5,
        'service': 'ride',
        'paymentMethod': 'cash',
        'date': '2026-02-20T10:30:00',
        'status': 'completed',
      },
      {
        'id': '2',
        'pickup': 'Hauz Khas, New Delhi',
        'destination': 'Sarojini Nagar Market',
        'fare': 85.0,
        'distance': 2.1,
        'driverName': 'Amit Singh',
        'driverRating': 4.9,
        'userRating': 4,
        'service': 'ride',
        'paymentMethod': 'upi',
        'date': '2026-02-19T14:15:00',
        'status': 'completed',
      },
      {
        'id': '3',
        'pickup': 'Sector 18, Noida',
        'destination': 'Botanical Garden Metro',
        'fare': 65.0,
        'distance': 1.5,
        'driverName': 'Vikram Patel',
        'driverRating': 4.5,
        'userRating': 5,
        'service': 'ride',
        'paymentMethod': 'cash',
        'date': '2026-02-18T09:00:00',
        'status': 'completed',
      },
    ];

    _notifications = [
      {
        'id': '1',
        'title': 'Welcome! 🎉',
        'message': 'Welcome to RideApp! Enjoy your first ride with us.',
        'type': 'promo',
        'time': '2026-02-21T10:00:00',
        'read': false,
      },
      {
        'id': '2',
        'title': 'Safety Update',
        'message':
            'We have enhanced our safety features. Add your emergency contacts now.',
        'type': 'system',
        'time': '2026-02-20T15:00:00',
        'read': true,
      },
      {
        'id': '3',
        'title': '20% Off Your Next Ride',
        'message': 'Use code RIDE20 for 20% off. Valid till Feb 28.',
        'type': 'promo',
        'time': '2026-02-19T12:00:00',
        'read': false,
      },
    ];
    notifyListeners();
  }

  // Private Helpers
  double _calculateDistance(double destLat, double destLng) {
    // Simplified Haversine approximation
    double dLat = (destLat - _pickupLat).abs();
    double dLng = (destLng - _pickupLng).abs();
    double approxKm = ((dLat + dLng) * 111).clamp(1.0, 500.0);
    return double.parse(approxKm.toStringAsFixed(1));
  }

  double _calculateFare(double distanceKm) {
    double baseFare = 30;
    double perKmRate = 12;
    double fare = baseFare + (distanceKm * perKmRate);
    return double.parse(fare.toStringAsFixed(0));
  }

  String _generateOtp() {
    int otp = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    return otp.toString();
  }
}

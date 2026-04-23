import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../screens/auth_options_screen.dart';
import '../screens/login_screen.dart';
import '../screens/location_permission_screen.dart';
import '../screens/main_screen.dart';
import '../screens/route_selection_screen.dart';
import '../screens/searching_screen.dart';
import '../screens/driver_matched_screen.dart';
import '../screens/in_transit_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/rating_screen.dart';
import '../screens/safety_screen.dart';
import '../screens/my_rides_screen.dart';
import '../screens/profile_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String authOptions = '/auth-options';
  static const String login = '/login';
  static const String locationPermission = '/location-permission';
  static const String home = '/home';
  static const String routeSelection = '/route-selection';
  static const String searching = '/searching';
  static const String driverMatched = '/driver-matched';
  static const String inTransit = '/in-transit';
  static const String payment = '/payment';
  static const String rating = '/rating';
  static const String safety = '/safety';
  static const String myRides = '/my-rides';
  static const String profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _build(const SplashScreen(), settings);
      case authOptions:
        return _build(const AuthOptionsScreen(), settings);
      case login:
        return _build(const LoginScreen(), settings);
      case locationPermission:
        return _build(const LocationPermissionScreen(), settings);
      case home:
        return _build(const MainScreen(), settings);
      case routeSelection:
        return _build(const RouteSelectionScreen(), settings);
      case searching:
        return _build(const SearchingScreen(), settings);
      case driverMatched:
        return _build(const DriverMatchedScreen(), settings);
      case inTransit:
        return _build(const InTransitScreen(), settings);
      case payment:
        return _build(const PaymentScreen(), settings);
      case rating:
        return _build(const RatingScreen(), settings);
      case safety:
        return _build(const SafetyScreen(), settings);
      case myRides:
        return _build(const MyRidesScreen(), settings);
      case profile:
        return _build(const ProfileScreen(), settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route: ${settings.name}')),
          ),
        );
    }
  }

  static Route<dynamic> _build(Widget page, RouteSettings settings) {
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}

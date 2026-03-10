import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_options_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/location_permission_screen.dart';
import 'screens/home_screen.dart';
import 'screens/route_selection_screen.dart';
import 'screens/searching_screen.dart';
import 'screens/driver_matched_screen.dart';
import 'screens/in_transit_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/my_rides_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/safety_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'RideApp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/auth-options': (context) => const AuthOptionsScreen(),
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const OTPScreen(),
          '/location-permission': (context) => const LocationPermissionScreen(),
          '/home': (context) => const HomeScreen(),
          '/route-selection': (context) => const RouteSelectionScreen(),
          '/searching': (context) => const SearchingScreen(),
          '/driver-matched': (context) => const DriverMatchedScreen(),
          '/in-transit': (context) => const InTransitScreen(),
          '/payment': (context) => const PaymentScreen(),
          '/rating': (context) => const RatingScreen(),
          '/my-rides': (context) => const MyRidesScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/safety': (context) => const SafetyScreen(),
        },
      ),
    );
  }
}

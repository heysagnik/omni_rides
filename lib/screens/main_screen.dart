import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasActiveRide = state.rideStatus == 'matched' ||
        state.rideStatus == 'in_transit' ||
        state.rideStatus == 'searching';

    return Scaffold(
      body: Stack(
        children: [
          const HomeScreen(),
          if (hasActiveRide)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ActiveRideBanner(state: state),
            ),
        ],
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  final AppState state;
  const _ActiveRideBanner({required this.state});

  String get _route {
    if (state.rideStatus == 'matched') return AppRouter.driverMatched;
    if (state.rideStatus == 'in_transit') return AppRouter.inTransit;
    return AppRouter.searching;
  }

  String get _label {
    switch (state.rideStatus) {
      case 'searching':
        return 'Finding your driver…';
      case 'matched':
        return 'Driver on the way';
      case 'in_transit':
        return 'Ride in progress';
      default:
        return 'Ride active';
    }
  }

  IconData get _icon {
    if (state.rideStatus == 'in_transit') return Icons.directions_car_rounded;
    if (state.rideStatus == 'searching') return Icons.search_rounded;
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, _route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (state.driverName.isNotEmpty)
                    Text(
                      state.driverName,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                ],
              ),
            ),
            if (state.etaMinutes > 0 && state.rideStatus != 'searching') ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.etaMinutes} min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

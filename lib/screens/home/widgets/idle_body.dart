import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'home_widgets.dart';
import 'recent_row.dart';

class IdleBody extends StatelessWidget {
  final String? firstName;
  final String currentAddress;
  final List<PlaceItem> recentPlaces;
  final void Function(PlaceItem?) onSearchTap;

  const IdleBody({
    super.key,
    required this.firstName,
    required this.currentAddress,
    required this.recentPlaces,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top: greeting + search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName != null ? 'Hey, $firstName 👋' : 'Hey there 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),

              // White "Where to?" bar
              GestureDetector(
                onTap: () => onSearchTap(null),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Where to?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.divider),

        // Recent places section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              const Text(
                'Recent places',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            physics: const ClampingScrollPhysics(),
            itemCount: recentPlaces.length,
            itemBuilder: (_, i) => RecentRow(
              place: recentPlaces[i],
              onTap: () => onSearchTap(recentPlaces[i]),
            ),
          ),
        ),
      ],
    );
  }
}

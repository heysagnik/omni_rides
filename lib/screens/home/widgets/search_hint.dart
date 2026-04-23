import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class SearchHint extends StatelessWidget {
  const SearchHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 36, color: AppColors.textLight),
          const SizedBox(height: 8),
          const Text(
            'Type at least 3 characters\nto search for a place',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}

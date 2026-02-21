import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final ValueChanged<int>? onRatingChanged;

  const StarRating({
    super.key,
    this.rating = 0,
    this.maxRating = 5,
    this.size = 40,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxRating, (index) {
        return GestureDetector(
          onTap: onRatingChanged != null
              ? () => onRatingChanged!(index + 1)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: index < rating
                  ? AppColors.starFilled
                  : AppColors.starEmpty,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

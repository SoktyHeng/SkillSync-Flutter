import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final bool isInteractive;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarRating({
    super.key,
    required this.rating,
    this.isInteractive = false,
    this.onRatingChanged,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? Colors.amber;
    final inactive = inactiveColor ?? Colors.grey[300]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = rating >= starIndex;
        final isHalfFilled = rating > index && rating < starIndex;

        IconData icon;
        Color color;

        if (isFilled) {
          icon = Icons.star;
          color = active;
        } else if (isHalfFilled) {
          icon = Icons.star_half;
          color = active;
        } else {
          icon = Icons.star_border;
          color = inactive;
        }

        if (isInteractive) {
          return GestureDetector(
            onTap: () => onRatingChanged?.call(starIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                icon,
                size: size,
                color: color,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            icon,
            size: size,
            color: color,
          ),
        );
      }),
    );
  }
}

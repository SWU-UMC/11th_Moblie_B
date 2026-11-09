import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 별을 눌러 0.5점 단위로 평점을 고르는 입력 위젯입니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBar.builder(
          initialRating: rating,
          minRating: 0.5,
          allowHalfRating: true,
          glow: false,
          itemSize: 40,
          itemPadding: const EdgeInsets.symmetric(horizontal: 2),
          unratedColor: colors.primary.withValues(alpha: 0.2),
          itemBuilder: (_, _) =>
              Icon(Icons.star_rounded, color: colors.primary),
          onRatingUpdate: onChanged,
        ),
        const SizedBox(height: 12),
        Text(
          rating == 0 ? '별을 눌러 평점을 선택해주세요' : '${rating.toStringAsFixed(1)}점',
          style: rating == 0
              ? textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)
              : textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../theme/app_colors.dart';

/// 0.5점 단위로 별점을 입력하는 Widget.
/// 별점 값은 부모가 관리하고, 바뀐 값은 [onChanged]로 전달합니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.itemSize = 40,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: itemSize,
      glow: false,
      unratedColor: AppColors.violetLight,
      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
      itemBuilder: (context, index) =>
          const Icon(Icons.star_rounded, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}

/// 이미 정해진 평점을 읽기 전용으로 보여주는 Widget
class MovieRatingIndicator extends StatelessWidget {
  const MovieRatingIndicator({
    super.key,
    required this.rating,
    this.itemSize = 16,
  });

  final double rating;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    return RatingBarIndicator(
      rating: rating,
      itemCount: 5,
      itemSize: itemSize,
      unratedColor: AppColors.violetLight,
      itemBuilder: (context, index) =>
          const Icon(Icons.star_rounded, color: AppColors.violet),
    );
  }
}

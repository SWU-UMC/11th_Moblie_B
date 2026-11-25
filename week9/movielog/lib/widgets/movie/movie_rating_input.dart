import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../theme/app_colors.dart';

/// 별점 입력 (7주차 서버 연동이라 1~5 정수만)
/// 값은 부모가 관리, 바뀌면 onChanged 호출
/// RatingBar는 항상 double로 줘서 1.0, 2.0 같은 값이 옴
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
    this.itemSize = 32,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  /// 저장 중엔 false → 탭 막음
  final bool enabled;
  final double itemSize;

  // Figma: 고른 별 ★, 안 고른 별 ☆ (둘 다 보라)
  static const _full = Icon(Icons.star, color: AppColors.violet);
  static const _empty = Icon(Icons.star_border, color: AppColors.violet);

  @override
  Widget build(BuildContext context) {
    return RatingBar(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false, // 별 한 개 단위로만
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: itemSize,
      glow: false,
      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
      ratingWidget: RatingWidget(full: _full, half: _full, empty: _empty),
      onRatingUpdate: onChanged,
    );
  }
}

/// 읽기 전용 별점
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

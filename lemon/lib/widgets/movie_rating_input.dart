import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 별을 눌러 1점 단위(1~5 정수)로 평점을 고르는 입력 위젯입니다.
///
/// v6 서버 평점은 정수이므로 반 점 입력을 받지 않습니다.
/// RatingBar는 항상 double을 돌려주므로 값은 1.0, 2.0처럼 전달됩니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  /// 저장 중에는 별점을 바꾸지 못하게 합니다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // RatingBar는 Wrap이라 좁으면 다섯 번째 별이 다음 줄로 넘어가 드래그 위치와 점수가 어긋납니다.
    // 한 줄로 그린 뒤 FittedBox로 줄여, 터치 좌표도 같은 비율로 변환되게 합니다.
    return Semantics(
      label: rating == 0 ? '별점을 선택해주세요' : '별점 ${rating.toInt()}점',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RatingBar(
          initialRating: rating,
          minRating: 1,
          allowHalfRating: false,
          ignoreGestures: !enabled,
          glow: false,
          itemCount: 5,
          itemSize: 44,
          itemPadding: const EdgeInsets.symmetric(horizontal: 2),
          ratingWidget: RatingWidget(
            full: Icon(Icons.star_rounded, color: colors.primary),
            half: Icon(Icons.star_half_rounded, color: colors.primary),
            empty: Icon(Icons.star_outline_rounded, color: colors.primary),
          ),
          onRatingUpdate: onChanged,
        ),
      ),
    );
  }
}

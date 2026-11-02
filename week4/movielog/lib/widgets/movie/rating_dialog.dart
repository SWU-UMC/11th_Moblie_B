import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'movie_rating_input.dart';

/// 별점을 고르는 커스텀 Dialog. 확인을 누르면 고른 별점을 반환합니다.
///
/// ```dart
/// final rating = await RatingDialog.show(context);
/// ```
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  final double initialRating;

  static Future<double?> show(
    BuildContext context, {
    double initialRating = 0,
  }) {
    return showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(initialRating: initialRating),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  /// RatingBar는 처음 값만 읽으므로, 다시 선택할 때 key를 바꿔 새로 그립니다.
  int _resetCount = 0;

  bool get _hasRating => _rating > 0;

  void _reset() {
    setState(() {
      _rating = 0;
      _resetCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: AppColors.warmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '영화는 어떠셨나요?',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Center(
              child: MovieRatingInput(
                key: ValueKey(_resetCount),
                rating: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _hasRating
                  ? '${_rating.toStringAsFixed(1)}점'
                  : '별을 눌러 평점을 선택해주세요',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: _hasRating ? AppColors.violet : AppColors.hint,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _hasRating ? _reset : null,
              child: const Text('다시 선택'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              // 별점을 고르기 전에는 확인 버튼이 비활성화됩니다.
              onPressed: _hasRating
                  ? () => Navigator.pop(context, _rating)
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppColors.violet,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.disabledButton,
                disabledForegroundColor: AppColors.white,
                textStyle: textTheme.titleMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}

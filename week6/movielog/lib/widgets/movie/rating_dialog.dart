import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'movie_rating_input.dart';

/// 별점 고르는 Dialog, 확인 누르면 별점 반환
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.movieId,
    this.initialRating = 0,
  });

  /// TMDB 영화 id (나중에 평점 API movieId로 사용)
  final int movieId;
  final double initialRating;

  static Future<double?> show(
    BuildContext context, {
    required int movieId,
    double initialRating = 0,
  }) {
    return showDialog<double>(
      context: context,
      builder: (context) =>
          RatingDialog(movieId: movieId, initialRating: initialRating),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  /// RatingBar가 초기값만 읽어서 key 바꿔서 다시 그림
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
              // 별점 안 고르면 확인 비활성화
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

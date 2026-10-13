import 'package:flutter/material.dart';

import 'movie_rating_input.dart';

/// 평점을 입력받는 Dialog입니다. 저장하면 선택한 평점을, 취소하면 null을 돌려줍니다.
/// [movieId]는 TMDB 영화의 id이며, 이후 평점 API의 movieId로 사용합니다.
Future<double?> showMovieRatingDialog(
  BuildContext context, {
  required String movieId,
  required String movieTitle,
  double initialRating = 0,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _MovieRatingDialog(
      movieId: movieId,
      movieTitle: movieTitle,
      initialRating: initialRating,
    ),
  );
}

class _MovieRatingDialog extends StatefulWidget {
  const _MovieRatingDialog({
    required this.movieId,
    required this.movieTitle,
    required this.initialRating,
  });

  final String movieId;
  final String movieTitle;
  final double initialRating;

  @override
  State<_MovieRatingDialog> createState() => _MovieRatingDialogState();
}

class _MovieRatingDialogState extends State<_MovieRatingDialog> {
  late double _rating = widget.initialRating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('평점 남기기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.movieTitle, style: textTheme.bodyLarge),
          const SizedBox(height: 20),
          MovieRatingInput(
            rating: _rating,
            onChanged: (value) => setState(() => _rating = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        // 평점을 고르기 전에는 저장 버튼이 비활성화됩니다.
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () {
                  // TODO(평점 API): movieId와 평점을 MovieLog API로 저장합니다.
                  debugPrint('[평점] movieId=${widget.movieId} rating=$_rating');
                  Navigator.of(context).pop(_rating);
                },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

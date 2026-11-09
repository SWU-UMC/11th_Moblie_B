import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/movie/movie_rating_input.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/tmdb_poster_image.dart';

/// W6-02 내가 등록한 평점 (하단 바 없음)
/// 아직 로그인이 없어서 memberId 1 데이터로 조회
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '내가 등록한 평점',
          style: textTheme.titleLarge?.copyWith(color: AppColors.violet),
        ),
        centerTitle: true,
        foregroundColor: AppColors.violet,
      ),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) => switch (viewModel.status) {
          LoadStatus.idle || LoadStatus.loading => const Center(
            child: CircularProgressIndicator(color: AppColors.violet),
          ),
          LoadStatus.error => _MyRatingsError(
            message: viewModel.message ?? '평점을 불러오지 못했습니다.',
            onRetry: viewModel.load,
          ),
          LoadStatus.empty => const MovieListEmpty(message: '아직 등록된 평점이 없어요.'),
          LoadStatus.success => _MyRatingsList(viewModel: viewModel),
        },
      ),
    );
  }
}

class _MyRatingsList extends StatelessWidget {
  const _MyRatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notice = viewModel.message;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // 내 평점처럼 보이지 않게 안내 문구 표시
        Text(
          '학습용 memberId ${viewModel.memberId}의 공개 조회입니다.',
          style: textTheme.labelMedium,
        ),
        if (notice != null) ...[
          const SizedBox(height: 8),
          Text(
            notice,
            style: textTheme.labelMedium?.copyWith(color: AppColors.violet),
          ),
        ],
        const SizedBox(height: 16),
        for (final entry in viewModel.ratings) ...[
          RatingCard(entry: entry),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 평점 카드 (포스터, 제목, 별점, 후기, 등록일)
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.entry});

  final RatingWithMovie entry;

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.violetLight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // 영화 정보 없으면 placeholder
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 72,
              height: 104,
              size: 'w342',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 #${rating.movieId}',
                  style: textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    MovieRatingIndicator(rating: rating.score.toDouble()),
                    const SizedBox(width: 6),
                    Text(
                      '별점 ${rating.score} / 5',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.violet,
                      ),
                    ),
                  ],
                ),
                // 후기 null이면 안 보여줌
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: textTheme.bodyMedium),
                ],
                if (movie == null) ...[
                  const SizedBox(height: 6),
                  Text('포스터 정보 없음', style: textTheme.labelMedium),
                ],
                const SizedBox(height: 6),
                Text(
                  '등록일 ${_formatDate(rating.createdAt)}',
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRatingsError extends StatelessWidget {
  const _MyRatingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            // 고정 너비(120)
            MovieLogButton(label: '다시 시도', width: 120, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

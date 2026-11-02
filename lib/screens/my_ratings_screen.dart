import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_with_movie.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/movie_empty_view.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movie_loading_view.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/tmdb_poster_image.dart';

/// 마이페이지 위에 열리는 "내가 등록한 평점" 화면입니다.
/// 조회 대상은 로그인한 본인이 아니라 학습용 샘플 회원(memberId 1)입니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // bottomNavigationBar를 두지 않습니다. (root Navigator 위에 열리는 자식 화면)
    return Scaffold(
      appBar: MovieLogAppBar(
        title: '내가 등록한 평점',
        titleColor: colors.primary,
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () => context.pop(),
          icon: SvgPicture.asset(
            'assets/icons/arrow_back.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<MyRatingsViewModel>(
          builder: (context, viewModel, _) => switch (viewModel.status) {
            MyRatingsLoadStatus.idle || MyRatingsLoadStatus.loading =>
              const MovieLoadingView(message: '평점을 불러오고 있어요'),
            MyRatingsLoadStatus.empty => MovieEmptyView(
              message: '아직 등록한 평점이 없어요.',
              actionLabel: '새로고침',
              onAction: viewModel.load,
            ),
            MyRatingsLoadStatus.error => MovieErrorView(
              message: viewModel.message,
              onRetry: viewModel.load,
            ),
            MyRatingsLoadStatus.success => _RatingList(
              ratings: viewModel.ratings,
              notice: viewModel.message,
              memberId: viewModel.memberId,
            ),
          },
        ),
      ),
    );
  }
}

class _RatingList extends StatelessWidget {
  const _RatingList({
    required this.ratings,
    required this.notice,
    required this.memberId,
  });

  final List<RatingWithMovie> ratings;
  final String? notice;
  final int memberId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final captionStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: ratings.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          // 로그인한 사용자의 평점이라고 오해하지 않도록 조회 대상을 밝힙니다.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습용 샘플 회원(memberId $memberId)의 평점입니다.',
                style: captionStyle,
              ),
              if (notice != null) ...[
                const SizedBox(height: 4),
                Text(notice!, style: captionStyle),
              ],
            ],
          );
        }
        return _RatingCard(entry: ratings[index - 1]);
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  static const _posterWidth = 82.0;
  static const _posterHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;
    final mutedStyle = textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: movie == null
                // TMDB에서 영화를 찾지 못하면 포스터 자리만 비워 둡니다.
                ? Container(
                    width: _posterWidth,
                    height: _posterHeight,
                    color: colors.surfaceContainerHighest,
                  )
                : TmdbPosterImage(
                    posterPath: movie.posterPath,
                    width: _posterWidth,
                    height: _posterHeight,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 #${rating.movieId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '별점 ${rating.score} / 5',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (movie == null) ...[
                    const SizedBox(height: 8),
                    Text('포스터 정보 없음', style: mutedStyle),
                  ],
                  // 후기가 없으면(null) 표시하지 않습니다.
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment, style: mutedStyle),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(rating.createdAt)} 등록',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 서버 시각(UTC)을 기기 시간대로 바꿔 "2026.11.02" 형식으로 보여줍니다.
  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)}';
  }
}

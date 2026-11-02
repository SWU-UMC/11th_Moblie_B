import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/movie/movie_detail_actions.dart';
import '../widgets/movie/movie_rating_input.dart';
import '../widgets/movie/rating_dialog.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/tmdb_poster_image.dart';

/// W3-03 영화 상세 (5주차: TMDB 영화 id 기준)
class MovieDetailScreen extends StatelessWidget {
  const MovieDetailScreen({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite(BuildContext context, MovieDetailViewModel viewModel) {
    viewModel.toggleFavorite();
    final title = viewModel.movie!.title;
    _showSnackBar(
      context,
      viewModel.isFavorite
          ? '$title을(를) 즐겨찾기에 추가했어요.'
          : '$title을(를) 즐겨찾기에서 삭제했어요.',
    );
  }

  Future<void> _rate(
    BuildContext context,
    MovieDetailViewModel viewModel,
  ) async {
    // 평점 Dialog에도 TMDB 영화 id를 그대로 넘깁니다. (배열 index를 쓰지 않음)
    final rating = await RatingDialog.show(
      context,
      movieId: viewModel.movie!.id,
      initialRating: viewModel.myRating ?? 0,
    );
    if (rating == null || !context.mounted) return;
    viewModel.saveMyRating(rating);
    _showSnackBar(context, '평점 ${rating.toStringAsFixed(1)}점을 남겼어요.');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    final appBar = AppBar(
      leading: IconButton(
        // URL로 바로 들어와 돌아갈 화면이 없으면 홈으로 이동합니다.
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.home),
        icon: const Icon(Icons.arrow_back, color: AppColors.violet),
        tooltip: '뒤로 가기',
      ),
      title: Text(
        'Cinema Archive',
        style: textTheme.titleLarge?.copyWith(color: AppColors.violet),
      ),
      actions: [
        IconButton(
          onPressed: () {}, // 공유는 이후 주차에서 연결합니다.
          icon: const Icon(Icons.share_outlined),
          tooltip: '공유',
        ),
      ],
    );

    final body = switch (viewModel.status) {
      LoadStatus.idle || LoadStatus.loading => const Center(
        child: CircularProgressIndicator(color: AppColors.violet),
      ),
      LoadStatus.empty => const MovieListEmpty(message: '영화를 찾을 수 없어요'),
      LoadStatus.error => MovieListError(
        message: '영화 정보를 불러오지 못했어요.',
        onRetry: viewModel.retry,
      ),
      LoadStatus.success => ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: TmdbPosterImage(
              posterPath: movie!.backdropPath ?? movie.posterPath,
              size: 'w780',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _MovieInfo(
              movie: movie,
              genreNames: viewModel.genreNames,
              myRating: viewModel.myRating,
            ),
          ),
        ],
      ),
    };

    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: movie == null
          ? null
          : MovieDetailActions(
              isFavorite: viewModel.isFavorite,
              onFavoritePressed: () => _toggleFavorite(context, viewModel),
              onRatePressed: () => _rate(context, viewModel),
            ),
    );
  }
}

/// 제목, 기본 정보, 평균 평점, 장르, 줄거리
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({
    required this.movie,
    required this.genreNames,
    required this.myRating,
  });

  final TmdbMovieDto movie;
  final List<String> genreNames;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rating = myRating;
    final runtime = movie.runtime;
    final info = [
      ?movie.releaseYear,
      if (genreNames.isNotEmpty) genreNames.join('/'),
      if (runtime != null && runtime > 0) '$runtime분',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(movie.title, style: textTheme.headlineMedium),
        if (info.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(info, style: textTheme.labelMedium),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            // TMDB 평균 평점(10점 만점)을 별 5개로 읽기 전용 표시합니다.
            MovieRatingIndicator(rating: movie.voteAverage / 2),
            const SizedBox(width: 8),
            Text(
              '${movie.voteAverage.toStringAsFixed(1)} / 10 (${movie.voteCount})',
              style: textTheme.labelMedium,
            ),
          ],
        ),
        if (rating != null) ...[
          const SizedBox(height: 4),
          Text(
            '내 평점 ${rating.toStringAsFixed(1)}',
            style: textTheme.labelMedium?.copyWith(color: AppColors.violet),
          ),
        ],
        if (genreNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in genreNames)
                Chip(
                  label: Text(genre),
                  labelStyle: textTheme.labelMedium,
                  backgroundColor: AppColors.cardBackground,
                  side: const BorderSide(color: AppColors.divider),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const Divider(height: 32, color: AppColors.divider),
        Text('줄거리', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          movie.overview.isEmpty ? '등록된 줄거리가 없어요.' : movie.overview,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

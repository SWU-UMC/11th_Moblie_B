import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/submit_status.dart';
import '../widgets/movie/movie_detail_actions.dart';
import '../widgets/movie/movie_rating_input.dart';
import '../widgets/movie/rating_dialog.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/tmdb_poster_image.dart';

/// W3-03 영화 상세
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

  /// 평점 등록: Dialog가 저장까지 끝내고 true 줄 때만 성공 Snackbar
  Future<void> _rate(
    BuildContext context,
    MovieDetailViewModel viewModel,
  ) async {
    final saved = await RatingDialog.show(
      context,
      onSubmit: (score, comment) async {
        // movieId는 ViewModel이 가진 TMDB id 사용
        await viewModel.createRating(score: score, comment: comment);
        if (viewModel.submitStatus != SubmitStatus.success) {
          throw SubmitFailure(viewModel.submitMessage ?? '저장에 실패했습니다.');
        }
      },
    );
    // 저장 요청이랑 Snackbar는 다른 비동기 경계 → mounted 다시 확인
    if (!context.mounted || saved != true) return;
    _showSnackBar(context, '평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    final appBar = AppBar(
      leading: IconButton(
        // 이전 화면 없으면(URL로 진입) 홈으로 이동
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
          onPressed: () {}, // TODO: 공유
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
              myScore: viewModel.myScore,
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
              // 가입 안 했으면 비활성화 + 회원가입 안내
              onRatePressed: viewModel.canRate
                  ? () => _rate(context, viewModel)
                  : null,
              onSignUpPressed: () => context.push(AppRoutes.register),
            ),
    );
  }
}

/// 제목, 정보, 평점, 장르, 줄거리
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({
    required this.movie,
    required this.genreNames,
    required this.myScore,
  });

  final TmdbMovieDto movie;
  final List<String> genreNames;
  final int? myScore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final score = myScore;
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
            // 10점 만점 → 별 5개로 표시
            MovieRatingIndicator(rating: movie.voteAverage / 2),
            const SizedBox(width: 8),
            Text(
              '${movie.voteAverage.toStringAsFixed(1)} / 10 (${movie.voteCount})',
              style: textTheme.labelMedium,
            ),
          ],
        ),
        if (score != null) ...[
          const SizedBox(height: 4),
          Text(
            '내 평점 $score점 등록됨',
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

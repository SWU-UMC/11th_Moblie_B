import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/load_status.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/submit_status.dart';
import '../widgets/favorite_button.dart';
import '../widgets/movie/movie_detail_actions.dart';
import '../widgets/movie/movie_rating_input.dart';
import '../widgets/movie/rating_dialog.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/tmdb_poster_image.dart';

/// W3-03 영화 상세
/// 9주차: 제목 오른쪽 북마크 = 서버 즐겨찾기 (FavoriteDetailViewModel)
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // build에서 조회 안 함 → 첫 build 끝나고 서버 즐겨찾기 여부 한 번
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// 평점 남기기
  /// - 아직 즐겨찾기 안 한 영화면 Dialog에 "즐겨찾기에도 추가" (Challenge)
  /// - COMMON400·네트워크: Dialog 유지 + 안에 이유
  /// - RATING409_1·FAVORITE409_1·MEMBER404_1: Dialog 닫고 Snackbar
  Future<void> _rate(
    MovieDetailViewModel viewModel,
    FavoriteDetailViewModel favorite,
  ) async {
    final saved = await RatingDialog.show(
      context,
      showAddToFavorite: favorite.hasLoadedStatus && !favorite.isFavorite,
      onSubmit: (score, comment, addToFavorites) async {
        await viewModel.createRating(
          score: score,
          comment: comment,
          addToFavorites: addToFavorites,
        );
        if (viewModel.submitStatus != SubmitStatus.success &&
            !viewModel.submitClosesDialog) {
          throw SubmitFailure(viewModel.submitMessage ?? '저장에 실패했습니다.');
        }
      },
    );
    // 저장 요청이랑 Snackbar는 다른 비동기 경계 → mounted 다시 확인
    if (!mounted || saved != true) return;
    if (viewModel.submitStatus == SubmitStatus.success) {
      _showSnackBar('평점을 저장했습니다.');
    } else {
      _showSnackBar(viewModel.submitMessage ?? '평점을 저장하지 못했습니다.');
    }
    // 같이 저장됐거나 FAVORITE409_1이면 북마크를 서버 값으로 다시 맞춤
    if (!favorite.isDisposed) await favorite.refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<MovieDetailViewModel>();
    final favorite = context.watch<FavoriteDetailViewModel>();
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
              favoriteError: favorite.errorMessage,
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
              // 이번 세션에서 이미 남긴 영화면 비활성화 (409 대신 마이페이지에서 수정)
              onRatePressed: viewModel.canRate
                  ? () => _rate(viewModel, favorite)
                  : null,
            ),
    );
  }
}

/// 제목(+북마크), 정보, 평점, 장르, 줄거리
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({
    required this.movie,
    required this.genreNames,
    required this.myScore,
    required this.favoriteError,
  });

  final TmdbMovieDto movie;
  final List<String> genreNames;
  final int? myScore;

  /// 즐겨찾기 실패 안내 (이전 북마크 상태는 그대로)
  final String? favoriteError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final score = myScore;
    final runtime = movie.runtime;
    final error = favoriteError;
    final info = [
      ?movie.releaseYear,
      if (genreNames.isNotEmpty) genreNames.join('/'),
      if (runtime != null && runtime > 0) '$runtime분',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목·정보 오른쪽에 북마크 (시각 자료 W9 상세)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: textTheme.headlineMedium),
                  if (info.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(info, style: textTheme.labelMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const FavoriteButton(),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _FavoriteErrorBox(message: error),
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

/// 즐겨찾기 실패 박스 (시각 자료 W9 "실패 - 이전 상태 유지")
class _FavoriteErrorBox extends StatelessWidget {
  const _FavoriteErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
        ),
      ),
    );
  }
}

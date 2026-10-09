import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../models/movie.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/movie/movie_detail_actions.dart';
import '../widgets/movie/movie_rating_input.dart';
import '../widgets/movie/rating_dialog.dart';

/// W3-03 영화 상세
///
/// Path Parameter로 받은 영화 ID로 Mock Data를 다시 찾습니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final int? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기와 내 평점은 API 없이 화면 내부 상태로만 관리합니다.
  bool _isFavorite = false;
  double? _myRating;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite(Movie movie) {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(
      _isFavorite
          ? '${movie.title}을(를) 즐겨찾기에 추가했어요.'
          : '${movie.title}을(를) 즐겨찾기에서 삭제했어요.',
    );
  }

  Future<void> _rate() async {
    final rating = await RatingDialog.show(
      context,
      initialRating: _myRating ?? 0,
    );
    if (rating == null || !mounted) return;
    setState(() => _myRating = rating);
    _showSnackBar('평점 ${rating.toStringAsFixed(1)}점을 남겼어요.');
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(widget.movieId);
    final textTheme = Theme.of(context).textTheme;

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

    if (movie == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(child: Text('영화를 찾을 수 없어요', style: textTheme.bodyLarge)),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _MovieInfo(movie: movie, myRating: _myRating),
          ),
        ],
      ),
      bottomNavigationBar: MovieDetailActions(
        isFavorite: _isFavorite,
        onFavoritePressed: () => _toggleFavorite(movie),
        onRatePressed: _rate,
      ),
    );
  }
}

/// 제목, 기본 정보, 평균 평점, 장르, 시놉시스
class _MovieInfo extends StatelessWidget {
  const _MovieInfo({required this.movie, required this.myRating});

  final Movie movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rating = myRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(movie.title, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${movie.year} • ${movie.genres.join('/')} • ${movie.runtimeMinutes}분',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 평균 평점은 읽기 전용으로 표시합니다.
            MovieRatingIndicator(rating: movie.averageRating),
            const SizedBox(width: 8),
            Text(
              '${movie.averageRating.toStringAsFixed(1)} (${movie.ratingCount})',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final genre in movie.genres)
              Chip(
                label: Text(genre),
                labelStyle: textTheme.labelMedium,
                backgroundColor: AppColors.cardBackground,
                side: const BorderSide(color: AppColors.divider),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const Divider(height: 32, color: AppColors.divider),
        Text('시놉시스', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(movie.synopsis, style: textTheme.bodyMedium),
      ],
    );
  }
}

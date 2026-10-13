import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../models/movie.dart';
import '../widgets/movie_rating_dialog.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/tmdb_poster_image.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.tmdbMovie});

  /// 경로의 영화 ID입니다. TMDB 영화는 TMDB id, 추천 카드는 mock id입니다.
  final String movieId;

  /// 목록에서 함께 넘긴 TMDB 영화입니다. 없으면 mock 영화에서 찾습니다.
  final TmdbMovieDto? tmdbMovie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기와 내 평점은 서버 없이 화면 내부 상태로만 관리합니다.
  bool _isFavorite = false;
  double? _myRating;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tmdbMovie = widget.tmdbMovie;
    final mockMovie = findMovieById(widget.movieId);
    final movie = tmdbMovie != null
        ? _DetailData.fromTmdb(tmdbMovie)
        : mockMovie == null
        ? null
        : _DetailData.fromMock(mockMovie);

    return Scaffold(
      appBar: MovieLogAppBar(
        title: 'Cinema Archive',
        titleColor: colors.primary,
        leading: IconButton(
          onPressed: () => _goBack(context),
          icon: SvgPicture.asset(
            'assets/icons/arrow_back.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(colors.primary, BlendMode.srcIn),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {}, // 공유는 이후 과제에서 연결합니다.
            icon: SvgPicture.asset(
              'assets/icons/share.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
            ),
          ),
        ],
      ),
      body: movie == null
          ? const Center(child: Text('영화 정보를 찾을 수 없어요.'))
          : _MovieDetailBody(movie: movie, myRating: _myRating),
      bottomNavigationBar: movie == null
          ? null
          : _DetailActions(
              isFavorite: _isFavorite,
              onFavoritePressed: _toggleFavorite,
              onRatePressed: () => _openRatingDialog(movie),
            ),
    );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.');
  }

  Future<void> _openRatingDialog(_DetailData movie) async {
    final rating = await showMovieRatingDialog(
      context,
      movieId: widget.movieId,
      movieTitle: movie.title,
      initialRating: _myRating ?? 0,
    );
    if (rating == null || !mounted) return;
    setState(() => _myRating = rating);
    _showSnackBar('평점 ${rating.toStringAsFixed(1)}점을 남겼어요.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

/// 상세 화면이 그리는 값입니다. mock 영화와 TMDB 영화를 같은 모양으로 맞춥니다.
class _DetailData {
  const _DetailData({
    required this.title,
    required this.poster,
    required this.meta,
    required this.rating,
    required this.ratingLabel,
    required this.reviewCount,
    required this.tags,
    required this.synopsis,
  });

  factory _DetailData.fromMock(Movie movie) => _DetailData(
    title: movie.title,
    poster: Image.asset(movie.posterPath, fit: BoxFit.cover),
    meta:
        '${movie.year} • ${movie.genres.join('/')} • '
        '${movie.runtimeMinutes}분',
    rating: movie.rating,
    ratingLabel: movie.rating.toStringAsFixed(1),
    reviewCount: movie.reviewCount,
    tags: movie.tags,
    synopsis: movie.synopsis,
  );

  factory _DetailData.fromTmdb(TmdbMovieDto movie) => _DetailData(
    title: movie.title,
    poster: TmdbPosterImage(
      posterPath: movie.posterPath,
      width: double.infinity,
      height: double.infinity,
    ),
    // release_date가 없으면 연도를 표시하지 않습니다.
    meta: movie.releaseYear?.toString() ?? '',
    // TMDB 평점은 10점 만점이므로 별 5개에 맞춰 절반으로 표시합니다.
    rating: movie.voteAverage / 2,
    ratingLabel: '${movie.voteAverage.toStringAsFixed(1)} / 10',
    reviewCount: null,
    tags: const [],
    synopsis: movie.overview,
  );

  final String title;
  final Widget poster;
  final String meta;

  /// 별 5개 기준 평점입니다.
  final double rating;
  final String ratingLabel;
  final int? reviewCount;
  final List<String> tags;
  final String synopsis;
}

class _MovieDetailBody extends StatelessWidget {
  const _MovieDetailBody({required this.movie, required this.myRating});

  final _DetailData movie;
  final double? myRating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 2 / 3, child: movie.poster),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: textTheme.headlineSmall),
                if (movie.meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    movie.meta,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    RatingBarIndicator(
                      rating: movie.rating,
                      itemSize: 22,
                      unratedColor: colors.primary.withValues(alpha: 0.25),
                      itemBuilder: (_, _) =>
                          Icon(Icons.star_rounded, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(movie.ratingLabel, style: textTheme.titleMedium),
                    if (movie.reviewCount case final count?) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${_formatCount(count)})',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (myRating != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '내 평점 ${myRating!.toStringAsFixed(1)}점',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in movie.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tag, style: textTheme.labelLarge),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시놉시스',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (movie.synopsis.isEmpty)
                  // overview가 비어 있으면 안내 문구를 가운데에 보여줍니다.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '줄거리 정보가 없어요.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    movie.synopsis,
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.7,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int count) => count.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onRatePressed,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFavoritePressed,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                  label: Text(isFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRatePressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 20),
                  label: const Text('평점 남기기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

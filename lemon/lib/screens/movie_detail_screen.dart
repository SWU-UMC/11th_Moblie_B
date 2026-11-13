import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../models/movie.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_poster_image.dart';

/// 상세 화면의 AppBar(뒤로 가기·공유)를 공통으로 씁니다. 로딩·오류 화면에서도 같은 모양입니다.
class MovieDetailScaffold extends StatelessWidget {
  const MovieDetailScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
  });

  final Widget body;
  final Widget? bottomNavigationBar;

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
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// 영화 상세 화면입니다.
///
/// TMDB 영화라면 위에 [MovieDetailViewModel]이 있어 평점을 서버에 등록할 수 있고,
/// mock 영화라면 ViewModel이 없어 평점 버튼을 막습니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  final MovieDetailData movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기는 아직 서버 없이 화면 내부 상태로만 관리합니다.
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel?>();

    return MovieDetailScaffold(
      body: _MovieDetailBody(
        movie: widget.movie,
        myScore: viewModel?.lastSavedScore,
      ),
      bottomNavigationBar: _DetailActions(
        isFavorite: _isFavorite,
        onFavoritePressed: _toggleFavorite,
        onRatePressed: viewModel != null && viewModel.canRate
            ? _openRatingDialog
            : null,
        notice: viewModel == null
            ? const _RatingNotice(message: '샘플 영화는 평점을 저장할 수 없어요.')
            : !viewModel.canRate
            ? _RatingNotice(
                message: '평점을 남기려면 학습용 회원가입이 필요해요.',
                actionLabel: '회원가입',
                onAction: () => context.go('/signup'),
              )
            : null,
      ),
    );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했어요.' : '즐겨찾기에서 삭제했어요.');
  }

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        movieTitle: viewModel.movie.title,
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            // Dialog가 입력을 유지한 채 서버 message를 보여줍니다.
            throw RatingWriteFailure(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 mounted를 다시 확인합니다.
    if (!mounted || saved != true) return;
    _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

/// 상세 화면이 그리는 값입니다. mock 영화와 TMDB 영화를 같은 모양으로 맞춥니다.
class MovieDetailData {
  const MovieDetailData({
    required this.title,
    required this.poster,
    required this.meta,
    required this.rating,
    required this.ratingLabel,
    required this.reviewCount,
    required this.tags,
    required this.synopsis,
  });

  factory MovieDetailData.fromMock(Movie movie) => MovieDetailData(
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

  factory MovieDetailData.fromTmdb(TmdbMovieDto movie) => MovieDetailData(
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
  const _MovieDetailBody({required this.movie, required this.myScore});

  final MovieDetailData movie;

  /// 이 화면에서 방금 서버에 등록한 별점입니다.
  final int? myScore;

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
                if (myScore != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '내 평점 $myScore점 등록 완료',
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
    this.notice,
  });

  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  /// null이면 평점 버튼이 비활성입니다. (mock 영화, 회원가입 전)
  final VoidCallback? onRatePressed;

  /// 평점 버튼을 누를 수 없는 이유입니다. 버튼 위에 보여줍니다.
  final Widget? notice;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?notice,
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 평점 버튼을 누를 수 없는 이유와, 필요하면 바로 갈 수 있는 버튼입니다.
class _RatingNotice extends StatelessWidget {
  const _RatingNotice({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actionLabel = this.actionLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

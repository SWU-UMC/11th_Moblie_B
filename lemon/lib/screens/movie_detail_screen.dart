import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../models/movie.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/favorite_button.dart';
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
/// TMDB 영화라면 위에 [MovieDetailViewModel]이 있어 토큰으로 평점을 등록·수정·삭제할 수 있고,
/// mock 영화라면 ViewModel이 없어 평점 버튼을 막습니다.
/// 즐겨찾기도 TMDB 영화에만 [FavoriteDetailViewModel]이 있어 제목 옆 북마크로 등록·해제합니다.
/// 등록 result로 받은 Rating 객체를 "내 평점" 카드로 보여주고, 같은 카드에서 수정·삭제합니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  final MovieDetailData movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 서버의 즐겨찾기 여부를 한 번 조회합니다. (build에서 조회하지 않습니다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel?>()?.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel?>();
    final myRating = viewModel?.myRating;
    final hasFavorite = context.read<FavoriteDetailViewModel?>() != null;

    return MovieDetailScaffold(
      body: _MovieDetailBody(
        movie: widget.movie,
        myRating: myRating,
        favoriteButton: hasFavorite ? const FavoriteButton() : null,
        onEdit: _openRatingDialog,
        onDelete: _openDeleteDialog,
      ),
      bottomNavigationBar: _DetailActions(
        rateLabel: myRating == null ? '평점 남기기' : '평점 수정',
        onRatePressed: viewModel != null ? _openRatingDialog : null,
        notice: viewModel == null
            ? const _RatingNotice(message: '샘플 영화는 평점을 저장할 수 없어요.')
            : null,
      ),
    );
  }

  /// 내 평점이 없으면 등록, 있으면 기존 별점·코멘트를 채운 같은 Dialog로 수정합니다.
  /// PATCH는 전체 교체라 Dialog가 기존 comment를 채워 두어야 후기가 지워지지 않습니다.
  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final existing = viewModel.myRating;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        movieTitle: viewModel.movie.title,
        initialScore: existing?.score ?? 0,
        initialComment: existing?.comment,
        onSubmit: (score, comment) async {
          if (existing == null) {
            await viewModel.createRating(score: score, comment: comment);
          } else {
            await viewModel.updateRating(score: score, comment: comment);
          }
          _throwIfFailed(viewModel);
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 mounted를 다시 확인합니다.
    if (!mounted || saved != true) return;
    _showSnackBar(existing == null ? '평점을 등록했습니다.' : '평점을 수정했습니다.');
  }

  /// 삭제는 확인 Dialog 안에서 진행하고, 실패하면 Dialog에 문구를 남깁니다.
  Future<void> _openDeleteDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    if (viewModel.myRating == null) return;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteRatingDialog(
        onConfirm: () async {
          await viewModel.deleteRating();
          _throwIfFailed(viewModel);
        },
      ),
    );
    if (!mounted || deleted != true) return;
    _showSnackBar('평점을 삭제했습니다.');
  }

  /// Dialog가 입력을 유지한 채 문구를 보여주도록 실패를 예외로 바꿉니다.
  /// 401이면 세션이 이미 정리되어 Router가 로그인 화면으로 이동합니다.
  static void _throwIfFailed(MovieDetailViewModel viewModel) {
    if (viewModel.submitStatus == SubmitStatus.success) return;
    throw RatingWriteFailure(
      viewModel.submitMessage ?? '저장에 실패했습니다.',
      sessionExpired: viewModel.submitSessionExpired,
    );
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
  const _MovieDetailBody({
    required this.movie,
    required this.myRating,
    required this.onEdit,
    required this.onDelete,
    this.favoriteButton,
  });

  final MovieDetailData movie;

  /// 제목·정보 오른쪽의 북마크 버튼입니다. mock 영화는 null입니다.
  final Widget? favoriteButton;

  /// 이번 로그인 세션에서 이 영화에 등록한 평점입니다. (등록·수정 result의 Rating 객체)
  final RatingDto? myRating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                // 제목·정보 텍스트를 Row로 감싸고 오른쪽에 북마크 버튼을 둡니다.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                        ],
                      ),
                    ),
                    if (favoriteButton case final button?) ...[
                      const SizedBox(width: 12),
                      button,
                    ],
                  ],
                ),
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
                if (myRating case final rating?) ...[
                  const SizedBox(height: 16),
                  _MyRatingCard(
                    rating: rating,
                    onEdit: onEdit,
                    onDelete: onDelete,
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
    required this.onRatePressed,
    required this.rateLabel,
    this.notice,
  });

  /// 내 평점이 없으면 "평점 남기기", 있으면 "평점 수정"입니다.
  final String rateLabel;

  /// null이면 평점 버튼이 비활성입니다. (mock 영화)
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
              // 즐겨찾기 버튼은 제목 옆 북마크로 옮겨, 평점 버튼이 전체 너비를 씁니다.
              Row(
                children: [
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
                      label: Text(rateLabel),
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

/// 평점 버튼을 누를 수 없는 이유입니다.
class _RatingNotice extends StatelessWidget {
  const _RatingNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
        ],
      ),
    );
  }
}

/// 이번 로그인 세션에서 등록한 내 평점 카드입니다. 수정·삭제 결과도 서버 응답으로 바로 바뀝니다.
class _MyRatingCard extends StatelessWidget {
  const _MyRatingCard({
    required this.rating,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingDto rating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 평점 ${rating.score}점',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text('수정', semanticsLabel: '내 평점 수정'),
          ),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('삭제', semanticsLabel: '내 평점 삭제'),
          ),
        ],
      ),
    );
  }
}

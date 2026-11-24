import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/movie/movie_summary_card.dart';
import '../widgets/movielog_button.dart';

/// W9 내 즐겨찾기 (/my/favorites, 하단 바 없음)
/// 목록 / 빈 목록 / 조회 오류 / 영화 정보 일부 실패 4가지
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  /// 상세로 push → 돌아올 때까지 기다림 (돌아오면 목록 다시 조회)
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // refresh가 바로 notify해서 첫 build 끝난 뒤 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    // 상세에서 해제했을 수 있음 → 다시 조회 (ViewModel이 같은 세션인지 다시 확인)
    await vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();

    final Widget body = switch (vm.phase) {
      LoadPhase.idle || LoadPhase.loading => const Center(
        child: CircularProgressIndicator(
          color: AppColors.violet,
          semanticsLabel: '내 즐겨찾기 불러오는 중',
        ),
      ),
      LoadPhase.empty => const _FavoritesEmpty(),
      LoadPhase.error => _FavoritesError(
        message: vm.errorMessage ?? '즐겨찾기를 불러오지 못했습니다.',
        onRetry: vm.refresh,
      ),
      LoadPhase.ready => RefreshIndicator(
        color: AppColors.violet,
        onRefresh: vm.refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          itemCount: vm.items.length + 1,
          separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 0 : 14),
          itemBuilder: (context, index) {
            // 0번: 목록 다시 불러오기 실패 안내 (이전 목록은 유지)
            if (index == 0) {
              final message = vm.errorMessage;
              if (message == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              );
            }
            final item = vm.items[index - 1];
            return _FavoriteCard(
              item: item,
              onOpen: (movie) => _open(vm, movie),
              onRetry: () => vm.retryMovie(item.favorite.favoriteId),
            );
          },
        ),
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        title: const Text(
          '내 즐겨찾기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.violet,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.screenBackground,
        foregroundColor: AppColors.textPrimary,
      ),
      body: body,
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.onOpen,
    required this.onRetry,
  });

  final FavoriteListItem item;
  final ValueChanged<TmdbMovieDto> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final movie = item.movie;
    if (movie != null) {
      return MovieSummaryCard(
        key: ValueKey('favorite-${item.favorite.favoriteId}'),
        movie: movie,
        title: movie.title,
        subtitle: movieSummaryLine(movie),
        tag: '즐겨찾기한 영화',
        onTap: () => onOpen(movie),
      );
    }

    // TMDB 정보 한 건 실패: 다른 카드는 그대로, 이 카드만 재조회
    return MovieSummaryCard(
      key: ValueKey('favorite-${item.favorite.favoriteId}'),
      title: '영화 #${item.favorite.movieId}',
      subtitle: item.isRetrying
          ? '영화 정보를 다시 불러오는 중…'
          : (item.errorMessage ?? '영화 정보가 없습니다.'),
      tag: '즐겨찾기한 영화',
      action: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: TextButton(
          onPressed: item.isRetrying ? null : onRetry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.violet,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('정보 다시 불러오기'),
        ),
      ),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 34, color: AppColors.violet),
            SizedBox(height: 18),
            Text(
              '아직 즐겨찾기한 영화가 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '영화 상세에서 북마크를 눌러보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 22),
            MovieLogButton(
              label: '다시 시도',
              width: 200,
              borderRadius: 10,
              fontSize: 14,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

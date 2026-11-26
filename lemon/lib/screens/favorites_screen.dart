import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/movie_row_card.dart';
import '../widgets/movielog_button.dart';

/// 내 즐겨찾기 화면입니다. (`/my/favorites`, 하단 NavigationBar 없음)
///
/// 목록 / 빈 목록 / 조회 오류 / 영화 정보 한 건 실패를 서로 다른 모양으로 보여줍니다.
/// 카드를 눌러 상세에 다녀오면 목록을 다시 조회해 해제한 영화를 뺍니다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // build에서 조회하지 않고, 첫 프레임 뒤 한 번만 요청합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    // 상세에서 해제했을 수 있으므로 돌아오면 다시 조회합니다.
    // ViewModel이 같은 세션인지 다시 확인하므로 계정이 바뀌었다면 반영하지 않습니다.
    await vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '내 즐겨찾기',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<FavoritesViewModel>(
        builder: (context, vm, _) => switch (vm.phase) {
          LoadPhase.idle ||
          LoadPhase.loading => const Center(child: CircularProgressIndicator()),
          LoadPhase.empty => const _FavoritesEmpty(),
          LoadPhase.error => _FavoritesError(
            message: vm.errorMessage ?? '즐겨찾기를 불러오지 못했습니다.',
            onRetry: vm.refresh,
          ),
          LoadPhase.ready => RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: vm.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = vm.items[index];
                final movie = item.movie;
                final movieId = item.favorite.movieId;
                return MovieRowCard(
                  key: ValueKey(item.favorite.favoriteId),
                  movie: movie,
                  fallbackTitle: 'TMDB #$movieId',
                  caption: movie == null
                      ? item.errorMessage ?? '영화 정보가 없습니다.'
                      : [
                          ?movie.releaseYear?.toString(),
                          'TMDB #${movie.id}',
                        ].join(' · '),
                  badge: '즐겨찾기한 영화',
                  onTap: movie == null ? null : () => _open(vm, movie),
                  // 정보를 못 가져온 카드만 그 카드의 TMDB 정보를 다시 요청합니다.
                  onRetry: movie == null ? () => vm.retryMovie(movieId) : null,
                  retrying: vm.retryingMovieIds.contains(movieId),
                );
              },
            ),
          ),
        },
      ),
    );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 40, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              '아직 즐겨찾기한 영화가 없습니다.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '영화 상세에서 북마크를 눌러보세요.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            MovieLogButton(label: '다시 시도', width: 220, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

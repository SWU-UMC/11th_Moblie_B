import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/mock_movies.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/featured_movie_card.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/popular_movie_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final featured = mockMovies.first;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: 'MovieLog',
        titleColor: AppColors.primaryDark,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {}, // 검색은 이후 과제에서 연결합니다.
            icon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryDark,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '오늘은 어떤\n영화를 볼까요?',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              FeaturedMovieCard(
                movie: featured,
                onTap: () => context.push('/movies/${featured.id}'),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '인기 영화',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/movies'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체보기'),
                        Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 인기 영화 영역만 ViewModel 상태에 맞춰 다시 그립니다.
              SizedBox(
                height: 260,
                child: Consumer<MovieHomeViewModel>(
                  builder: (context, viewModel, child) {
                    return switch (viewModel.status) {
                      MovieHomeLoadStatus.idle || MovieHomeLoadStatus.loading =>
                        const Center(child: CircularProgressIndicator()),
                      MovieHomeLoadStatus.error => _PopularMessage(
                        message: viewModel.message ?? '인기 영화를 불러오지 못했어요.',
                        onRetry: () =>
                            context.read<MovieHomeViewModel>().loadPopular(),
                      ),
                      MovieHomeLoadStatus.empty => const _PopularMessage(
                        message: '지금은 인기 영화가 없어요.',
                      ),
                      MovieHomeLoadStatus.success => _PopularList(
                        movies: viewModel.popularMovies,
                      ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularList extends StatelessWidget {
  const _PopularList({required this.movies});

  final List<TmdbMovieDto> movies;

  @override
  Widget build(BuildContext context) {
    // ViewModel이 이미 최대 5개로 줄였으므로 길이만큼만 그립니다.
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: movies.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return SizedBox(
          width: 140,
          child: PopularMovieCard(
            rank: index + 1,
            movie: movie,
            // TMDB id를 그대로 넘겨 이후 평점 movieId로 사용합니다.
            onTap: () => context.push('/movies/${movie.id}', extra: movie),
          ),
        );
      },
    );
  }
}

class _PopularMessage extends StatelessWidget {
  const _PopularMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}

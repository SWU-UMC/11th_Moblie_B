import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/home/featured_movie_card.dart';
import '../widgets/home/popular_movie_list.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';

/// W3-01 홈 (5주차: TMDB Popular 앞 5개)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MovieLog',
          style: textTheme.titleLarge?.copyWith(
            color: AppColors.violet,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {}, // 검색은 이후 주차에서 연결합니다.
            icon: const Icon(Icons.search, color: AppColors.violet),
            tooltip: '검색',
          ),
        ],
      ),
      // 상태가 바뀌면 이 Consumer 영역만 다시 그립니다.
      body: Consumer<MovieHomeViewModel>(
        builder: (context, viewModel, child) => switch (viewModel.status) {
          LoadStatus.idle || LoadStatus.loading => const Center(
            child: CircularProgressIndicator(color: AppColors.violet),
          ),
          LoadStatus.error => MovieListError(
            message: viewModel.message ?? '인기 영화를 불러오지 못했어요.',
            onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
          ),
          LoadStatus.empty => const MovieListEmpty(message: '지금은 인기 영화가 없어요.'),
          LoadStatus.success => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  '오늘은 어떤\n영화를 볼까요?',
                  style: textTheme.headlineMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FeaturedMovieCard(movie: viewModel.featuredMovie!),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('인기 영화', style: textTheme.titleLarge),
                    TextButton(
                      // 영화 탭으로 전환합니다.
                      onPressed: () => context.go(AppRoutes.movies),
                      child: const Text('전체보기 >'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              PopularMovieList(movies: viewModel.popularMovies),
            ],
          ),
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../theme/app_colors.dart';
import '../widgets/featured_movie_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/movielog_app_bar.dart';

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
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mockMovies.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final movie = mockMovies[index];
                    return SizedBox(
                      width: 140,
                      child: MovieCard(
                        movie: movie,
                        onTap: () => context.push('/movies/${movie.id}'),
                      ),
                    );
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

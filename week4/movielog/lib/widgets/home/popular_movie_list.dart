import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';

/// 홈의 "인기 영화" 가로 목록 (순위 번호 + 포스터 + 평점)
class PopularMovieList extends StatelessWidget {
  const PopularMovieList({super.key, required this.movies});

  final List<Movie> movies;

  static const _itemWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: _itemWidth,
          child: _PopularMovieItem(rank: index + 1, movie: movies[index]),
        ),
      ),
    );
  }
}

class _PopularMovieItem extends StatelessWidget {
  const _PopularMovieItem({required this.rank, required this.movie});

  final int rank;
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppRoutes.movieDetailOf(movie.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Text(
                    '$rank',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            style: textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '★ ${movie.averageRating.toStringAsFixed(1)}',
            style: textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

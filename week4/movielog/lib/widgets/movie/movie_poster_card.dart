import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';

/// 영화 목록 Grid의 카드 한 칸. 누르면 상세 화면으로 push합니다.
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      // 투명한 여백을 눌러도 Tap이 되도록 합니다.
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
                  top: 8,
                  right: 8,
                  child: RatingBadge(rating: movie.averageRating),
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
            '${movie.year} · ${movie.mainGenre}',
            style: textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// 포스터 위에 올리는 "★ 4.5" 배지
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.posterBadge,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '★ ${rating.toStringAsFixed(1)}',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../tmdb_poster_image.dart';

/// 영화 목록 카드. 누르면 상세로 push
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({super.key, required this.movie, this.genreName});

  final TmdbMovieDto movie;

  /// 대표 장르 이름
  final String? genreName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = [?movie.releaseYear, ?genreName].join(' · ');

    return GestureDetector(
      // 빈 공간 눌러도 탭 되게 함
      behavior: HitTestBehavior.opaque,
      onTap: () => openMovieDetail(context, movie),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TmdbPosterImage(posterPath: movie.posterPath),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: RatingBadge(rating: movie.voteAverage),
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
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// 상세로 이동 (path: id, extra: 영화 정보)
void openMovieDetail(BuildContext context, TmdbMovieDto movie) {
  context.push(AppRoutes.movieDetailOf(movie.id), extra: movie);
}

/// 포스터 위 평점 배지 (10점 만점)
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

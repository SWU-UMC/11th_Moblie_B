import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'tmdb_poster_image.dart';

/// 내 즐겨찾기·검색 결과에서 쓰는 가로형 영화 카드입니다. (포스터 + 제목 + 보조 문구)
///
/// [movie]가 null이면 TMDB 정보를 못 가져온 카드라 포스터 자리를 비워 두고,
/// [onRetry]가 있으면 "정보 다시 불러오기"를 보여줍니다.
class MovieRowCard extends StatelessWidget {
  const MovieRowCard({
    super.key,
    required this.movie,
    required this.fallbackTitle,
    this.caption,
    this.badge,
    this.onTap,
    this.onRetry,
    this.retrying = false,
  });

  final TmdbMovieDto? movie;

  /// 영화 정보가 없을 때 대신 보여줄 제목입니다. (예: TMDB #550)
  final String fallbackTitle;

  /// 제목 아래 회색 문구입니다. (개봉 연도·오류 안내 등)
  final String? caption;

  /// 보라색 강조 문구입니다. (예: 즐겨찾기한 영화)
  final String? badge;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final movie = this.movie;
    final title = movie?.title ?? fallbackTitle;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: movie == null
                    ? Container(
                        width: 78,
                        height: 116,
                        color: colors.primary.withValues(alpha: 0.12),
                      )
                    : TmdbPosterImage(
                        posterPath: movie.posterPath,
                        width: 78,
                        height: 116,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (caption case final text?) ...[
                      const SizedBox(height: 6),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (badge case final text?) ...[
                      const SizedBox(height: 8),
                      Text(
                        text,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (onRetry != null) ...[
                      const SizedBox(height: 4),
                      retrying
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('정보 다시 불러오기'),
                            ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.chevron_right, color: colors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

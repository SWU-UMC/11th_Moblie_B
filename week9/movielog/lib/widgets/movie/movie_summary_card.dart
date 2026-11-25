import 'package:flutter/material.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../../theme/app_colors.dart';
import '../tmdb_poster_image.dart';

/// 포스터 + 제목 + 설명 + 보라 글자 한 줄 가로 카드
/// 내 즐겨찾기·검색 결과에서 같이 씀 (시각 자료 W9 카드)
/// movie null이면 포스터 자리에 연보라 placeholder
class MovieSummaryCard extends StatelessWidget {
  const MovieSummaryCard({
    super.key,
    required this.title,
    this.movie,
    this.subtitle,
    this.tag,
    this.onTap,
    this.action,
  });

  final TmdbMovieDto? movie;
  final String title;
  final String? subtitle;

  /// "즐겨찾기한 영화" 같은 보라 글자
  final String? tag;
  final VoidCallback? onTap;

  /// tag 아래 추가 버튼 (정보 다시 불러오기)
  final Widget? action;

  static const _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const _subtitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  static const _tagStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.violet,
  );

  @override
  Widget build(BuildContext context) {
    final current = movie;
    final sub = subtitle;
    final label = tag;
    final extra = action;

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
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
                borderRadius: BorderRadius.circular(8),
                child: current == null
                    ? Container(
                        width: 70,
                        height: 104,
                        color: AppColors.violetLight,
                      )
                    : TmdbPosterImage(
                        posterPath: current.posterPath,
                        width: 70,
                        height: 104,
                        size: 'w185',
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: _titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sub != null && sub.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          sub,
                          style: _subtitleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (label != null) ...[
                        const SizedBox(height: 10),
                        Text(label, style: _tagStyle),
                      ],
                      ?extra,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2024 · 평점 7.5" 같은 한 줄 설명
String movieSummaryLine(TmdbMovieDto movie) {
  final parts = [
    ?movie.releaseYear,
    if (movie.voteAverage > 0) '평점 ${movie.voteAverage.toStringAsFixed(1)}',
  ];
  return parts.isEmpty ? '개봉 정보 없음' : parts.join(' · ');
}

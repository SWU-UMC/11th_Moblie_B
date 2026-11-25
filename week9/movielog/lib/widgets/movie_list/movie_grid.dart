import 'package:flutter/material.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../movie/movie_poster_card.dart';

/// 영화 카드 2열 Grid + 맨 아래 footer (9주차 더 보기·추가 로딩·끝)
/// controller는 무한 스크롤(남은 거리 확인)용
class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    this.genreNameOf,
    this.footer,
    this.controller,
  });

  final List<TmdbMovieDto> movies;

  /// 대표 장르 이름
  final String? Function(TmdbMovieDto movie)? genreNameOf;

  /// Grid 아래 한 줄 (MoviePageFooter)
  final Widget? footer;
  final ScrollController? controller;

  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 16,
    childAspectRatio: 0.55,
  );

  static const padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  @override
  Widget build(BuildContext context) {
    final bottom = footer;
    return CustomScrollView(
      controller: controller,
      // 목록 짧아도 당겨서 새로고침 되게 함
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          // footer 있으면 아래 여백은 footer가 가짐
          padding: bottom == null ? padding : padding.copyWith(bottom: 0),
          sliver: SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return MoviePosterCard(
                movie: movie,
                genreName: genreNameOf?.call(movie),
              );
            },
          ),
        ),
        if (bottom != null) SliverToBoxAdapter(child: bottom),
      ],
    );
  }
}

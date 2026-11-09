import 'package:flutter/material.dart';

import '../../data/models/tmdb_movie_dto.dart';
import '../movie/movie_poster_card.dart';

/// 영화 카드 2열 Grid
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, this.genreNameOf});

  final List<TmdbMovieDto> movies;

  /// 대표 장르 이름
  final String? Function(TmdbMovieDto movie)? genreNameOf;

  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 16,
    childAspectRatio: 0.55,
  );

  static const padding = EdgeInsets.fromLTRB(16, 8, 16, 24);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // 목록 짧아도 당겨서 새로고침 되게 함
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: movies.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MoviePosterCard(
          movie: movie,
          genreName: genreNameOf?.call(movie),
        );
      },
    );
  }
}

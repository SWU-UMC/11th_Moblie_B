import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import 'movie_card.dart';

/// 영화 목록 화면의 2열 포스터 Grid입니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies, this.genres = const []});

  final List<TmdbMovieDto> movies;

  /// 카드에 장르 이름을 표시하기 위한 TMDB 장르 목록입니다.
  final List<TmdbGenreDto> genres;

  @override
  Widget build(BuildContext context) {
    final genreNames = {for (final genre in genres) genre.id: genre.name};

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        final firstGenreId = movie.genreIds.firstOrNull;
        return MovieCard(
          movie: movie,
          genreName: firstGenreId == null ? null : genreNames[firstGenreId],
          // TMDB id를 경로로, DTO를 extra로 넘겨 상세·평점에서 그대로 씁니다.
          onTap: () => context.push('/movies/${movie.id}', extra: movie),
        );
      },
    );
  }
}

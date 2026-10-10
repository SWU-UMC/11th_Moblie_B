import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import 'movie_card.dart';

/// 영화 목록 화면의 2열 포스터 Grid입니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) => GridView.builder(
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
      return MovieCard(
        movie: movie,
        onTap: () => context.push('/movies/${movie.id}'),
      );
    },
  );
}

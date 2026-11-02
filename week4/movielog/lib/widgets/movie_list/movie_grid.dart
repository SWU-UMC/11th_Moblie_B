import 'package:flutter/material.dart';

import '../../models/movie.dart';
import '../movie/movie_poster_card.dart';

/// 영화 목록 Success 상태: 3주차 MoviePosterCard를 2열 Grid로 배치합니다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({super.key, required this.movies});

  final List<Movie> movies;

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
      // 목록이 짧아도 당겨서 새로고침할 수 있도록 항상 스크롤 가능하게 둡니다.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: movies.length,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) => MoviePosterCard(movie: movies[index]),
    );
  }
}

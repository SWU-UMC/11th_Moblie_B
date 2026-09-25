import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_card.dart';
import '../widgets/movielog_app_bar.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  String _selectedGenre = allGenresLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final movies = moviesByGenre(_selectedGenre);

    return Scaffold(
      appBar: MovieLogAppBar(
        title: '영화',
        titleColor: colors.primary,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {}, // 검색은 이후 과제에서 연결합니다.
            icon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreFilterChips(
            genres: movieGenres,
            selectedGenre: _selectedGenre,
            onSelected: (genre) => setState(() => _selectedGenre = genre),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: movies.isEmpty
                ? Center(
                    child: Text(
                      '해당 장르의 영화가 없어요.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                  ),
          ),
        ],
      ),
    );
  }
}

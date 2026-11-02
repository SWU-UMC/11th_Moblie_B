import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/movie/genre_chip_bar.dart';
import '../widgets/movie/genre_filter_sheet.dart';
import '../widgets/movie/movie_poster_card.dart';

/// W3-02 영화 목록
///
/// 선택한 장르는 화면 State가 아니라 URL Query Parameter(?genre=)에 있습니다.
/// 장르를 바꾸면 새 URL로 go하고, Router가 [selectedGenres]를 다시 넘겨줍니다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, this.selectedGenres = const {}});

  final Set<String> selectedGenres;

  void _applyGenres(BuildContext context, Set<String> genres) {
    context.go(AppRoutes.moviesWithGenres(genres));
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await GenreFilterSheet.show(
      context,
      genres: allGenres,
      selected: selectedGenres,
    );
    // 확인 없이 닫으면 null → 필터를 바꾸지 않습니다.
    if (result == null || !context.mounted) return;
    _applyGenres(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = filterMoviesByGenres(selectedGenres);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: textTheme.titleLarge?.copyWith(color: AppColors.violet),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _openFilterSheet(context),
            icon: Badge(
              isLabelVisible: selectedGenres.isNotEmpty,
              label: Text('${selectedGenres.length}'),
              child: const Icon(Icons.filter_list, color: AppColors.violet),
            ),
            tooltip: '장르 필터',
          ),
        ],
      ),
      body: Column(
        children: [
          GenreChipBar(
            genres: allGenres,
            selectedGenres: selectedGenres,
            onSelected: (genres) => _applyGenres(context, genres),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('선택한 장르의 영화가 없어요', style: textTheme.bodyLarge),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.55,
                        ),
                    itemBuilder: (context, index) =>
                        MoviePosterCard(movie: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

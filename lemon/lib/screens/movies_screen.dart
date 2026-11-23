import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/load_phase.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_empty_view.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_loading_view.dart';
import '../widgets/movie_page_footer.dart';
import '../widgets/movielog_app_bar.dart';

/// TMDB Discover 영화를 "더 보기"로 한 page씩 보여주는 화면입니다.
///
/// 장르 목록·선택은 [MovieListViewModel], 영화 page는 [PagedMoviesViewModel]이 관리합니다.
/// 장르를 바꾸면 이전 목록을 비우고 첫 page부터 다시 불러오며, 이전 장르의 늦은 응답은 버립니다.
class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  /// 장르 목록(저장된 장르 복원 포함)을 먼저 받은 뒤 그 장르의 첫 page를 요청합니다.
  Future<void> _start() async {
    final genres = context.read<MovieListViewModel>();
    final paged = context.read<PagedMoviesViewModel>();
    await genres.loadGenres();
    if (!mounted) return;
    await paged.loadInitial(genreId: genres.selectedGenreId);
  }

  void _selectGenre(int? genreId) {
    context.read<MovieListViewModel>().selectGenre(genreId);
    context.read<PagedMoviesViewModel>().loadInitial(genreId: genreId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final genres = context.watch<MovieListViewModel>();
    return Scaffold(
      appBar: MovieLogAppBar(
        title: '영화',
        titleColor: colors.primary,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '영화 검색',
            onPressed: () => context.push('/movies/search'),
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
          // 요청 중에도 장르를 바꿀 수 있습니다. 이전 요청의 응답은 generation으로 버립니다.
          GenreFilterChips(
            genres: genres.genres,
            selectedGenreId: genres.selectedGenreId,
            onSelected: _selectGenre,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, paged, _) =>
                  _buildContent(context, genres, paged),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MovieListViewModel genres,
    PagedMoviesViewModel paged,
  ) {
    return switch (paged.phase) {
      LoadPhase.idle || LoadPhase.loading => const MovieLoadingView(),
      LoadPhase.error => MovieErrorView(
        message: paged.errorMessage,
        onRetry: _start,
      ),
      LoadPhase.empty => _buildEmpty(genres),
      LoadPhase.ready => MovieGrid(
        movies: paged.movies,
        genres: genres.genres,
        footer: MoviePageFooter(vm: paged),
      ),
    };
  }

  Widget _buildEmpty(MovieListViewModel genres) {
    final genreName = genres.selectedGenreName;
    if (genreName == null) {
      return const MovieEmptyView(message: '아직 등록된 영화가 없어요.');
    }
    return MovieEmptyView(
      message: '$genreName 장르의 영화가 없어요.',
      actionLabel: '전체 영화 보기',
      onAction: () => _selectGenre(null),
    );
  }
}

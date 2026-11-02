import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../view_models/movie_list_view_model.dart';
import '../widgets/genre_filter_chips.dart';
import '../widgets/movie_empty_view.dart';
import '../widgets/movie_error_view.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_loading_view.dart';
import '../widgets/movielog_app_bar.dart';

/// TMDB Discover 영화 최대 30개와 장르 필터를 보여주는 화면입니다.
/// 상태는 Route에서 만든 MovieListViewModel이 관리합니다.
class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      // AppBar는 그대로 두고, 상태가 바뀌면 장르 Chip과 목록 영역만 다시 그립니다.
      body: Consumer<MovieListViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            children: [
              const SizedBox(height: 8),
              GenreFilterChips(
                genres: viewModel.genres,
                selectedGenreId: viewModel.selectedGenreId,
                // Discover 요청 중에는 장르를 바꿀 수 없습니다.
                enabled: !viewModel.isLoading,
                onSelected: viewModel.selectGenre,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildContent(context, viewModel)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, MovieListViewModel viewModel) {
    return switch (viewModel.status) {
      MovieListLoadStatus.idle ||
      MovieListLoadStatus.loading => const MovieLoadingView(),
      MovieListLoadStatus.error => MovieErrorView(
        message: viewModel.message,
        onRetry: () => context.read<MovieListViewModel>().loadInitial(),
      ),
      MovieListLoadStatus.empty => _buildEmpty(context, viewModel),
      MovieListLoadStatus.success => MovieGrid(
        movies: viewModel.movies,
        genres: viewModel.genres,
      ),
    };
  }

  Widget _buildEmpty(BuildContext context, MovieListViewModel viewModel) {
    final genreName = viewModel.selectedGenreName;
    if (genreName == null) {
      return const MovieEmptyView(message: '아직 등록된 영화가 없어요.');
    }
    return MovieEmptyView(
      message: '$genreName 장르의 영화가 없어요.',
      actionLabel: '전체 영화 보기',
      onAction: () => context.read<MovieListViewModel>().selectGenre(null),
    );
  }
}

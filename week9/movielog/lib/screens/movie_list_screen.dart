import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_sort.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../view_models/load_phase.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/movie/genre_chip_bar.dart';
import '../widgets/movie/genre_filter_sheet.dart';
import '../widgets/movie_list/movie_grid.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/movie_list/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

/// W3-02 영화 목록 + 9주차 페이지네이션
/// - 첫 page만 불러오고 아래 footer(더 보기·추가 로딩·재시도·끝)
/// - Challenge: 끝에 가까워지면 다음 page 자동 요청 (무한 스크롤)
/// - AppBar 검색 아이콘 → /movies/search
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  /// 남은 스크롤이 이만큼 이하면 다음 page 요청
  static const loadMoreThreshold = 400.0;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Challenge 무한 스크롤
  /// 실패한 뒤엔 자동으로 계속 보내지 않고 "다음 페이지 다시 시도" 눌러야 함
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final paged = context.read<PagedMoviesViewModel>();
    if (paged.loadMoreError != null) return;
    if (_scrollController.position.extentAfter <=
        MovieListScreen.loadMoreThreshold) {
      // 중복 요청은 ViewModel이 막음 (isLoadingMore·hasMore 확인)
      paged.loadNextPage();
    }
  }

  Future<void> _openFilterSheet(MovieListViewModel viewModel) async {
    final result = await GenreFilterSheet.show(
      context,
      genres: viewModel.genres,
      selected: viewModel.selectedGenreIds,
    );
    // 그냥 닫으면 null → 장르 안 바꿈
    if (result == null || !mounted) return;
    await viewModel.selectGenres(result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<MovieListViewModel>();
    final paged = context.watch<PagedMoviesViewModel>();

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
            key: const ValueKey('movie-search-button'),
            onPressed: () => context.push(AppRoutes.movieSearch),
            icon: const Icon(Icons.search),
            color: AppColors.violet,
            tooltip: '영화 검색',
          ),
          PopupMenuButton<MovieSort>(
            tooltip: '정렬',
            icon: const Icon(Icons.sort, color: AppColors.violet),
            onSelected: viewModel.changeSort,
            itemBuilder: (context) => [
              for (final sort in MovieSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == viewModel.sort,
                  child: Text(sort.label),
                ),
            ],
          ),
          IconButton(
            onPressed: viewModel.genres.isNotEmpty
                ? () => _openFilterSheet(viewModel)
                : null,
            icon: Badge(
              isLabelVisible: viewModel.selectedGenreIds.isNotEmpty,
              label: Text('${viewModel.selectedGenreIds.length}'),
              child: const Icon(Icons.filter_list),
            ),
            color: AppColors.violet,
            tooltip: '장르 필터',
          ),
        ],
      ),
      body: Column(
        children: [
          if (viewModel.genres.isNotEmpty)
            GenreChipBar(
              genres: viewModel.genres,
              selectedGenreIds: viewModel.selectedGenreIds,
              // 요청 중에 바꿔도 이전 장르 응답은 generation으로 버려짐
              enabled: true,
              onSelected: viewModel.selectGenres,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _MovieListBody(
              viewModel: viewModel,
              paged: paged,
              controller: _scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieListBody extends StatelessWidget {
  const _MovieListBody({
    required this.viewModel,
    required this.paged,
    required this.controller,
  });

  final MovieListViewModel viewModel;
  final PagedMoviesViewModel paged;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    switch (paged.phase) {
      // 첫 로딩: 화면 전체 skeleton
      case LoadPhase.idle || LoadPhase.loading:
        return const MovieListLoading();
      case LoadPhase.error:
        return _Scrollable(
          onRefresh: paged.refresh,
          child: MovieListError(
            message: paged.errorMessage ?? '영화 목록을 불러오지 못했습니다.',
            onRetry: paged.refresh,
          ),
        );
      case LoadPhase.empty:
        final filtered = viewModel.selectedGenreIds.isNotEmpty;
        return _Scrollable(
          onRefresh: paged.refresh,
          child: MovieListEmpty(
            message: filtered ? '선택한 장르의 영화가 없어요.' : '아직 등록된 영화가 없어요.',
            actionLabel: filtered ? '전체 보기' : null,
            onAction: () => viewModel.selectGenres(const []),
          ),
        );
      case LoadPhase.ready:
        return RefreshIndicator(
          // 당겨서 새로고침 = 같은 장르로 page 1부터 다시
          onRefresh: paged.refresh,
          color: AppColors.violet,
          child: MovieGrid(
            movies: viewModel.movies,
            genreNameOf: viewModel.genreNameOf,
            controller: controller,
            footer: MoviePageFooter(vm: paged),
          ),
        );
    }
  }
}

/// Empty, Error에서도 당겨서 새로고침 되게 스크롤로 감쌈
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child, required this.onRefresh});

  final Widget child;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.violet,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}

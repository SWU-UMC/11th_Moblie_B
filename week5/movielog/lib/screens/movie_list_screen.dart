import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movie_sort.dart';
import '../theme/app_colors.dart';
import '../view_models/load_status.dart';
import '../view_models/movie_list_view_model.dart';
import '../widgets/movie/genre_chip_bar.dart';
import '../widgets/movie/genre_filter_sheet.dart';
import '../widgets/movie_list/movie_grid.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/movie_list/movie_list_loading.dart';
import '../widgets/movie_list/retry_dialog.dart';

/// W3-02 영화 목록 (5주차: TMDB Discover 최대 30개 + Genre API 장르 Chip)
///
/// 화면은 ViewModel의 상태를 보여주고, 사용자 입력을 ViewModel에 전달하기만 합니다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final MovieListViewModel _viewModel;
  bool _isRetryDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // 실패 시 재시도 Dialog는 화면을 다시 그리는 것과 별개로 한 번만 띄웁니다.
    _viewModel = context.read<MovieListViewModel>()
      ..addListener(_showRetryDialogIfNeeded);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_showRetryDialogIfNeeded);
    super.dispose();
  }

  Future<void> _showRetryDialogIfNeeded() async {
    if (!_viewModel.retryDialogRequested || _isRetryDialogOpen) return;
    _isRetryDialogOpen = true;
    final retry = await RetryDialog.show(context);
    _isRetryDialogOpen = false;
    if (!mounted) return;
    retry ? await _viewModel.retry() : _viewModel.cancelRetry();
  }

  Future<void> _openFilterSheet(MovieListViewModel viewModel) async {
    final result = await GenreFilterSheet.show(
      context,
      genres: viewModel.genres,
      selected: viewModel.selectedGenreIds,
    );
    // 확인 없이 닫으면 null → 장르를 바꾸지 않습니다.
    if (result == null || !mounted) return;
    await viewModel.selectGenres(result);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final viewModel = context.watch<MovieListViewModel>();
    final canChangeGenres = viewModel.canChangeGenres;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: textTheme.titleLarge?.copyWith(color: AppColors.violet),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
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
            // 영화를 불러오는 중에는 장르를 바꿀 수 없습니다.
            onPressed: canChangeGenres && viewModel.genres.isNotEmpty
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
              enabled: canChangeGenres,
              onSelected: viewModel.selectGenres,
            ),
          const SizedBox(height: 8),
          Expanded(child: _MovieListBody(viewModel: viewModel)),
        ],
      ),
    );
  }
}

class _MovieListBody extends StatelessWidget {
  const _MovieListBody({required this.viewModel});

  final MovieListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final content = switch (viewModel.status) {
      // Loading 중에는 RefreshIndicator로 감싸지 않아 당겨서 새로고침이 동작하지 않습니다.
      LoadStatus.idle || LoadStatus.loading => const MovieListLoading(),
      LoadStatus.error => _Scrollable(
        child: MovieListError(
          message: viewModel.message ?? '영화를 불러오지 못했어요.',
          onRetry: viewModel.retry,
        ),
      ),
      LoadStatus.empty => _Scrollable(
        child: MovieListEmpty(
          message: viewModel.selectedGenreIds.isEmpty
              ? '아직 등록된 영화가 없어요.'
              : '선택한 장르의 영화가 없어요.',
          actionLabel: viewModel.selectedGenreIds.isEmpty ? null : '전체 보기',
          onAction: () => viewModel.selectGenres(const []),
        ),
      ),
      LoadStatus.success => MovieGrid(
        movies: viewModel.movies,
        genreNameOf: viewModel.genreNameOf,
      ),
    };

    if (viewModel.status == LoadStatus.idle ||
        viewModel.status == LoadStatus.loading) {
      return content;
    }
    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      color: AppColors.violet,
      child: content,
    );
  }
}

/// Empty·Error 화면에서도 당겨서 새로고침이 되도록 스크롤 가능하게 감쌉니다.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../data/movie_preferences.dart';
import '../models/movie.dart';
import '../models/movie_sort.dart';
import '../router/app_routes.dart';
import '../services/fake_movie_service.dart';
import '../theme/app_colors.dart';
import '../widgets/movie/genre_chip_bar.dart';
import '../widgets/movie/genre_filter_sheet.dart';
import '../widgets/movie_list/movie_grid.dart';
import '../widgets/movie_list/movie_list_empty.dart';
import '../widgets/movie_list/movie_list_error.dart';
import '../widgets/movie_list/movie_list_loading.dart';

/// W3-02 영화 목록 (4주차: 비동기 로드 + 마지막 선택 장르 저장)
///
/// 선택한 장르는 URL Query Parameter(?genre=)에 있고, 마지막 선택은 로컬에도 저장합니다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.selectedGenres = const {},
    this.movieService = const FakeMovieService(),
    this.preferences,
    this.timeout = const Duration(seconds: 5),
  });

  final Set<String> selectedGenres;
  final FakeMovieService movieService;

  /// null이면 기기 로컬 저장소(SharedPreferencesAsync)를 사용합니다.
  final MoviePreferences? preferences;

  /// 이 시간 안에 응답이 없으면 Timeout 오류 화면을 보여줍니다.
  final Duration timeout;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final MoviePreferences _preferences =
      widget.preferences ?? MoviePreferences();

  /// build가 아니라 initState·재시도·새로고침에서만 새 Future를 만듭니다.
  late Future<List<Movie>> _moviesFuture;

  MovieSort _sort = MovieSort.rating;

  /// 개발용 Mock 응답 종류 (디버그 메뉴에서 변경)
  MovieLoadMode _mode = MovieLoadMode.success;

  /// 당겨서 새로고침 중에는 Skeleton 대신 기존 목록을 유지합니다.
  bool _isRefreshing = false;

  /// 저장값 복원이 끝나기 전에 사용자가 장르를 바꿨는지
  bool _filterChangedByUser = false;

  @override
  void initState() {
    super.initState();
    _moviesFuture = _fetchMovies();
    _restoreSavedSettings();
  }

  Future<List<Movie>> _fetchMovies() {
    // TODO(5주차 유저별 평점 조회 API): FakeMovieService를 실제 API Service로 교체
    return widget.movieService.fetchMovies(mode: _mode).timeout(widget.timeout);
  }

  Future<void> _restoreSavedSettings() async {
    // 장르와 정렬은 서로 의존하지 않으므로 함께 읽습니다.
    final (savedGenres, savedSort) = await (
      _preferences.readGenres(),
      _preferences.readSort(),
    ).wait;

    // await하는 동안 화면이 사라졌을 수 있으므로 확인한 뒤 setState·context를 사용합니다.
    if (!mounted) return;
    setState(() => _sort = savedSort);

    final shouldRestoreGenres =
        widget.selectedGenres.isEmpty &&
        savedGenres.isNotEmpty &&
        !_filterChangedByUser;
    if (shouldRestoreGenres) {
      context.go(AppRoutes.moviesWithGenres(savedGenres));
    }
  }

  void _retry() {
    setState(() {
      // Mock 실패·지연은 일시적인 오류를 흉내 내므로 다시 시도하면 정상 응답을 받습니다.
      if (_mode == MovieLoadMode.failure || _mode == MovieLoadMode.slow) {
        _mode = MovieLoadMode.success;
      }
      _moviesFuture = _fetchMovies();
    });
  }

  Future<void> _refresh() async {
    final future = _fetchMovies();
    setState(() {
      _isRefreshing = true;
      _moviesFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // 오류는 FutureBuilder가 Error 화면으로 보여줍니다.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _changeMockMode(MovieLoadMode mode) {
    setState(() {
      _mode = mode;
      _moviesFuture = _fetchMovies();
    });
  }

  Future<void> _applyGenres(Set<String> genres) async {
    _filterChangedByUser = true;
    context.go(AppRoutes.moviesWithGenres(genres));
    await _preferences.saveGenres(genres);
  }

  Future<void> _changeSort(MovieSort sort) async {
    setState(() => _sort = sort);
    await _preferences.saveSort(sort);
  }

  Future<void> _openFilterSheet() async {
    final result = await GenreFilterSheet.show(
      context,
      genres: allGenres,
      selected: widget.selectedGenres,
    );
    // 확인 없이 닫으면 null → 필터를 바꾸지 않습니다.
    if (result == null || !mounted) return;
    await _applyGenres(result);
  }

  String _errorMessage(Object? error) {
    // 내부 Exception·StackTrace는 화면에 그대로 보여주지 않습니다.
    debugPrint('영화 목록 로드 실패: $error');
    return switch (error) {
      TimeoutException() => '응답이 늦어지고 있어요.\n잠시 후 다시 시도해주세요.',
      _ => '영화를 불러오지 못했습니다.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedGenres = widget.selectedGenres;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '영화',
          style: textTheme.titleLarge?.copyWith(color: AppColors.violet),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              tooltip: 'Mock 응답 선택',
              icon: const Icon(Icons.science_outlined, color: AppColors.hint),
              onSelected: _changeMockMode,
              itemBuilder: (context) => [
                for (final mode in MovieLoadMode.values)
                  CheckedPopupMenuItem(
                    value: mode,
                    checked: mode == _mode,
                    child: Text(mode.label),
                  ),
              ],
            ),
          PopupMenuButton<MovieSort>(
            tooltip: '정렬',
            icon: const Icon(Icons.sort, color: AppColors.violet),
            onSelected: _changeSort,
            itemBuilder: (context) => [
              for (final sort in MovieSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == _sort,
                  child: Text(sort.label),
                ),
            ],
          ),
          IconButton(
            onPressed: _openFilterSheet,
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
            onSelected: _applyGenres,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.violet,
              child: FutureBuilder<List<Movie>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  final isWaiting =
                      snapshot.connectionState == ConnectionState.waiting;
                  if (isWaiting && !(_isRefreshing && snapshot.hasData)) {
                    return const MovieListLoading();
                  }

                  // 오류를 먼저 확인한 뒤 빈 목록 여부를 확인합니다.
                  if (snapshot.hasError) {
                    return _Scrollable(
                      child: MovieListError(
                        message: _errorMessage(snapshot.error),
                        onRetry: _retry,
                      ),
                    );
                  }

                  final loaded = snapshot.data ?? const <Movie>[];
                  if (loaded.isEmpty) {
                    return const _Scrollable(
                      child: MovieListEmpty(message: '아직 등록된 영화가 없어요.'),
                    );
                  }

                  final visible = _sort.apply(
                    filterMoviesInList(loaded, selectedGenres),
                  );
                  if (visible.isEmpty) {
                    return _Scrollable(
                      child: MovieListEmpty(
                        message: '선택한 장르의 영화가 없어요.',
                        actionLabel: '전체 보기',
                        onAction: () => _applyGenres({}),
                      ),
                    );
                  }

                  return MovieGrid(movies: visible);
                },
              ),
            ),
          ),
        ],
      ),
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

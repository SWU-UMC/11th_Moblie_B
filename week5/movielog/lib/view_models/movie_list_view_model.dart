import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/movie_preferences.dart';
import '../data/services/tmdb_movie_service.dart';
import '../models/movie_sort.dart';
import 'load_status.dart';

/// 영화 목록 화면: Genre API로 Chip을 만들고, Discover API로 최대 30개를 모읍니다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {MoviePreferences? preferences})
    : _preferences = preferences ?? MoviePreferences();

  static const maxMovies = 30;

  final TmdbMovieService _service;
  final MoviePreferences _preferences;

  List<TmdbGenreDto> genres = const [];

  /// 선택한 TMDB 장르 id. 비어 있으면 "전체"(with_genres 없이 요청)
  List<int> selectedGenreIds = const [];

  LoadStatus status = LoadStatus.idle;
  String? message;
  MovieSort sort = MovieSort.popularity;

  /// 당겨서 새로고침 중이면 true (기존 목록은 그대로 보여줌)
  bool isRefreshing = false;

  /// 이전 목록이 있는 상태에서 요청이 실패하면 true → 화면이 재시도 Dialog를 띄웁니다.
  bool retryDialogRequested = false;

  List<TmdbMovieDto> _movies = const [];

  /// 마지막으로 성공한 목록과 그때의 장르 (실패 시 목록 유지, 취소 시 장르 되돌리기)
  List<TmdbMovieDto> _lastSuccessMovies = const [];
  List<int> _lastSuccessGenreIds = const [];

  /// 늦게 도착한 이전 요청의 응답을 무시하기 위한 요청 번호
  int _requestVersion = 0;
  bool _disposed = false;

  /// 화면에 보여줄 목록 (선택한 정렬 적용)
  List<TmdbMovieDto> get movies => sort.apply(_movies);

  /// 요청 중에는 장르를 바꿀 수 없습니다.
  bool get canChangeGenres => status != LoadStatus.loading && !isRefreshing;

  /// 장르 id → 이름 (카드의 "2024 · 드라마" 표시용)
  String? genreNameOf(TmdbMovieDto movie) {
    for (final id in movie.genreIds) {
      for (final genre in genres) {
        if (genre.id == id) return genre.name;
      }
    }
    return null;
  }

  /// Discover를 page 1부터 불러 TMDB id 기준으로 중복을 없애며 최대 30개를 모읍니다.
  /// 결과가 30개보다 적으면 있는 만큼만 돌려줍니다.
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({
    List<int>? genreIds,
  }) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(maxMovies).toList();
  }

  /// 화면 진입 시 한 번: 저장된 장르·정렬 복원 → Genre API → Discover
  Future<void> loadInitial() async {
    final version = ++_requestVersion;
    status = LoadStatus.loading;
    message = null;
    notifyListeners();

    final (savedGenreIds, savedSort) = await (
      _preferences.readGenreIds(),
      _preferences.readSort(),
    ).wait;
    if (_isStale(version)) return;
    selectedGenreIds = savedGenreIds;
    sort = savedSort;

    try {
      if (genres.isEmpty) genres = await _service.fetchGenres();
      final discovered = await fetchUpToThirtyMovies(
        genreIds: selectedGenreIds,
      );
      if (_isStale(version)) return;
      _applySuccess(discovered);
    } on DioException catch (error) {
      if (_isStale(version)) return;
      _applyFailure(error, '영화를 불러오지 못했어요. 다시 시도해 주세요.');
    }

    if (!_isStale(version)) notifyListeners();
  }

  /// 장르 Chip(하나) 또는 BottomSheet(여러 개) 선택 → with_genres로 page 1부터 다시 요청
  Future<void> selectGenres(List<int> genreIds) async {
    if (!canChangeGenres) return;
    selectedGenreIds = List.unmodifiable(genreIds);
    await _preferences.saveGenreIds(selectedGenreIds);
    await _reload(clearList: true);
  }

  /// Error 화면·재시도 Dialog: 마지막으로 선택한 장르로 page 1부터 다시
  Future<void> retry() {
    retryDialogRequested = false;
    return _reload(clearList: true);
  }

  /// 재시도 Dialog에서 취소: 마지막으로 성공한 목록과 그때의 장르로 되돌립니다.
  void cancelRetry() {
    retryDialogRequested = false;
    selectedGenreIds = _lastSuccessGenreIds;
    _movies = _lastSuccessMovies;
    status = _movies.isEmpty ? LoadStatus.empty : LoadStatus.success;
    notifyListeners();
  }

  /// 당겨서 새로고침: 같은 장르로 page 1부터 다시, 그동안 기존 목록은 유지
  Future<void> refresh() async {
    if (status == LoadStatus.loading || isRefreshing) return;
    isRefreshing = true;
    notifyListeners();
    await _reload(clearList: false);
  }

  Future<void> changeSort(MovieSort newSort) async {
    sort = newSort;
    notifyListeners();
    await _preferences.saveSort(newSort);
  }

  Future<void> _reload({required bool clearList}) async {
    final version = ++_requestVersion;
    if (clearList) status = LoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final discovered = await fetchUpToThirtyMovies(
        genreIds: selectedGenreIds,
      );
      if (_isStale(version)) return;
      _applySuccess(discovered);
    } on DioException catch (error) {
      if (_isStale(version)) return;
      _applyFailure(error, '해당 장르 영화를 불러오지 못했어요.');
    }

    if (_isStale(version)) return;
    isRefreshing = false;
    notifyListeners();
  }

  void _applySuccess(List<TmdbMovieDto> discovered) {
    _movies = discovered;
    _lastSuccessMovies = discovered;
    _lastSuccessGenreIds = selectedGenreIds;
    status = discovered.isEmpty ? LoadStatus.empty : LoadStatus.success;
  }

  void _applyFailure(DioException error, String errorMessage) {
    debugPrint('영화 목록 로드 실패: ${error.type.name} ${error.response?.statusCode}');
    if (_lastSuccessMovies.isNotEmpty) {
      // 최근 성공한 목록은 지우지 않고 유지한 채 재시도 Dialog로 안내합니다.
      _movies = _lastSuccessMovies;
      status = LoadStatus.success;
      retryDialogRequested = true;
    } else {
      status = LoadStatus.error;
      message = errorMessage;
    }
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

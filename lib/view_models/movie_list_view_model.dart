import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../services/genre_preferences.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면의 장르 목록, 선택 장르, Discover 최대 30개 상태를 관리합니다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {GenrePreferences? genrePreferences})
    : _genrePreferences = genrePreferences ?? GenrePreferences();

  static const maxMovies = 30;

  final TmdbMovieService _service;
  final GenrePreferences _genrePreferences;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId;
  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;

  int _requestVersion = 0;
  bool _disposed = false;

  bool get isLoading =>
      status == MovieListLoadStatus.idle ||
      status == MovieListLoadStatus.loading;

  /// 선택한 장르의 이름입니다. "전체"이거나 목록에 없으면 null입니다.
  String? get selectedGenreName {
    for (final genre in genres) {
      if (genre.id == selectedGenreId) return genre.name;
    }
    return null;
  }

  /// 페이지 크기를 가정하지 않고, 30개가 되거나 마지막 페이지에 닿을 때까지 요청합니다.
  /// TMDB id를 Map key로 써서 페이지 사이에 겹친 영화는 하나만 남깁니다.
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({int? genreId}) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
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

  /// 장르 목록과 첫 목록을 불러옵니다. 저장된 장르가 있으면 그 장르로 시작합니다.
  /// 재시도도 이 메서드를 쓰며, 이때는 현재 선택한 장르를 유지합니다.
  Future<void> loadInitial() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    notifyListeners();

    try {
      if (genres.isEmpty) {
        genres = await _service.fetchGenres();
        await _restoreLastGenre();
        // Discover를 기다리는 동안에도 장르 Chip은 (비활성 상태로) 보이게 합니다.
        if (_disposed || version != _requestVersion) return;
        notifyListeners();
      }
      final discovered = await fetchUpToThirtyMovies(genreId: selectedGenreId);

      if (_disposed || version != _requestVersion) return;
      movies = discovered;
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } on DioException {
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '영화를 불러오지 못했어요. 다시 시도해 주세요.';
    }

    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  Future<void> _restoreLastGenre() async {
    final int? saved;
    try {
      saved = await _genrePreferences.loadLastGenreId();
    } catch (error) {
      // 읽기에 실패하면 "전체"로 시작합니다.
      debugPrint('마지막 장르 불러오기 실패: $error');
      return;
    }
    // TMDB 장르 목록에 없는 값은 무시합니다.
    if (genres.any((genre) => genre.id == saved)) selectedGenreId = saved;
  }

  /// 장르를 바꾸고 Discover를 page 1부터 다시 요청합니다. null은 "전체"입니다.
  Future<void> selectGenre(int? genreId) async {
    // 요청 중에는 장르를 바꾸지 않습니다. (화면의 Chip도 비활성화됩니다.)
    if (isLoading) return;

    selectedGenreId = genreId;
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    notifyListeners();

    // 저장은 기다리지 않고, 실패해도 선택한 장르로 계속 진행합니다.
    _genrePreferences.saveLastGenreId(genreId).catchError((Object error) {
      debugPrint('마지막 장르 저장 실패: $error');
    });

    try {
      final result = await fetchUpToThirtyMovies(genreId: genreId);
      if (_disposed || version != _requestVersion) return;
      movies = result;
      status = result.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } on DioException {
      if (_disposed || version != _requestVersion) return;
      status = MovieListLoadStatus.error;
      message = '해당 장르 영화를 불러오지 못했어요.';
    }

    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

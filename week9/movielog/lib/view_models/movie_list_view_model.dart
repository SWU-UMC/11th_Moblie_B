import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/movie_preferences.dart';
import '../data/services/tmdb_movie_service.dart';
import '../models/movie_sort.dart';
import 'paged_movies_view_model.dart';

/// 영화 목록 화면의 필터 상태 (장르 Chip·BottomSheet 다중 선택, 정렬)
/// 9주차: 영화 불러오기는 PagedMoviesViewModel이 page 단위로 함
/// → 여기선 장르 바뀌면 paged.loadInitial만 부름 (5주차 30개 수집 방식 제거)
class MovieListViewModel extends ChangeNotifier with SafeNotify {
  MovieListViewModel(this._service, this.paged, {MoviePreferences? preferences})
    : _preferences = preferences ?? MoviePreferences();

  final TmdbMovieService _service;
  final MoviePreferences _preferences;

  /// 같은 Route에서 만든 목록 page 상태
  final PagedMoviesViewModel paged;

  List<TmdbGenreDto> genres = const [];

  /// 선택한 장르 id, 비어있으면 전체
  List<int> selectedGenreIds = const [];

  MovieSort sort = MovieSort.popularity;

  /// 불러온 page 안에서만 정렬 (인기순은 서버 순서 그대로)
  List<TmdbMovieDto> get movies => sort.apply(paged.movies);

  /// 장르 id → 이름
  String? genreNameOf(TmdbMovieDto movie) {
    for (final id in movie.genreIds) {
      for (final genre in genres) {
        if (genre.id == id) return genre.name;
      }
    }
    return null;
  }

  /// 처음 진입: 저장된 장르/정렬 복원 → 장르 목록 → 첫 page
  Future<void> loadInitial() async {
    final (savedGenreIds, savedSort) = await (
      _preferences.readGenreIds(),
      _preferences.readSort(),
    ).wait;
    if (isDisposed) return;
    selectedGenreIds = savedGenreIds;
    sort = savedSort;
    notifyIfAlive();

    // 장르 이름 실패해도 영화 목록은 보여줌 (Chip만 숨김)
    await (_loadGenres(), paged.loadInitial(genreIds: selectedGenreIds)).wait;
  }

  Future<void> _loadGenres() async {
    if (genres.isNotEmpty) return;
    try {
      final loaded = await _service.fetchGenres();
      if (isDisposed) return;
      genres = loaded;
      notifyIfAlive();
    } on DioException catch (error) {
      debugPrint('장르 목록 실패: ${error.response?.statusCode}');
    }
  }

  /// 장르 선택(Chip/BottomSheet) → 이전 목록 비우고 page 1부터
  /// 요청 중에 바꿔도 PagedMoviesViewModel generation이 이전 응답 버림
  Future<void> selectGenres(List<int> genreIds) async {
    selectedGenreIds = List.unmodifiable(genreIds);
    notifyIfAlive();
    await (
      paged.loadInitial(genreIds: selectedGenreIds),
      _preferences.saveGenreIds(selectedGenreIds),
    ).wait;
  }

  Future<void> changeSort(MovieSort newSort) async {
    sort = newSort;
    notifyIfAlive();
    await _preferences.saveSort(newSort);
  }
}

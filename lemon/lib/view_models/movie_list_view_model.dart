import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../services/genre_preferences.dart';

/// 영화 목록 화면의 장르 목록과 선택 장르(마지막 선택 저장·복원)를 관리합니다.
///
/// 9주차부터 영화 자체는 [PagedMoviesViewModel]이 "더 보기"로 한 page씩 불러옵니다.
/// (5주차의 Discover 최대 30개 수집 방식은 더 이상 쓰지 않습니다.)
class MovieListViewModel extends ChangeNotifier with SafeNotify {
  MovieListViewModel(this._service, {GenrePreferences? genrePreferences})
    : _genrePreferences = genrePreferences ?? GenrePreferences();

  final TmdbMovieService _service;
  final GenrePreferences _genrePreferences;

  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId;
  bool genresLoaded = false;

  /// 선택한 장르의 이름입니다. "전체"이거나 목록에 없으면 null입니다.
  String? get selectedGenreName {
    for (final genre in genres) {
      if (genre.id == selectedGenreId) return genre.name;
    }
    return null;
  }

  /// 장르 목록을 불러오고 저장된 장르를 복원합니다. 실패해도 "전체"로 목록을 보여줍니다.
  Future<void> loadGenres() async {
    if (genresLoaded || isDisposed) return;
    try {
      final loaded = await _service.fetchGenres();
      if (isDisposed) return;
      genres = loaded;
      genresLoaded = true;
      await _restoreLastGenre();
    } catch (error) {
      debugPrint('장르 목록 요청 실패: ${error.runtimeType}');
    }
    notifyIfAlive();
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

  /// 장르를 바꾸고 저장합니다. null은 "전체"입니다. 저장 실패는 선택에 영향을 주지 않습니다.
  void selectGenre(int? genreId) {
    selectedGenreId = genreId;
    notifyIfAlive();
    _genrePreferences.saveLastGenreId(genreId).catchError((Object error) {
      debugPrint('마지막 장르 저장 실패: $error');
    });
  }
}

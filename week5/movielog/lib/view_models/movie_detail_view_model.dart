import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_status.dart';

/// 영화 상세: 목록에서 넘겨받은 영화가 있으면 바로 보여주고,
/// URL(id)로만 들어왔으면 TMDB에서 id로 다시 불러옵니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._service, {required this.movieId, this.movie})
    : status = movie == null ? LoadStatus.idle : LoadStatus.success;

  final TmdbMovieService _service;

  /// TMDB 영화 id (Path Parameter). 평점 Dialog에도 이 값을 그대로 넘깁니다.
  final int? movieId;

  TmdbMovieDto? movie;
  List<TmdbGenreDto> genres = const [];
  LoadStatus status;

  // 즐겨찾기와 내 평점은 아직 서버 없이 화면 내부 상태로만 관리합니다.
  bool isFavorite = false;
  double? myRating;

  bool _disposed = false;

  List<String> get genreNames {
    final current = movie;
    if (current == null) return const [];
    return [
      for (final id in current.genreIds)
        for (final genre in genres)
          if (genre.id == id) genre.name,
    ];
  }

  Future<void> load() async {
    final id = movieId;
    if (id == null) {
      status = LoadStatus.empty;
      notifyListeners();
      return;
    }

    if (movie == null) {
      status = LoadStatus.loading;
      notifyListeners();
    }

    if (movie == null) {
      try {
        movie = await _service.fetchMovieDetail(id);
        if (_disposed) return;
        status = LoadStatus.success;
      } on DioException catch (error) {
        if (_disposed) return;
        debugPrint('영화 상세 로드 실패: ${error.response?.statusCode}');
        // 없는 id(404)는 Empty, 그 밖의 실패는 Error
        status = error.response?.statusCode == 404
            ? LoadStatus.empty
            : LoadStatus.error;
        notifyListeners();
        return;
      }
      notifyListeners();
    }

    try {
      genres = await _service.fetchGenres();
    } on DioException {
      // 장르 이름을 못 불러와도 영화 정보는 그대로 보여줍니다.
      genres = const [];
    }
    if (!_disposed) notifyListeners();
  }

  /// 오류 화면의 다시 시도
  Future<void> retry() => load();

  void toggleFavorite() {
    isFavorite = !isFavorite;
    notifyListeners();
  }

  void saveMyRating(double rating) {
    // TODO(6주차 평점 API): movieId와 함께 MovieLog 자체 API로 평점을 저장합니다.
    myRating = rating;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

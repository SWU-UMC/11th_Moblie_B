import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);
  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;
  Future<void> load() async {
    if (_disposed) return;
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();
    try {
      final raw = await _service.fetchMyRatings(memberId);
      if (_disposed || version != _requestVersion) return;
      final entries = <RatingWithMovie>[];
      // 한 로딩 안에서는 실패한 ID도 중복 조회하지 않습니다.
      final attempted = <int>{};
      var missing = 0;
      for (final rating in raw) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId) &&
            attempted.add(rating.movieId)) {
          try {
            final movie = await _movieService.findMovieById(rating.movieId);
            if (_disposed || version != _requestVersion) return;
            _movieCache[rating.movieId] = movie;
          } on DioException {
            /* 일시 오류는 다음 load에서 재시도합니다. */
          }
        }
        if (_disposed || version != _requestVersion) return;
        final movie = _movieCache[rating.movieId];
        if (movie == null) missing++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missing > 0) message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
    } on DioException catch (error) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
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

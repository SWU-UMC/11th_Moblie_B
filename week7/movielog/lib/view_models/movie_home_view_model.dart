import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_status.dart';

/// 홈: Popular 1페이지에서 5개
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  LoadStatus status = LoadStatus.idle;
  String? message;

  bool _disposed = false;

  /// 추천 카드에 쓰는 1위
  TmdbMovieDto? get featuredMovie =>
      popularMovies.isEmpty ? null : popularMovies.first;

  Future<void> loadPopular() async {
    status = LoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      // 5개보다 적게 와도 안 터지게 take 사용
      popularMovies = page.results.take(popularCount).toList();
      status = popularMovies.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } on DioException {
      status = LoadStatus.error;
      message = '인기 영화를 불러오지 못했어요.';
    }

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

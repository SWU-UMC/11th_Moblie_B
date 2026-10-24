import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_status.dart';

/// 홈 화면: Popular 첫 페이지에서 인기 영화 5개를 보여줍니다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularCount = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  LoadStatus status = LoadStatus.idle;
  String? message;

  bool _disposed = false;

  /// 홈 상단 추천 카드에 쓰는 1위 영화
  TmdbMovieDto? get featuredMovie =>
      popularMovies.isEmpty ? null : popularMovies.first;

  Future<void> loadPopular() async {
    status = LoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final page = await _service.fetchPopular();
      // 결과가 5개보다 적어도 안전하도록 index 대신 take를 씁니다.
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

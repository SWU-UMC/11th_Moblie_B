import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_status.dart';
import 'submit_status.dart';

/// 영화 상세: extra로 받은 영화 있으면 바로 씀
/// 없으면 id로 TMDB에서 불러옴
/// 7주차: 평점 등록만 여기서 함 (조회·수정·삭제는 마이페이지)
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service,
    this._ratingService, {
    required this.movieId,
    required this.memberId,
    this.movie,
  }) : status = movie == null ? LoadStatus.idle : LoadStatus.success;

  final TmdbMovieService _service;
  final RatingApiService _ratingService;

  /// TMDB 영화 id (path param)
  final int? movieId;

  /// 학습용 현재 회원 (로그인 인증 아님)
  final int? memberId;

  TmdbMovieDto? movie;
  List<TmdbGenreDto> genres = const [];
  LoadStatus status;

  // 즐겨찾기는 아직 서버 연결 안 함 (화면 상태로만 관리)
  bool isFavorite = false;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이번 화면에서 등록 성공한 별점 (화면 표시용)
  int? myScore;

  bool _disposed = false;

  /// 가입 안 했으면 평점 등록 버튼 비활성화
  bool get canRate => memberId != null;

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
        // 404면 Empty, 나머지는 Error
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
      // 장르 이름 실패해도 영화 정보는 보여줌
      genres = const [];
    }
    if (!_disposed) notifyListeners();
  }

  /// 다시 시도
  Future<void> retry() => load();

  void toggleFavorite() {
    isFavorite = !isFavorite;
    notifyListeners();
  }

  /// 평점 등록 POST
  /// movieId는 TMDB id 그대로 보냄 (목록 index 아님)
  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    final current = movie;
    if (id == null || current == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: current.id,
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return; // 화면 나갔으면 결과 반영 안 함
      submitStatus = SubmitStatus.success;
      myScore = score;
    } on DioException catch (error) {
      if (_disposed) return;
      debugPrint('평점 등록 실패: ${error.response?.statusCode}');
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

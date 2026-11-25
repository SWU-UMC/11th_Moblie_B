import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_status.dart';
import 'session_ratings.dart';
import 'submit_status.dart';

/// 내가 등록한 평점 (이번 로그인 세션 기준)
/// 8주차: 토큰 기반 내 평점 GET이 없어서 등록 result로 받은 Rating을 수정·삭제
/// movieId(TMDB id)로 영화 제목·포스터 붙임, 없으면 "영화 #id"
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService, {
    required this._auth,
    required this._sessionRatings,
  });

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;

  /// movieId별 캐시 (TMDB 404는 null로 저장)
  final Map<int, TmdbMovieDto?> _movieCache = {};

  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  LoadStatus status = LoadStatus.idle;
  String? message;

  /// Challenge(7주차): 다중 선택 모드
  bool isEditing = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  /// 세션 평점 + TMDB 영화 정보 묶기
  /// 영화 정보 실패해도 평점은 placeholder로 보여줌
  Future<void> load() async {
    final version = ++_requestVersion;
    final source = _sessionRatings.ratings;
    final missing = {
      for (final rating in source)
        if (!_movieCache.containsKey(rating.movieId)) rating.movieId,
    };
    if (missing.isNotEmpty && ratings.isEmpty) {
      status = LoadStatus.loading;
      message = null;
      _notify();
    }

    for (final movieId in missing) {
      try {
        _movieCache[movieId] = await _movieService.findMovieById(movieId);
      } on DioException {
        // 일시적 실패는 캐시 안 함 (다음에 다시 시도)
      }
      if (_isStale(version)) return;
    }
    if (_isStale(version)) return;
    _applyEntries();
    _notify();
  }

  void _applyEntries() {
    final source = _sessionRatings.ratings;
    ratings = [
      for (final rating in source)
        RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
    ];
    selectedRatingIds.retainAll(ratings.map((e) => e.rating.ratingId));
    status = ratings.isEmpty ? LoadStatus.empty : LoadStatus.success;
    if (ratings.isEmpty) isEditing = false;
    final missingMovies = ratings.where((e) => e.movie == null).length;
    message = missingMovies > 0 ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.' : null;
  }

  /// 쓰기 실패 처리
  /// 401(AUTH401_2/3/4) → 세션 정리 / 404 → 목록에서 뺌 / 나머지 → Dialog에 문구
  Future<Never> _onWriteError(
    DioException error, {
    required int version,
    required int ratingId,
  }) async {
    debugPrint(
      '평점 쓰기 실패: ${error.response?.statusCode} ${apiErrorCode(error)}',
    );
    if (isSessionExpired(error)) {
      await _auth.expireSession(version: version);
      throw const SubmitFailure('로그인이 만료됐어요. 다시 로그인해 주세요.');
    }
    if (apiErrorCode(error) == 'RATING404_1' && _isSession(version)) {
      // 서버엔 이미 없음 → 화면도 맞춤
      _sessionRatings.remove(ratingId);
      _applyEntries();
      _notify();
    }
    throw SubmitFailure(writeErrorMessage(error));
  }

  /// 수정 PATCH → result Rating으로 교체
  /// comment는 null이어도 항상 같이 보냄 (안 보내면 기존 후기 null로 덮임)
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
      if (!_isSession(version)) return;
      _sessionRatings.replace(updated);
      _applyEntries();
      _notify();
    } on DioException catch (error) {
      await _onWriteError(error, version: version, ratingId: ratingId);
    }
  }

  /// 삭제 DELETE (v8도 200 + result null)
  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      if (!_isSession(version)) return;
      _sessionRatings.remove(ratingId);
      _applyEntries();
      _notify();
    } on DioException catch (error) {
      await _onWriteError(error, version: version, ratingId: ratingId);
    }
  }

  // ---- Challenge(7주차): 다중 선택 삭제 ----

  void startEditing() {
    isEditing = true;
    selectedRatingIds.clear();
    _notify();
  }

  void cancelEditing() {
    isEditing = false;
    selectedRatingIds.clear();
    _notify();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    _notify();
  }

  /// 선택한 평점 하나씩 삭제
  /// 실패한 건 선택 그대로 남겨서 다시 시도 가능하게 함
  /// 반환값: 실패 개수
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    _notify();

    var failed = 0;
    try {
      // 원본 Set 돌면서 remove하면 ConcurrentModificationError → 복사해서 돔
      for (final ratingId in selectedRatingIds.toList()) {
        if (!_isSession(version)) return failed;
        try {
          await _service.deleteRating(ratingId);
          _sessionRatings.remove(ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException catch (error) {
          if (isSessionExpired(error)) {
            await _auth.expireSession(version: version);
            return failed + selectedRatingIds.length;
          }
          if (apiErrorCode(error) == 'RATING404_1') {
            // 이미 없음 → 지운 걸로 봄
            _sessionRatings.remove(ratingId);
            selectedRatingIds.remove(ratingId);
            continue;
          }
          failed++;
          debugPrint('다중 삭제 실패: $ratingId ${apiErrorCode(error)}');
        }
      }
    } finally {
      // 예상 못 한 오류에도 로딩은 꼭 풀기
      isDeletingSelected = false;
      if (!_disposed) {
        _applyEntries();
        notifyListeners();
      }
    }
    if (failed == 0 && !_disposed) {
      isEditing = false;
      _notify();
    }
    return failed;
  }

  bool _isSession(int version) => !_disposed && version == _auth.sessionVersion;

  bool _isStale(int version) => _disposed || version != _requestVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_status.dart';
import 'submit_status.dart';

/// 평점 목록 + movieId별 TMDB 영화 정보
/// 7주차: 회원가입으로 받은 memberId로 조회·수정·삭제
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  static const refreshFailedMessage =
      '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// movieId별 캐시 (404는 null로 저장)
  final Map<int, TmdbMovieDto?> _movieCache = {};

  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  LoadStatus status = LoadStatus.idle;
  String? message;

  /// 쓰기는 성공했는데 재조회(GET)만 실패한 경우 안내
  /// 쓰기 실패랑 다른 상태라 따로 둠
  String? refreshWarning;

  /// Challenge: 다중 선택 모드
  bool isEditing = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = LoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in rawRatings) {
        if (_isStale(version)) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException {
            // 일시적 실패는 캐시 안 함 (다음에 다시 시도)
            // 영화 정보 실패해도 평점 목록은 유지
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_isStale(version)) return;

      ratings = entries;
      // 목록에서 사라진 평점은 선택에서도 뺌
      selectedRatingIds.retainAll(entries.map((e) => e.rating.ratingId));
      // 빈 배열은 Empty
      status = entries.isEmpty ? LoadStatus.empty : LoadStatus.success;
      if (entries.isEmpty) isEditing = false;
      refreshWarning = null;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (error) {
      if (_isStale(version)) return;
      status = LoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }

    if (!_isStale(version)) notifyListeners();
  }

  /// 쓰기 성공 뒤 목록 다시 읽기
  /// GET 실패는 쓰기 실패로 안 던짐 (저장은 이미 끝남)
  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;
    if (status == LoadStatus.error) {
      refreshWarning = refreshFailedMessage;
      notifyListeners();
    }
  }

  /// 쓰기 실패 처리: 403·404면 목록 맞추고, Dialog엔 서버 문구로 실패 알림
  Future<Never> _onWriteError(DioException error) async {
    final text = writeErrorMessage(error);
    debugPrint('평점 쓰기 실패: ${error.response?.statusCode}');
    if (shouldRefreshAfterRatingError(error) && !_disposed) await load();
    throw SubmitFailure(text);
  }

  /// 수정 PATCH → 성공하면 다시 조회
  /// comment는 null이어도 항상 같이 보냄 (안 보내면 기존 후기 null로 덮임)
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        request: UpdateRatingRequest(score: score, comment: comment),
      );
    } on DioException catch (error) {
      await _onWriteError(error);
    }
    if (_disposed) return;
    await _refreshAfterWrite();
  }

  /// 삭제 DELETE(204) → 성공하면 다시 조회
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _onWriteError(error);
    }
    if (_disposed) return;
    await _refreshAfterWrite();
  }

  // ---- Challenge: 다중 선택 삭제 ----

  void startEditing() {
    isEditing = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void cancelEditing() {
    isEditing = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  /// 선택한 평점 하나씩 삭제
  /// 실패한 건 선택 그대로 남겨서 다시 시도 가능하게 함
  /// 반환값: 실패 개수
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    notifyListeners();

    var failed = 0;
    try {
      // 원본 Set 돌면서 remove하면 ConcurrentModificationError → 복사해서 돔
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException catch (error) {
          failed++;
          debugPrint('다중 삭제 실패: $ratingId ${error.response?.statusCode}');
        }
      }
    } finally {
      // 예상 못 한 오류에도 로딩은 꼭 풀기
      isDeletingSelected = false;
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return failed;

    if (failed == 0) isEditing = false;
    await _refreshAfterWrite();
    return failed;
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

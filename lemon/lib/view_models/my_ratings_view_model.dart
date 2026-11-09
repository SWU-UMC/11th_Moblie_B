import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면의 평점 목록과 TMDB 영화 정보를 함께 관리합니다.
/// 조회·수정·삭제는 이 화면에서만 합니다. (등록은 영화 상세 화면)
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;

  /// 회원가입으로 받은 학습용 회원입니다. 로그인 인증은 아닙니다.
  final int memberId;

  /// 같은 movieId는 한 번만 조회합니다. 없는 영화(404)는 null로 저장합니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// Error 상태에서는 오류 문구, Success 상태에서는 영화 정보 일부 누락 안내입니다.
  String? message;

  /// 저장(수정·삭제)은 성공했지만 그 뒤 목록 GET만 실패했을 때의 안내입니다.
  /// 저장 실패와 구분해, 저장을 다시 하지 않고 조회만 다시 시도하게 합니다.
  String? refreshWarning;

  /// 다중 삭제(Challenge)용 선택 상태입니다.
  bool isSelecting = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    // 화면을 벗어난 뒤에는 새 요청도, 이전 요청 결과 반영도 하지 않습니다.
    if (_disposed) return;
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_disposed || version != _requestVersion) return;

      // 캐시에 없는 영화만 동시에 조회합니다.
      final missingIds = {
        for (final rating in rawRatings)
          if (!_movieCache.containsKey(rating.movieId)) rating.movieId,
      };
      await Future.wait(missingIds.map(_loadMovie));
      if (_disposed || version != _requestVersion) return;

      final entries = [
        for (final rating in rawRatings)
          RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
      ];
      ratings = entries;
      refreshWarning = null;
      // 이미 사라진 평점은 선택에서도 뺍니다.
      selectedRatingIds.removeWhere(
        (id) => !entries.any((entry) => entry.rating.ratingId == id),
      );
      if (entries.isEmpty) isSelecting = false;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (entries.any((entry) => entry.movie == null)) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (error) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    } catch (error) {
      // 응답 형식이 달라 파싱에 실패해도 Loading에 머물지 않도록 Error로 바꿉니다.
      debugPrint('평점 조회 실패: $error');
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }

    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  /// 쓰기 성공 뒤 목록을 다시 읽습니다. GET 실패는 저장 실패로 다시 던지지 않습니다.
  Future<void> _refreshAfterWrite() async {
    if (_disposed) return;
    await load();
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 쓰기 실패를 Dialog가 보여줄 문구로 바꿔 던집니다.
  /// 403·404는 화면 목록이 서버와 어긋났다는 뜻이므로 다시 조회해 맞춥니다.
  Future<Never> _failWrite(DioException error) async {
    if (!_disposed && shouldRefreshAfterRatingError(error)) await load();
    throw RatingWriteFailure(writeErrorMessage(error));
  }

  /// 수정 API가 성공한 뒤에만 목록을 다시 읽습니다.
  /// comment가 null이면 서버의 기존 후기도 null로 바뀝니다. (전체 교체)
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      await _failWrite(error); // 쓰기 실패일 때만 Dialog가 실패로 처리합니다.
    }
    await _refreshAfterWrite();
  }

  /// 삭제 API(204)가 성공한 뒤에만 목록을 다시 읽습니다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _failWrite(error);
    }
    selectedRatingIds.remove(ratingId);
    await _refreshAfterWrite();
  }

  @override
  void notifyListeners() {
    // 쓰기 요청이 끝나기 전에 화면이 사라져도 dispose된 ViewModel을 건드리지 않습니다.
    if (!_disposed) super.notifyListeners();
  }

  void startSelection() {
    if (ratings.isEmpty || isDeletingSelected) return;
    isSelecting = true;
    notifyListeners();
  }

  void cancelSelection() {
    if (isDeletingSelected) return;
    isSelecting = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelection(int ratingId) {
    if (isDeletingSelected) return;
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  /// 선택한 평점을 하나씩 지웁니다. 실패한 항목은 선택 상태로 남기고, 실패 개수를 돌려줍니다.
  /// 확인 Dialog가 닫힌 뒤 시작하며, 진행 중에는 화면이 로딩 오버레이로 이탈을 막습니다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException catch (error) {
          debugPrint('평점 $ratingId 삭제 실패: ${error.response?.statusCode}');
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      // 예상하지 못한 오류에도 로딩을 해제합니다.
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return failed;
    if (selectedRatingIds.isEmpty) isSelecting = false;
    await _refreshAfterWrite(); // GET 실패는 삭제 성공 여부와 분리합니다.
    return failed;
  }

  /// 영화 조회가 실패해도 평점 목록은 지우지 않습니다.
  Future<void> _loadMovie(int movieId) async {
    try {
      _movieCache[movieId] = await _movieService.findMovieById(movieId);
    } catch (error) {
      // 일시적인 실패는 캐시하지 않고, 다음 로딩에서 다시 시도합니다.
      debugPrint('영화 $movieId 조회 실패: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

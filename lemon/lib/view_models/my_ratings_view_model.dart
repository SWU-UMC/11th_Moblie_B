import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'session_ratings_view_model.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

/// 선택 삭제 결과입니다. 실패한 항목은 서버 message를 함께 돌려줍니다.
class BulkDeleteResult {
  const BulkDeleteResult({
    this.deleted = 0,
    this.failed = 0,
    this.messages = const [],
    this.sessionExpired = false,
  });

  final int deleted;
  final int failed;
  final List<String> messages;

  /// 도중에 401(AUTH401_2/3/4)을 받아 남은 삭제를 멈췄습니다.
  final bool sessionExpired;
}

/// "내가 등록한 평점" 화면입니다.
///
/// v7에는 토큰 기반 내 평점 목록 GET이 없으므로, 이번 로그인 세션에서 등록한 평점
/// ([SessionRatingsViewModel])을 TMDB 영화 정보와 묶어 보여줍니다.
/// 수정·삭제 결과는 서버 응답으로 카드만 바꾸고 목록을 다시 GET하지 않습니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._ratings, this._movieService) {
    _ratings.addListener(_onRatingsChanged);
  }

  final SessionRatingsViewModel _ratings;
  final TmdbMovieService _movieService;

  /// 같은 movieId는 한 번만 조회합니다. 없는 영화(404)는 null로 저장합니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// 영화 정보 일부 누락 안내입니다.
  String? message;

  /// 다중 삭제(Challenge)용 선택 상태입니다.
  bool isSelecting = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  /// 평점과 영화 정보를 묶습니다. 캐시에 없는 영화만 TMDB에서 조회합니다.
  Future<void> load() async {
    if (_disposed) return;
    final version = ++_requestVersion;
    final missingIds = {
      for (final rating in _ratings.ratings)
        if (!_movieCache.containsKey(rating.movieId)) rating.movieId,
    };
    if (missingIds.isNotEmpty) {
      status = MyRatingsLoadStatus.loading;
      message = null;
      notifyListeners();
      await Future.wait(missingIds.map(_loadMovie));
      if (_disposed || version != _requestVersion) return;
    }
    _rebuild();
  }

  void _rebuild() {
    final entries = [
      for (final rating in _ratings.ratings)
        RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
    ];
    ratings = entries;
    // 이미 사라진 평점은 선택에서도 뺍니다.
    selectedRatingIds.removeWhere(
      (id) => !entries.any((entry) => entry.rating.ratingId == id),
    );
    if (entries.isEmpty) isSelecting = false;
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    message = entries.any((entry) => entry.movie == null)
        ? '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'
        : null;
    notifyListeners();
  }

  /// 등록·수정·삭제·로그아웃으로 세션 평점이 바뀌면 화면 목록을 맞춥니다.
  void _onRatingsChanged() {
    if (_disposed) return;
    final hasUnknownMovie = _ratings.ratings.any(
      (rating) => !_movieCache.containsKey(rating.movieId),
    );
    if (hasUnknownMovie) {
      load();
    } else {
      _rebuild();
    }
  }

  /// 실패하면 [RatingWriteFailure]를 던지고, Dialog가 입력을 유지한 채 문구를 보여줍니다.
  /// comment가 null이면 서버의 기존 후기도 null로 바뀝니다. (전체 교체)
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) => _ratings.update(ratingId: ratingId, score: score, comment: comment);

  Future<void> deleteRating(int ratingId) => _ratings.delete(ratingId);

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

  /// 선택한 평점을 하나씩 지웁니다. 실패한 항목은 선택 상태로 남기고 나머지를 계속 처리합니다.
  /// 401을 받으면 세션이 정리되므로 남은 요청을 보내지 않고 멈춥니다.
  Future<BulkDeleteResult> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) {
      return const BulkDeleteResult();
    }
    isDeletingSelected = true;
    notifyListeners();
    var deleted = 0;
    var sessionExpired = false;
    final messages = <String>[];
    try {
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _ratings.delete(ratingId);
          selectedRatingIds.remove(ratingId);
          deleted++;
        } on RatingWriteFailure catch (failure) {
          messages.add(failure.message);
          if (failure.sessionExpired) {
            sessionExpired = true;
            break;
          }
        }
      }
    } finally {
      isDeletingSelected = false;
      if (!_disposed) {
        if (selectedRatingIds.isEmpty) isSelecting = false;
        notifyListeners();
      }
    }
    return BulkDeleteResult(
      deleted: deleted,
      failed: messages.length,
      messages: messages,
      sessionExpired: sessionExpired,
    );
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
    _ratings.removeListener(_onRatingsChanged);
    super.dispose();
  }
}

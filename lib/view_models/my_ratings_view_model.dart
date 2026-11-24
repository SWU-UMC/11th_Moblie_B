import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/network/api_error.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/rating_request.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

// v7에는 토큰 기반 내 평점 GET이 없습니다. 등록 응답만 현재 세션에 보관합니다.
// 앱 재시작/로그아웃 뒤의 전체 평점 복원은 지원하지 않습니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._auth)
    : _version = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }
  final RatingApiService _service;
  final AuthViewModel _auth;
  int _version;
  bool _disposed = false;
  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus get status =>
      ratings.isEmpty ? MyRatingsLoadStatus.empty : MyRatingsLoadStatus.success;
  String? message;
  String? get refreshWarning => null;
  bool isWriting = false;
  bool _current(int version) =>
      !_disposed &&
      version == _auth.sessionVersion &&
      _auth.status == AuthStatus.signedIn;
  void _onAuthChanged() {
    if (_version == _auth.sessionVersion) return;
    _version = _auth.sessionVersion;
    ratings = const [];
    message = null;
    isWriting = false;
    notifyListeners();
  }

  Future<void> load() async {
    if (!_disposed) notifyListeners();
  }

  Future<void> createRating(
    TmdbMovieDto movie, {
    required int score,
    String? comment,
  }) => _write(() async {
    final result = await _service.createRating(
      CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
    );
    return () {
      ratings = [
        ...ratings.where((e) => e.rating.ratingId != result.ratingId),
        RatingWithMovie(
          rating: result,
          movie: result.movieId == movie.id ? movie : null,
        ),
      ];
    };
  });
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) => _write(() async {
    final result = await _service.updateRating(
      ratingId: ratingId,
      score: score,
      comment: comment,
    );
    return () {
      ratings = ratings
          .map(
            (e) => e.rating.ratingId == ratingId
                ? RatingWithMovie(
                    rating: result,
                    movie: e.movie?.id == result.movieId ? e.movie : null,
                  )
                : e,
          )
          .toList();
    };
  }, ratingId: ratingId);
  Future<void> deleteRating(int ratingId) => _write(() async {
    await _service.deleteRating(ratingId);
    return () {
      ratings = ratings.where((e) => e.rating.ratingId != ratingId).toList();
    };
  }, ratingId: ratingId);
  Future<void> _write(
    Future<VoidCallback> Function() request, {
    int? ratingId,
  }) async {
    final version = _auth.sessionVersion;
    if (!_current(version) || isWriting) throw StateError('요청할 수 없는 상태입니다.');
    isWriting = true;
    message = null;
    notifyListeners();
    try {
      final apply = await request();
      if (!_current(version)) throw StateError('세션이 변경되었습니다.');
      apply();
    } on DioException catch (error) {
      if (!_current(version)) throw StateError('세션이 변경되었습니다.');
      if (isSessionExpiredError(error)) {
        await _auth.expireSession(expectedVersion: version);
      } else {
        message = writeErrorMessage(error);
        // 전체 내 목록 GET 계약이 없어 404 대상만 현재 작업 목록에서 제거합니다.
        if (apiErrorCode(error) == 'RATING404_1' && ratingId != null) {
          ratings = ratings
              .where((e) => e.rating.ratingId != ratingId)
              .toList();
        }
      }
      rethrow;
    } finally {
      if (_current(version)) {
        isWriting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

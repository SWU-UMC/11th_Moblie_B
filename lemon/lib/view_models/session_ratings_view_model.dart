import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';

/// 이번 로그인 세션에서 등록한 평점과, 토큰 기반 등록·수정·삭제를 관리합니다.
///
/// v7에는 토큰 기반 "내 평점 목록 GET"이 없고, 로그인·내 정보 응답에 memberId도 없습니다.
/// 그래서 등록 응답으로 받은 Rating 객체를 메모리에 두고 그것만 수정·삭제합니다.
/// 로그아웃·세션 만료·다른 계정 로그인(sessionVersion 변경) 시 모두 비웁니다.
/// 앱을 다시 시작하면 이전 평점 목록은 복원되지 않습니다. (계약 확인 전까지 미지원)
class SessionRatingsViewModel extends ChangeNotifier {
  SessionRatingsViewModel(this._service, this._auth)
    : _sessionVersion = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final RatingApiService _service;
  final AuthViewModel _auth;

  /// ratingId → 평점. 등록 순서를 유지합니다.
  final _ratings = <int, RatingDto>{};
  int _sessionVersion;
  bool _disposed = false;

  /// 최근에 등록한 평점이 위에 오도록 돌려줍니다.
  List<RatingDto> get ratings => _ratings.values.toList().reversed.toList();

  RatingDto? ratingForMovie(int movieId) {
    for (final rating in _ratings.values) {
      if (rating.movieId == movieId) return rating;
    }
    return null;
  }

  void _onAuthChanged() {
    // 같은 세션 안의 상태 변화(내 정보 로딩 등)는 무시하고, 세션이 바뀌었을 때만 비웁니다.
    if (_auth.sessionVersion == _sessionVersion) return;
    _sessionVersion = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    _notify();
  }

  /// 등록 result의 Rating 객체를 그대로 보관합니다. 목록 GET으로 다시 확인하지 않습니다.
  Future<RatingDto> create({
    required int movieId,
    required int score,
    String? comment,
  }) => _write(
    () => _service.createRating(
      CreateRatingRequest(movieId: movieId, score: score, comment: comment),
    ),
    onSuccess: (rating) => _ratings[rating.ratingId] = rating,
  );

  /// PATCH는 전체 교체라 기존 comment를 유지하려면 그대로 보내야 합니다.
  /// 수정 result로 카드 하나만 교체합니다.
  Future<RatingDto> update({
    required int ratingId,
    required int score,
    String? comment,
  }) => _write(
    () => _service.updateRating(
      ratingId: ratingId,
      score: score,
      comment: comment,
    ),
    ratingId: ratingId,
    onSuccess: (rating) => _ratings[rating.ratingId] = rating,
  );

  /// 200 + result null이면 성공입니다. 성공한 뒤에만 목록에서 뺍니다.
  Future<void> delete(int ratingId) => _write(
    () => _service.deleteRating(ratingId),
    ratingId: ratingId,
    onSuccess: (_) => _ratings.remove(ratingId),
  );

  /// 보호 요청 공통 처리입니다.
  /// - AUTH401_2/3/4: 세션을 정리하고(→ /login), sessionExpired 실패를 던집니다.
  /// - RATING404_1: 서버에 이미 없으므로 목록에서도 뺍니다.
  /// - RATING403_1·RATING409_1·COMMON400: 안내만 하고 로그인 상태를 유지합니다.
  /// - 요청 중에 로그아웃·재로그인됐다면 늦게 온 응답을 반영하지 않습니다.
  Future<T> _write<T>(
    Future<T> Function() request, {
    int? ratingId,
    required void Function(T result) onSuccess,
  }) async {
    final version = _auth.sessionVersion;
    if (!_auth.isSignedIn) {
      throw const RatingWriteFailure('로그인이 필요해요.', sessionExpired: true);
    }
    try {
      final result = await request();
      if (_disposed || version != _auth.sessionVersion) {
        throw const RatingWriteFailure(
          '이전 로그인 세션의 응답이라 반영하지 않았어요.',
          sessionExpired: true,
        );
      }
      onSuccess(result);
      _notify();
      return result;
    } on DioException catch (error) {
      if (isSessionExpiredError(error)) {
        await _auth.expireSession(sessionVersion: version);
        throw RatingWriteFailure(
          writeErrorMessage(error),
          sessionExpired: true,
        );
      }
      // 요청 중에 로그아웃·재로그인됐다면 실패도 이전 세션의 결과입니다.
      // 새 세션에서 남은 요청(선택 삭제 등)을 이어 보내지 않도록 멈춥니다.
      if (_disposed || version != _auth.sessionVersion) {
        throw const RatingWriteFailure(
          '이전 로그인 세션의 요청이라 중단했어요.',
          sessionExpired: true,
        );
      }
      if (ratingId != null &&
          isRatingGone(error) &&
          _ratings.remove(ratingId) != null) {
        _notify();
      }
      throw RatingWriteFailure(writeErrorMessage(error));
    } on RatingWriteFailure {
      rethrow;
    } catch (error) {
      // 200/201인데 형식이 다르거나, 삭제가 200이 아닌 경우입니다.
      debugPrint('평점 응답 확인 실패: $error');
      throw const RatingWriteFailure('저장 결과를 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

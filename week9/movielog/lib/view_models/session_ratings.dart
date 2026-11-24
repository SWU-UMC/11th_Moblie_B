import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';

/// 이번 로그인 세션에서 등록한 평점 (메모리)
/// v7·v8엔 토큰 기반 "내 평점 전체 GET"이 없고 로그인 응답에 memberId도 없음
/// → 등록 응답 Rating만 모아서 수정·삭제에 씀
/// 앱 재시작하면 비어 있음 (전체 복원은 계약 확인 전까지 미완료로 둠)
class SessionRatings extends ChangeNotifier {
  final List<RatingDto> _ratings = [];

  /// 최근 등록이 위로
  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  RatingDto? findByMovie(int movieId) {
    for (final rating in _ratings) {
      if (rating.movieId == movieId) return rating;
    }
    return null;
  }

  void add(RatingDto rating) {
    _ratings.removeWhere((r) => r.ratingId == rating.ratingId);
    _ratings.insert(0, rating);
    notifyListeners();
  }

  /// PATCH 성공 result로 교체
  void replace(RatingDto rating) {
    final index = _ratings.indexWhere((r) => r.ratingId == rating.ratingId);
    if (index < 0) return;
    _ratings[index] = rating;
    notifyListeners();
  }

  /// DELETE 성공, 또는 서버에 이미 없음(RATING404_1)
  void remove(int ratingId) {
    final before = _ratings.length;
    _ratings.removeWhere((r) => r.ratingId == ratingId);
    if (_ratings.length != before) notifyListeners();
  }

  /// 로그아웃·만료·다른 계정 로그인 때 이전 사람 평점 안 남게 비움
  void clear() {
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }
}

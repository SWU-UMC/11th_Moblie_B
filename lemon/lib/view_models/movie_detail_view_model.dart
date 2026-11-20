import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'session_ratings_view_model.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 영화 상세 화면의 영화 DTO와 평점 등록·수정·삭제 상태를 관리합니다.
///
/// 이 화면은 보호 Route라 로그인 상태에서만 열립니다. 쓰기는 토큰으로 본인을 식별하므로
/// memberId를 받지 않습니다. 평점 카드는 [SessionRatingsViewModel]의 값을 그대로 보여줍니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratings, this.movie) {
    _ratings.addListener(_notify);
  }

  final SessionRatingsViewModel _ratings;

  /// 제목·포스터는 TMDB DTO를, movieId도 이 DTO의 id를 씁니다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 마지막 실패가 세션 만료였는지입니다. 화면은 이때 Dialog 안내 대신 로그인 이동을 기다립니다.
  bool submitSessionExpired = false;
  bool _disposed = false;

  /// 이번 로그인 세션에서 이 영화에 등록한 평점입니다. (등록 result의 Rating 객체)
  RatingDto? get myRating => _ratings.ratingForMovie(movie.id);

  Future<void> createRating({required int score, String? comment}) => _submit(
    () => _ratings.create(movieId: movie.id, score: score, comment: comment),
  );

  Future<void> updateRating({required int score, String? comment}) {
    final rating = myRating;
    if (rating == null) return Future.value();
    return _submit(
      () => _ratings.update(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    );
  }

  Future<void> deleteRating() {
    final rating = myRating;
    if (rating == null) return Future.value();
    return _submit(() => _ratings.delete(rating.ratingId));
  }

  Future<void> _submit(Future<Object?> Function() request) async {
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    submitSessionExpired = false;
    _notify();

    try {
      await request();
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
    } on RatingWriteFailure catch (failure) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = failure.message;
      submitSessionExpired = failure.sessionExpired;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ratings.removeListener(_notify);
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'my_ratings_view_model.dart';
import 'auth_view_model.dart';
import 'submit_status.dart';

class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratings, this._auth, this.movie);
  final MyRatingsViewModel _ratings;
  final AuthViewModel _auth;
  final TmdbMovieDto movie;
  bool get canRate => _auth.status == AuthStatus.signedIn;
  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;
  Future<void> createRating({required int score, String? comment}) async {
    if (_disposed || submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();
    try {
      await _ratings.createRating(movie, score: score, comment: comment);
      if (_disposed || version != _auth.sessionVersion) return;
      submitStatus = SubmitStatus.success;
    } catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;
      submitStatus = SubmitStatus.error;
      submitMessage = error is DioException
          ? writeErrorMessage(error)
          : '등록 결과를 확인하지 못했습니다. 현재 세션 평점을 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

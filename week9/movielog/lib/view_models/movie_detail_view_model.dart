import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/movie_record_models.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_status.dart';
import 'session_ratings.dart';
import 'submit_status.dart';

/// 영화 상세: extra로 받은 영화 있으면 바로 씀
/// 없으면 id로 TMDB에서 불러옴
/// 평점 등록만 여기서 함 (수정·삭제는 마이페이지)
/// 8주차: memberId 대신 토큰(보호 Dio)으로 등록
/// 9주차: 즐겨찾기 상태는 FavoriteDetailViewModel이 서버 값으로 따로 관리
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service,
    this._ratingService, {
    required this.movieId,
    required this._auth,
    required this._sessionRatings,
    this.movie,
  }) : status = movie == null ? LoadStatus.idle : LoadStatus.success;

  final TmdbMovieService _service;
  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;

  /// TMDB 영화 id (path param)
  final int? movieId;

  TmdbMovieDto? movie;
  List<TmdbGenreDto> genres = const [];
  LoadStatus status;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  bool _disposed = false;

  /// 이번 세션에서 이 영화에 등록한 별점 (등록 result Rating 기준)
  int? get myScore {
    final id = movie?.id ?? movieId;
    return id == null ? null : _sessionRatings.findByMovie(id)?.score;
  }

  /// 로그인 상태 + 이번 세션에서 아직 안 남긴 영화만 등록 가능
  /// (이미 남긴 건 409라 마이페이지에서 수정)
  bool get canRate => _auth.isSignedIn && myScore == null;

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

  /// 실패했지만 Dialog는 닫고 Snackbar로 알릴 오류인지 (Challenge)
  /// RATING409_1·FAVORITE409_1·MEMBER404_1·세션 만료 → 닫음
  /// COMMON400·네트워크 → Dialog 유지 (입력 그대로 두고 안에 이유 표시)
  bool submitClosesDialog = false;

  /// 마지막 저장에서 즐겨찾기까지 같이 저장됐는지
  bool savedWithFavorite = false;

  static const _closeDialogCodes = {
    'RATING409_1',
    'FAVORITE409_1',
    'MEMBER404_1',
  };

  /// 평점 저장
  /// - addToFavorites false: POST /v8/ratings (평점만)
  /// - addToFavorites true (Challenge): POST /v8/movie-records (평점+즐겨찾기 한 트랜잭션)
  /// path·body에 memberId 없음, movieId는 TMDB id 그대로 보냄
  Future<void> createRating({
    required int score,
    String? comment,
    bool addToFavorites = false,
  }) async {
    final current = movie;
    if (!_auth.isSignedIn || current == null) {
      submitStatus = SubmitStatus.error;
      submitClosesDialog = false;
      submitMessage = '로그인 후 평점을 남길 수 있어요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;
    // 요청 보낼 때 세션 기억 → 로그아웃·계정 전환 뒤 늦은 응답 무시
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    submitClosesDialog = false;
    savedWithFavorite = false;
    notifyListeners();

    try {
      if (addToFavorites) {
        final record = await _ratingService.createMovieRecord(
          CreateMovieRecordRequest(
            movieId: current.id,
            score: score,
            comment: comment,
            addToFavorites: true,
          ),
        );
        if (!_isCurrent(version)) return;
        _sessionRatings.add(record.rating);
        savedWithFavorite = record.favorite != null;
      } else {
        final created = await _ratingService.createRating(
          CreateRatingRequest(
            movieId: current.id,
            score: score,
            comment: comment,
          ),
        );
        if (!_isCurrent(version)) return;
        // 등록 result Rating 객체로 바로 반영 (목록 다시 안 부름)
        _sessionRatings.add(created);
      }
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      final code = apiErrorCode(error);
      debugPrint('평점 저장 실패: ${error.response?.statusCode} $code');
      submitStatus = SubmitStatus.error;
      if (isSessionExpired(error)) {
        submitMessage = '로그인이 만료됐어요.';
        submitClosesDialog = true;
        // 세션 정리 → Router가 /login으로 보냄
        await _auth.expireSession(version: version);
        return;
      }
      // 403·409 등은 안내만 하고 로그인 유지
      submitClosesDialog = _closeDialogCodes.contains(code);
      submitMessage = code == 'COMMON400'
          ? (apiErrorMessage(error) ?? '입력값을 확인해 주세요.')
          : (error.response == null
                ? '네트워크 연결을 확인하고 다시 시도해 주세요.'
                : writeErrorMessage(error));
    } catch (error) {
      if (!_isCurrent(version)) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '평점을 저장하지 못했어요.';
    }
    if (!_disposed) notifyListeners();
  }

  bool _isCurrent(int version) => !_disposed && version == _auth.sessionVersion;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

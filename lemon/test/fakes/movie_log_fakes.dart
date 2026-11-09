import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

DioException fakeDioError(String path, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: path),
  response: statusCode == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: path),
          statusCode: statusCode,
        ),
  message: 'fake error',
);

/// 실제 서버 대신 [taken]에 든 값만 "중복"으로 답하는 중복 확인 Service입니다.
class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService({this.taken = const {}, this.fail = false})
    : super(Dio());

  final Set<String> taken;
  bool fail;

  /// 값을 넣으면 [gate]가 완료될 때까지 응답을 미룹니다. (통신 중 상태 확인용)
  Completer<void>? gate;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];

  @override
  Future<bool> checkNickname(String nickname) {
    nicknameCalls.add(nickname);
    return _answer(nickname);
  }

  @override
  Future<bool> checkEmail(String email) {
    emailCalls.add(email);
    return _answer(email);
  }

  Future<bool> _answer(String value) async {
    final waitFor = gate;
    if (waitFor != null) await waitFor.future;
    if (fail) throw fakeDioError('/v5/members');
    return !taken.contains(value.trim());
  }
}

/// 평점 조회 결과를 테스트에서 직접 정하는 Service입니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService(this.handler) : super(Dio());

  Future<List<RatingDto>> Function(int memberId) handler;
  final memberIds = <int>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) {
    memberIds.add(memberId);
    return handler(memberId);
  }
}

/// movieId로 영화를 찾는 부분만 바꾼 TMDB Service입니다.
/// [movies]에 없는 id는 404(null), [failingIds]는 네트워크 오류로 답합니다.
class FakeMovieLookupService extends TmdbMovieService {
  FakeMovieLookupService({this.movies = const {}, this.failingIds = const {}})
    : super(Dio());

  final Map<int, TmdbMovieDto> movies;
  Set<int> failingIds;
  final lookups = <int>[];

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    lookups.add(movieId);
    if (failingIds.contains(movieId)) throw fakeDioError('/movie/$movieId');
    final movie = movies[movieId];
    if (movie == null) throw fakeDioError('/movie/$movieId', statusCode: 404);
    return movie;
  }

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async =>
      const TmdbMoviePageDto(
        page: 1,
        results: [],
        totalPages: 1,
        totalResults: 0,
      );
}

RatingDto fakeRating(int ratingId, int movieId, int score, {String? comment}) =>
    RatingDto(
      ratingId: ratingId,
      movieId: movieId,
      score: score,
      comment: comment,
      createdAt: DateTime.utc(2026, 11, 1, 3),
    );

TmdbMovieDto fakeMovie(int id, String title) => TmdbMovieDto(
  id: id,
  title: title,
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: null,
  genreIds: const [],
  voteAverage: 0,
  popularity: 0,
);

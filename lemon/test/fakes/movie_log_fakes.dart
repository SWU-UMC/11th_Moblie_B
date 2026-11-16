import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

DioException fakeDioError(String path, {int? statusCode, Object? data}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: statusCode == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: path),
              statusCode: statusCode,
              data: data,
            ),
      message: 'fake error',
    );

/// v6 공통 형식의 오류 응답입니다.
DioException fakeCommonError(
  String path,
  int statusCode,
  String code,
  String message,
) => fakeDioError(
  path,
  statusCode: statusCode,
  data: {'isSuccess': false, 'code': code, 'message': message, 'result': null},
);

/// 실제 서버 대신 [taken]에 든 값만 "중복"으로 답하는 회원가입 Service입니다.
class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    this.taken = const {},
    this.fail = false,
    this.onSignUp,
    this.memberId = 42,
  }) : super(Dio());

  final Set<String> taken;
  bool fail;

  /// 값을 넣으면 [gate]가 완료될 때까지 응답을 미룹니다. (통신 중 상태 확인용)
  Completer<void>? gate;

  /// 가입 요청을 직접 처리합니다. 없으면 [memberId]로 성공합니다.
  Future<CommonResponse<SignUpResult>> Function(CreateMemberRequest request)?
  onSignUp;
  final int memberId;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];
  final signUpCalls = <CreateMemberRequest>[];

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

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request);
    final handler = onSignUp;
    if (handler != null) return handler(request);
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: SignUpResult(
        memberId: memberId,
        email: request.email.trim(),
        nickname: request.nickname.trim(),
      ),
    );
  }

  Future<bool> _answer(String value) async {
    final waitFor = gate;
    if (waitFor != null) await waitFor.future;
    if (fail) throw fakeDioError('/v6/members');
    return !taken.contains(value.trim());
  }
}

/// 평점 조회·쓰기 결과를 테스트에서 직접 정하는 Service입니다.
/// 쓰기 handler가 없으면 성공으로 처리합니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService(
    this.handler, {
    this.onCreate,
    this.onUpdate,
    this.onDelete,
  }) : super(Dio());

  Future<List<RatingDto>> Function(int memberId) handler;
  Future<void> Function(int memberId, CreateRatingRequest request)? onCreate;
  Future<void> Function(int ratingId, int score, String? comment)? onUpdate;
  Future<void> Function(int ratingId)? onDelete;

  final memberIds = <int>[];
  final creates = <(int memberId, CreateRatingRequest request)>[];
  final updates = <(int memberId, int ratingId, int score, String? comment)>[];
  final deletes = <(int memberId, int ratingId)>[];

  /// 순서 확인용 호출 기록입니다. (예: ['PATCH 1', 'GET'])
  final log = <String>[];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) {
    memberIds.add(memberId);
    log.add('GET');
    return handler(memberId);
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    creates.add((memberId, request));
    log.add('POST');
    await onCreate?.call(memberId, request);
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updates.add((memberId, ratingId, score, comment));
    log.add('PATCH $ratingId');
    await onUpdate?.call(ratingId, score, comment);
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deletes.add((memberId, ratingId));
    log.add('DELETE $ratingId');
    await onDelete?.call(ratingId);
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

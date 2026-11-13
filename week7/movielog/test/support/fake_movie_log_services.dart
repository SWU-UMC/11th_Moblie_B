import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

DioException fakeHttpError(String path, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: path),
  response: statusCode == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: path),
          statusCode: statusCode,
        ),
  type: statusCode == null
      ? DioExceptionType.connectionError
      : DioExceptionType.badResponse,
);

/// v6 공통 형식 실패 응답
DioException fakeCommonError(String path, int statusCode, String message) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: statusCode,
        data: {
          'isSuccess': false,
          'code': 'COMMON$statusCode',
          'message': message,
          'result': null,
        },
      ),
      type: DioExceptionType.badResponse,
    );

/// 정해둔 값으로 중복 여부·가입 결과 응답하는 Fake
class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    this.takenNicknames = const {'무비러버'},
    this.takenEmails = const {'taken@example.com'},
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  bool fail = false;

  /// 있으면 complete 될 때까지 응답 지연
  Completer<void>? gate;

  /// 있으면 complete 될 때까지 가입 응답 지연
  Completer<void>? signUpGate;

  /// 가입 실패시킬 응답 (null이면 성공)
  DioException? signUpError;

  /// 성공 응답에 memberId 빼기 (계약 오류)
  bool omitMemberId = false;

  int nextMemberId = 42;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];
  final signUpCalls = <CreateMemberRequest>[];

  Future<void> _wait() async {
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname);
    await _wait();
    if (fail) throw fakeHttpError('/v6/members/nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email);
    await _wait();
    if (fail) throw fakeHttpError('/v6/members/email');
    return !takenEmails.contains(email.trim());
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request);
    final pending = signUpGate;
    if (pending != null) await pending.future;
    final error = signUpError;
    if (error != null) throw error;
    final json = request.toJson();
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: omitMemberId
          ? null
          : SignUpResult(
              memberId: nextMemberId,
              email: json['email'] as String,
              nickname: json['nickname'] as String,
            ),
    );
  }
}

RatingDto fakeRating(
  int ratingId,
  int movieId, {
  int score = 4,
  String? comment,
}) => RatingDto(
  ratingId: ratingId,
  movieId: movieId,
  score: score,
  comment: comment,
  createdAt: DateTime.utc(2026, 9, 6, 12),
);

/// 메모리 목록으로 조회·등록·수정·삭제하는 Fake
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings =
          ratings ??
          [
            fakeRating(3, 13, score: 3),
            fakeRating(2, 2, score: 4, comment: '다시 봐도 좋다'),
            fakeRating(1, 3, score: 5, comment: '최고의 영화!'),
          ],
      super(Dio());

  List<RatingDto> ratings;

  /// 조회를 이 상태 코드로 실패 (0이면 통신 실패)
  int? failStatus;

  /// 쓰기(등록·수정·삭제)를 이 응답으로 실패
  DioException? writeError;

  /// 이 ratingId 삭제만 실패 (다중 삭제 일부 실패용)
  Set<int> failDeleteIds = {};

  /// 쓰기 성공 직후 조회만 실패시키기
  bool failFetchAfterWrite = false;

  Completer<void>? gate;

  /// 있으면 쓰기 응답 지연
  Completer<void>? writeGate;

  int calls = 0;
  final createCalls = <(int, Map<String, dynamic>)>[];
  final updateCalls = <(int, int, Map<String, dynamic>)>[];
  final deleteCalls = <int>[];
  int _nextId = 100;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    calls++;
    final pending = gate;
    if (pending != null) await pending.future;
    final status = failStatus;
    if (status != null) {
      throw fakeHttpError(
        '/v6/members/$memberId/ratings',
        statusCode: status == 0 ? null : status,
      );
    }
    return List.of(ratings);
  }

  Future<void> _beforeWrite() async {
    final pending = writeGate;
    if (pending != null) await pending.future;
    final error = writeError;
    if (error != null) throw error;
  }

  void _afterWrite() {
    if (failFetchAfterWrite) failStatus = 500;
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    createCalls.add((memberId, request.toJson()));
    await _beforeWrite();
    ratings = [
      RatingDto(
        ratingId: _nextId++,
        movieId: request.movieId,
        score: request.score,
        comment: request.toJson()['comment'] as String?,
        createdAt: DateTime.utc(2026, 11, 10),
      ),
      ...ratings,
    ];
    _afterWrite();
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final body = request.toJson();
    updateCalls.add((memberId, ratingId, body));
    await _beforeWrite();
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId == ratingId)
          RatingDto(
            ratingId: rating.ratingId,
            movieId: rating.movieId,
            score: body['score'] as int,
            comment: body['comment'] as String?,
            createdAt: rating.createdAt,
          )
        else
          rating,
    ];
    _afterWrite();
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deleteCalls.add(ratingId);
    await _beforeWrite();
    if (failDeleteIds.contains(ratingId)) {
      throw fakeCommonError(
        '/v6/members/$memberId/ratings/$ratingId',
        404,
        '존재하지 않는 평점입니다.',
      );
    }
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId != ratingId) rating,
    ];
    _afterWrite();
  }
}

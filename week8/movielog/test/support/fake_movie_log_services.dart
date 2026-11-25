import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
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

/// 공통 형식 실패 응답 (code 직접 지정, v7 도메인 code용)
DioException fakeCodeError(
  String path,
  int statusCode,
  String code,
  String message,
) => DioException(
  requestOptions: RequestOptions(path: path),
  response: Response(
    requestOptions: RequestOptions(path: path),
    statusCode: statusCode,
    data: {
      'isSuccess': false,
      'code': code,
      'message': message,
      'result': null,
    },
  ),
  type: DioExceptionType.badResponse,
);

/// COMMON{status} 실패 응답
DioException fakeCommonError(String path, int statusCode, String message) =>
    fakeCodeError(path, statusCode, 'COMMON$statusCode', message);

/// 토큰 만료 401
DioException fakeExpiredError(String path) =>
    fakeCodeError(path, 401, 'AUTH401_4', '토큰이 만료되었습니다. 다시 로그인해주세요.');

/// 메모리 토큰 저장소 (secure storage 대신)
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;
  bool failRead = false;
  bool failDelete = false;
  int deleteCalls = 0;

  @override
  Future<void> saveAccessToken(String token) async => this.token = token;

  @override
  Future<String?> readAccessToken() async {
    if (failRead) throw StateError('저장소 읽기 실패');
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCalls++;
    if (failDelete) throw StateError('저장소 삭제 실패');
    token = null;
  }
}

/// 이메일·비밀번호 맞으면 토큰 주는 Fake 로그인
class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService({
    this.email = 'movie@example.com',
    this.password = 'Password1!',
    this.nickname = '무비러버',
  }) : super(Dio());

  final String email;
  final String password;
  final String nickname;

  /// 있으면 이 에러로 실패 (네트워크 등)
  DioException? error;
  Completer<void>? gate;
  final calls = <LoginRequest>[];
  int _tokenNo = 0;

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls.add(request);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    final json = request.toJson();
    if (json['email'] != email || json['password'] != password) {
      throw fakeCodeError(
        '/v7/auth/login',
        401,
        'AUTH401_1',
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    }
    return LoginResult(nickname: nickname, accessToken: 'token-${++_tokenNo}');
  }
}

MemberInfo fakeMember({String nickname = '무비러버'}) => MemberInfo(
  email: 'movie@example.com',
  nickname: nickname,
  createdAt: DateTime.utc(2026, 10, 10, 3),
);

/// 내 정보 GET·PATCH Fake
class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService({MemberInfo? member, this.takenNicknames = const {}})
    : member = member ?? fakeMember(),
      super(Dio());

  MemberInfo member;
  final Set<String> takenNicknames;

  /// GET me 실패 (null이면 성공)
  DioException? fetchError;

  /// PATCH me 실패
  DioException? updateError;
  Completer<void>? fetchGate;
  Completer<void>? updateGate;
  int fetchCalls = 0;
  final updateCalls = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    final pending = fetchGate;
    if (pending != null) await pending.future;
    final error = fetchError;
    if (error != null) throw error;
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls.add(nickname);
    final pending = updateGate;
    if (pending != null) await pending.future;
    final error = updateError;
    if (error != null) throw error;
    if (takenNicknames.contains(nickname)) {
      throw fakeCodeError(
        '/v7/members/me',
        409,
        'MEMBER409_1',
        '이미 사용 중인 닉네임입니다.',
      );
    }
    member = MemberInfo(
      email: member.email,
      nickname: nickname,
      createdAt: member.createdAt,
    );
    return member;
  }
}

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
    if (fail) throw fakeHttpError('/v7/members/nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email);
    await _wait();
    if (fail) throw fakeHttpError('/v7/members/email');
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

/// v7 평점 Fake: 등록·수정은 Rating 객체 반환, 삭제는 성공만
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService() : super(Dio(), Dio());

  /// 서버에 있는 평점 (ratingId → Rating)
  final Map<int, RatingDto> server = {};

  /// 쓰기(등록·수정·삭제)를 이 응답으로 실패
  DioException? writeError;

  /// 이 ratingId 삭제만 실패 (다중 삭제 일부 실패용)
  Set<int> failDeleteIds = {};

  /// 있으면 쓰기 응답 지연
  Completer<void>? writeGate;

  final createCalls = <Map<String, dynamic>>[];
  final updateCalls = <(int, Map<String, dynamic>)>[];
  final deleteCalls = <int>[];
  int _nextId = 100;

  @override
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async =>
      server.values.toList();

  Future<void> _beforeWrite() async {
    final pending = writeGate;
    if (pending != null) await pending.future;
    final error = writeError;
    if (error != null) throw error;
  }

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final body = request.toJson();
    createCalls.add(body);
    await _beforeWrite();
    if (server.values.any((r) => r.movieId == request.movieId)) {
      throw fakeCodeError(
        '/v7/ratings',
        409,
        'RATING409_1',
        '이미 이 영화에 평점을 남기셨습니다.',
      );
    }
    final rating = RatingDto(
      ratingId: _nextId++,
      movieId: request.movieId,
      score: request.score,
      comment: body['comment'] as String?,
      createdAt: DateTime.utc(2026, 11, 19),
    );
    server[rating.ratingId] = rating;
    return rating;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final body = request.toJson();
    updateCalls.add((ratingId, body));
    await _beforeWrite();
    final old = server[ratingId];
    if (old == null) {
      throw fakeCodeError(
        '/v7/ratings/$ratingId',
        404,
        'RATING404_1',
        '해당 평점을 찾을 수 없습니다.',
      );
    }
    final updated = RatingDto(
      ratingId: ratingId,
      movieId: old.movieId,
      score: body['score'] as int,
      comment: body['comment'] as String?,
      createdAt: old.createdAt,
    );
    server[ratingId] = updated;
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteCalls.add(ratingId);
    await _beforeWrite();
    if (failDeleteIds.contains(ratingId)) {
      throw fakeCodeError(
        '/v7/ratings/$ratingId',
        403,
        'RATING403_1',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
    }
    if (server.remove(ratingId) == null) {
      throw fakeCodeError(
        '/v7/ratings/$ratingId',
        404,
        'RATING404_1',
        '해당 평점을 찾을 수 없습니다.',
      );
    }
  }
}

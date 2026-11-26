import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';
import '../models/member_info.dart';
import '../models/sign_up_models.dart';
import 'member_api_service.dart';
import 'rating_api_service.dart';
import 'sign_up_service.dart';

/// `--dart-define=<name>=<mode>` 값을 enum으로 바꿉니다.
/// 값이 없으면 [fallback]을 쓰고, 오타처럼 알 수 없는 값이면 바로 알려줍니다.
T _modeFromEnvironment<T extends Enum>(
  String name,
  String value,
  List<T> values,
  T fallback,
) {
  if (value.isEmpty) return fallback;
  final mode = values.asNameMap()[value];
  if (mode == null) {
    throw ArgumentError.value(
      value,
      name,
      '${values.map((mode) => mode.name).join(', ')} 중 하나여야 합니다',
    );
  }
  return mode;
}

DioException _fakeError(String path, String reason) => DioException(
  requestOptions: RequestOptions(path: path),
  message: '$reason: 일부러 실패시킨 요청',
);

Future<void> _wait(int seconds) =>
    Future<void>.delayed(Duration(seconds: seconds));

/// 회원가입 화면의 요청 결과를 정하는 모드입니다. (`MEMBER_CHECK_MODE`)
enum MemberCheckMode {
  /// 실제 응답을 그대로 사용합니다.
  success,

  /// 중복 확인·가입 요청 모두 3초 기다린 뒤 실제 응답을 사용합니다. 통신 중 화면 확인용입니다.
  slow,

  /// 중복 확인 통신 자체가 실패합니다. (DioException)
  error,

  /// 중복 확인은 항상 "사용 가능"이라고 답하고, 가입 POST만 실제 서버로 보냅니다.
  /// 확인 직후 다른 사람이 같은 값으로 먼저 가입한 상황을 재현해 최종 409를 확인합니다.
  staleAvailable;

  static MemberCheckMode fromEnvironment() => _modeFromEnvironment(
    'MEMBER_CHECK_MODE',
    const String.fromEnvironment('MEMBER_CHECK_MODE'),
    values,
    success,
  );
}

/// 평점 등록·수정·삭제 결과를 정하는 모드입니다. (`RATING_WRITE_MODE`)
enum RatingWriteMode {
  /// 실제 응답을 그대로 사용합니다.
  success,

  /// 3초 기다린 뒤 실제 요청을 보냅니다. 저장 중 Dialog·오버레이 확인용입니다.
  slow,

  /// 쓰기 통신 자체가 실패합니다. 저장 실패 후 입력이 유지되는지 확인합니다.
  error;

  static RatingWriteMode fromEnvironment() => _modeFromEnvironment(
    'RATING_WRITE_MODE',
    const String.fromEnvironment('RATING_WRITE_MODE'),
    values,
    success,
  );
}

/// 앱 시작 시 세션 확인(GET me) 결과를 정하는 모드입니다. (`AUTH_RESTORE_MODE`)
enum AuthRestoreMode {
  /// 실제 응답을 그대로 사용합니다.
  success,

  /// 3초 기다린 뒤 실제 요청을 보냅니다. Splash 로딩 확인용입니다.
  slow,

  /// 첫 GET me만 네트워크 오류로 실패시킵니다. 토큰을 지우지 않고 재시도 화면이 나오는지,
  /// 다시 시도하면 실제 응답으로 홈에 들어가는지 확인합니다.
  errorOnce;

  static AuthRestoreMode fromEnvironment() => _modeFromEnvironment(
    'AUTH_RESTORE_MODE',
    const String.fromEnvironment('AUTH_RESTORE_MODE'),
    values,
    success,
  );
}

/// 회원가입 화면의 요청 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
class DebugSignUpService extends SignUpService {
  DebugSignUpService(super.dio, {required this.mode});

  final MemberCheckMode mode;

  @override
  Future<bool> checkNickname(String nickname) =>
      _check('/v8/members/nickname', () => super.checkNickname(nickname));

  @override
  Future<bool> checkEmail(String email) =>
      _check('/v8/members/email', () => super.checkEmail(email));

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    if (mode == MemberCheckMode.slow) await _wait(3);
    return super.signUp(request);
  }

  Future<bool> _check(String path, Future<bool> Function() request) async {
    switch (mode) {
      case MemberCheckMode.success:
        return request();
      case MemberCheckMode.slow:
        await _wait(3);
        return request();
      case MemberCheckMode.error:
        await _wait(1);
        throw _fakeError(path, 'MEMBER_CHECK_MODE=error');
      case MemberCheckMode.staleAvailable:
        await _wait(1);
        return true;
    }
  }
}

/// 평점 쓰기 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
class DebugRatingApiService extends RatingApiService {
  DebugRatingApiService(
    super.publicDio,
    super.authDio, {
    required this.writeMode,
  });

  final RatingWriteMode writeMode;

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) =>
      _write('/v8/ratings', () => super.createRating(request));

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) => _write(
    '/v8/ratings/$ratingId',
    () =>
        super.updateRating(ratingId: ratingId, score: score, comment: comment),
  );

  @override
  Future<void> deleteRating(int ratingId) =>
      _write('/v8/ratings/$ratingId', () => super.deleteRating(ratingId));

  Future<T> _write<T>(String path, Future<T> Function() request) async {
    switch (writeMode) {
      case RatingWriteMode.success:
        return request();
      case RatingWriteMode.slow:
        await _wait(3);
        return request();
      case RatingWriteMode.error:
        await _wait(1);
        throw _fakeError(path, 'RATING_WRITE_MODE=error');
    }
  }
}

/// 세션 확인(GET me) 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
/// 프로필 수정(PATCH)은 그대로 실제 서버로 보냅니다.
class DebugMemberApiService extends MemberApiService {
  DebugMemberApiService(super.authDio, {required this.restoreMode});

  final AuthRestoreMode restoreMode;
  bool _failedOnce = false;

  @override
  Future<MemberInfo> fetchMe() async {
    switch (restoreMode) {
      case AuthRestoreMode.success:
        return super.fetchMe();
      case AuthRestoreMode.slow:
        await _wait(3);
        return super.fetchMe();
      case AuthRestoreMode.errorOnce:
        if (!_failedOnce) {
          _failedOnce = true;
          await _wait(1);
          throw _fakeError('/v8/members/me', 'AUTH_RESTORE_MODE=errorOnce');
        }
        return super.fetchMe();
    }
  }
}

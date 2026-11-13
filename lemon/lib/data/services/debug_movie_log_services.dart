import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';
import '../models/sign_up_models.dart';
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

/// 내가 등록한 평점 조회 결과를 정하는 모드입니다. (`RATING_LOAD_MODE`)
enum RatingLoadMode {
  /// 실제 응답을 그대로 사용합니다.
  success,

  /// 3초 기다린 뒤 실제 응답을 사용합니다. Loading 화면 확인용입니다.
  slow,

  /// 평점이 하나도 없는 빈 배열을 돌려줍니다.
  empty,

  /// 통신 자체가 실패합니다. 재시도하면 실제 응답을 사용합니다.
  errorOnce;

  static RatingLoadMode fromEnvironment() => _modeFromEnvironment(
    'RATING_LOAD_MODE',
    const String.fromEnvironment('RATING_LOAD_MODE'),
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
  error,

  /// 쓰기는 실제로 성공시키고, 바로 다음 목록 GET만 한 번 실패시킵니다.
  /// "저장 성공 + 목록 재조회 실패"와 조회만 다시 시도하는 흐름을 확인합니다.
  refreshErrorOnce;

  static RatingWriteMode fromEnvironment() => _modeFromEnvironment(
    'RATING_WRITE_MODE',
    const String.fromEnvironment('RATING_WRITE_MODE'),
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
      _check('/v6/members/nickname', () => super.checkNickname(nickname));

  @override
  Future<bool> checkEmail(String email) =>
      _check('/v6/members/email', () => super.checkEmail(email));

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

/// 평점 조회·쓰기 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
class DebugRatingApiService extends RatingApiService {
  DebugRatingApiService(
    super.dio, {
    this.loadMode = RatingLoadMode.success,
    this.writeMode = RatingWriteMode.success,
  });

  final RatingLoadMode loadMode;
  final RatingWriteMode writeMode;
  bool _loadFailedOnce = false;
  bool _failNextLoad = false;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final path = '/v6/members/$memberId/ratings';
    if (_failNextLoad) {
      _failNextLoad = false;
      await _wait(1);
      throw _fakeError(path, 'RATING_WRITE_MODE=refreshErrorOnce');
    }
    switch (loadMode) {
      case RatingLoadMode.success:
        return super.fetchMyRatings(memberId);
      case RatingLoadMode.slow:
        await _wait(3);
        return super.fetchMyRatings(memberId);
      case RatingLoadMode.empty:
        await _wait(1);
        return const [];
      case RatingLoadMode.errorOnce:
        if (!_loadFailedOnce) {
          _loadFailedOnce = true;
          await _wait(1);
          throw _fakeError(path, 'RATING_LOAD_MODE=errorOnce');
        }
        return super.fetchMyRatings(memberId);
    }
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) => _write(
    '/v6/members/$memberId/ratings',
    () => super.createRating(memberId: memberId, request: request),
  );

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) => _write(
    '/v6/members/$memberId/ratings/$ratingId',
    () => super.updateRating(
      memberId: memberId,
      ratingId: ratingId,
      score: score,
      comment: comment,
    ),
  );

  @override
  Future<void> deleteRating({required int memberId, required int ratingId}) =>
      _write(
        '/v6/members/$memberId/ratings/$ratingId',
        () => super.deleteRating(memberId: memberId, ratingId: ratingId),
      );

  Future<void> _write(String path, Future<void> Function() request) async {
    switch (writeMode) {
      case RatingWriteMode.success:
        return request();
      case RatingWriteMode.slow:
        await _wait(3);
        return request();
      case RatingWriteMode.error:
        await _wait(1);
        throw _fakeError(path, 'RATING_WRITE_MODE=error');
      case RatingWriteMode.refreshErrorOnce:
        await request();
        _failNextLoad = true;
    }
  }
}

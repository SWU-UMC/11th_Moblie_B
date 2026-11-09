import 'package:dio/dio.dart';

import '../models/rating_dto.dart';
import 'member_check_service.dart';
import 'rating_api_service.dart';

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

/// 중복 확인 요청 결과를 정하는 모드입니다. (`MEMBER_CHECK_MODE`)
enum MemberCheckMode {
  /// 실제 응답을 그대로 사용합니다.
  success,

  /// 3초 기다린 뒤 실제 응답을 사용합니다. 통신 중 화면 확인용입니다.
  slow,

  /// 통신 자체가 실패합니다. (DioException)
  error;

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

/// 중복 확인 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
class DebugMemberCheckService extends MemberCheckService {
  DebugMemberCheckService(super.dio, {required this.mode});

  final MemberCheckMode mode;

  @override
  Future<bool> checkNickname(String nickname) =>
      _apply('/v5/members/nickname', () => super.checkNickname(nickname));

  @override
  Future<bool> checkEmail(String email) =>
      _apply('/v5/members/email', () => super.checkEmail(email));

  Future<bool> _apply(String path, Future<bool> Function() request) async {
    switch (mode) {
      case MemberCheckMode.success:
        return request();
      case MemberCheckMode.slow:
        await Future<void>.delayed(const Duration(seconds: 3));
        return request();
      case MemberCheckMode.error:
        await Future<void>.delayed(const Duration(seconds: 1));
        throw _fakeError(path, 'MEMBER_CHECK_MODE=error');
    }
  }
}

/// 평점 조회 결과를 모드에 맞게 바꾸는 개발용 Service입니다.
class DebugRatingApiService extends RatingApiService {
  DebugRatingApiService(super.dio, {required this.mode});

  final RatingLoadMode mode;
  bool _failedOnce = false;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    switch (mode) {
      case RatingLoadMode.success:
        return super.fetchMyRatings(memberId);
      case RatingLoadMode.slow:
        await Future<void>.delayed(const Duration(seconds: 3));
        return super.fetchMyRatings(memberId);
      case RatingLoadMode.empty:
        await Future<void>.delayed(const Duration(seconds: 1));
        return const [];
      case RatingLoadMode.errorOnce:
        if (!_failedOnce) {
          _failedOnce = true;
          await Future<void>.delayed(const Duration(seconds: 1));
          throw _fakeError(
            '/v5/members/$memberId/ratings',
            'RATING_LOAD_MODE=errorOnce',
          );
        }
        return super.fetchMyRatings(memberId);
    }
  }
}

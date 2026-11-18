import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입 API (6주차 MemberCheckService에서 이름 바꿈)
/// 중복 확인 GET + 회원가입 POST
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// 사용 가능하면 true
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v6/members/nickname/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v6/members/email/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }

  /// 201이면 result에 memberId 담겨 옴
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v6/members',
      data: request.toJson(),
    );
    return CommonResponse<SignUpResult>.fromJson(
      response.data!,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 실패 문구
/// 서버 message가 이미 사용자용 문장이라 그대로 씀
String writeSignUpErrorMessage(DioException error) {
  return CommonResponse.tryParseError(error.response?.data)?.message ??
      '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

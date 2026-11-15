import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

import 'package:dio/dio.dart';

import '../models/check_result.dart';

class SignUpService {
  SignUpService(this._dio);
  final Dio _dio;
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());
    if (response.statusCode != 201) throw StateError('예상하지 못한 가입 응답입니다.');
    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

String writeSignUpErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value).message;
    } on FormatException {
      /* 공통 응답이 아닌 프록시 오류 */
    } on TypeError {
      /* 계약 외 응답 */
    }
  }
  return '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

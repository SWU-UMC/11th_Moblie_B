import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입 화면의 MovieLog API(v6)를 호출합니다.
/// 6주차 MemberCheckService의 중복 확인에 회원가입 POST를 더했습니다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// 사용할 수 있으면 true, 이미 사용 중이면 false입니다.
  /// 성공 응답은 공통 형식이 아닌 직접 객체(`{ "available": true }`)입니다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 사용할 수 있으면 true, 이미 사용 중이면 false입니다.
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 201이면 공통 응답의 result에 가입한 회원 정보가 들어 있습니다.
  /// 400(비밀번호 형식)·409(이메일·닉네임 중복)는 DioException으로 던집니다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 실패 응답의 서버 message를 그대로 사용자 문구로 씁니다.
/// (예: "이미 사용 중인 이메일입니다.") 형식이 다르거나 통신 실패면 기본 문구입니다.
String writeSignUpErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

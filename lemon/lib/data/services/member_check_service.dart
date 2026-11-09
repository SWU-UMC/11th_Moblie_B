import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 닉네임·이메일 중복 확인 API를 호출합니다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  /// 사용할 수 있으면 true, 이미 사용 중이면 false입니다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 사용할 수 있으면 true, 이미 사용 중이면 false입니다.
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }
}

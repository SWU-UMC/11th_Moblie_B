import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 닉네임/이메일 중복 확인 API
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  /// 사용 가능하면 true
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v5/members/nickname/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v5/members/email/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }
}

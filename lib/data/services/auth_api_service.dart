import 'package:dio/dio.dart';

import '../models/login_models.dart';
import '../models/common_response.dart';

class AuthApiService {
  AuthApiService(this._dio);
  final Dio _dio;
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _dio.post('/v7/auth/login', data: request.toJson());
    final data = response.data;
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw StateError('로그인 응답 형식이 올바르지 않습니다.');
    }
    final common = CommonResponse<LoginResult>.fromJson(
      data,
      (v) => LoginResult.fromJson(v as Map<String, dynamic>),
    );
    if (!common.isSuccess ||
        common.result == null ||
        common.result!.accessToken.isEmpty) {
      throw StateError('로그인 result가 없습니다.');
    }
    return common.result!;
  }
}

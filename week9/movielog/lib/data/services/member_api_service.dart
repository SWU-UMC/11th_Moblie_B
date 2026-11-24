import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 API (보호 Dio → Interceptor가 Bearer 붙임)
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get<Object?>('/v8/members/me');
    return parseMemberInfo(response.data);
  }

  /// 성공 result가 바뀐 내 정보라 GET me 다시 안 불러도 됨
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch<Object?>(
      '/v8/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}

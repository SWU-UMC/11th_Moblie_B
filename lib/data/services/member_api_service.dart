import 'package:dio/dio.dart';

import '../models/member_info.dart';

class MemberApiService {
  MemberApiService(this._authDio);
  final Dio _authDio;
  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    if (response.statusCode != 200) throw StateError('예상하지 못한 내 정보 응답입니다.');
    return parseMemberInfo(response.data);
  }

  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    if (response.statusCode != 200) throw StateError('예상하지 못한 프로필 수정 응답입니다.');
    return parseMemberInfo(response.data);
  }
}

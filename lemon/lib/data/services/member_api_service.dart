import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 조회·수정 API입니다. 보호용 Client(AuthInterceptor 등록)를 받습니다.
/// 경로에 memberId가 없고, 토큰으로 본인을 식별합니다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v8/members/me');
    return parseMemberInfo(response.data);
  }

  /// 수정할 수 있는 항목은 닉네임뿐입니다. 성공 응답이 곧 최신 내 정보입니다.
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v8/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}

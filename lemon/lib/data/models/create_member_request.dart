/// 회원가입 요청 body입니다. (`POST /v6/members`)
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;

  /// 사용자가 입력한 문자 그대로가 의미 있으므로 trim하지 않습니다.
  /// 로그·저장소·캡처에 남기지 않도록 toString에도 넣지 않습니다.
  final String password;
  final String nickname;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };

  @override
  String toString() =>
      'CreateMemberRequest(email: ${email.trim()}, nickname: ${nickname.trim()})';
}

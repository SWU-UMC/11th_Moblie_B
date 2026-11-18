/// POST /v6/members 요청 body
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// Dart 객체 → 요청 JSON
  /// 비밀번호는 입력한 그대로 보냄 (trim하면 값 자체가 바뀜)
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}

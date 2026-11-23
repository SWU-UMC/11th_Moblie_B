/// 로그인 요청 body입니다. (`POST /v8/auth/login`)
/// 비밀번호는 이 요청에만 담고, 어디에도 저장하거나 로그로 남기지 않습니다.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };

  /// 실수로 print해도 비밀번호가 보이지 않게 합니다.
  @override
  String toString() => 'LoginRequest(email: ${email.trim()}, password: ***)';
}

/// 로그인 성공 응답의 result입니다.
/// v8 명세에 memberId가 없으므로 추가하거나 JWT payload에서 추정하지 않습니다.
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    nickname: json['nickname'] as String,
    accessToken: json['accessToken'] as String,
  );

  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ***)';
}

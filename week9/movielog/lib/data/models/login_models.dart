/// POST /v8/auth/login 요청 body
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;

  /// 저장 안 하고 요청에만 씀
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };
}

/// 로그인 성공 result
/// memberId는 없음 → JWT payload에서 꺼내는 것도 안 함 (명세에 없음)
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
    nickname: json['nickname'] as String,
    accessToken: json['accessToken'] as String,
  );

  /// 디버그 출력에 토큰 원문 안 남게 막음
  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ***)';
}

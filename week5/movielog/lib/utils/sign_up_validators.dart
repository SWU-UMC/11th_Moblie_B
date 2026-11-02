/// 회원가입 입력값 검증 규칙
///
/// null을 반환하면 유효한 값, 문자열을 반환하면 그 문자열이 오류 메시지입니다.
abstract final class SignUpValidators {
  static const nicknameMinLength = 2;
  static const passwordMinLength = 8;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < nicknameMinLength) {
      return '닉네임은 $nicknameMinLength자 이상이어야 합니다.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (password.length < passwordMinLength) {
      return '비밀번호는 $passwordMinLength자 이상이어야 합니다.';
    }
    return null;
  }
}

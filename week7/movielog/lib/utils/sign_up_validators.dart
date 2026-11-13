/// 회원가입 입력값 검증 (v6 CreateMemberDto 제약 기준)
/// null이면 통과, 아니면 에러 메시지
/// 빠른 안내용이라 서버 검증을 대신하진 않음
abstract final class SignUpValidators {
  static const nicknameMinLength = 2;
  static const nicknameMaxLength = 12;
  static const passwordMinLength = 8;

  static const passwordRuleMessage = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // 소문자, 대문자, 숫자, 특수문자(!@#$%^&*) 각각 하나 이상 + 8자 이상
  static final _passwordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*]).{8,}$',
  );

  static String? nickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) return '닉네임을 입력해주세요.';
    if (nickname.length < nicknameMinLength) {
      return '닉네임은 $nicknameMinLength자 이상이어야 합니다.';
    }
    if (nickname.length > nicknameMaxLength) {
      return '닉네임은 $nicknameMaxLength자 이하여야 합니다.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailPattern.hasMatch(email)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  /// 비밀번호는 trim 안 함 (입력한 문자 그대로가 값)
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (!_passwordPattern.hasMatch(password)) return passwordRuleMessage;
    return null;
  }
}

/// 닉네임·이메일 중복 확인 응답입니다.
/// v6에서도 성공 응답은 공통 형식으로 감싸지 않아 body가 곧 `{ "available": true }`입니다.
/// (오류 응답만 공통 형식입니다.)
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}

/// 닉네임·이메일 중복 확인 응답입니다.
/// v5는 공통 Wrapper가 없으므로 응답 body가 곧 `{ "available": true }`입니다.
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}

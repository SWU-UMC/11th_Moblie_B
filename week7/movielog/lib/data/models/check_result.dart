/// 중복 확인 응답. 성공은 wrapper 없이 {available: bool}로 옴 (실패만 공통 형식)
class CheckResult {
  const CheckResult({required this.available});

  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}

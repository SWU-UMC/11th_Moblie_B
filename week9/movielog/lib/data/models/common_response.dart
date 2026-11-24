/// v6 공통 응답 {isSuccess, code, message, result}
/// 쓰기 API 성공 응답 + 모든 실패 응답이 이 모양
/// result는 API마다 달라서 제네릭, 없거나 실패면 null
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;

  /// COMMON201, COMMON409 같은 처리 결과 code
  final String code;

  /// 화면에 그대로 보여줘도 되는 문장
  final String message;
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }

  /// 실패 응답 body가 공통 형식이면 파싱, 아니면 null
  static CommonResponse<Object?>? tryParseError(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value);
    } on TypeError {
      // 공통 형식 아닌 body (게이트웨이 에러 페이지 등)
      return null;
    }
  }
}

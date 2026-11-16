/// v6 공통 응답 형식입니다. (`isSuccess`, `code`, `message`, `result`)
///
/// 회원가입·평점 등록·평점 수정의 성공 응답과, 모든 v6 API의 실패 응답이 이 형식입니다.
/// 중복 확인·평점 조회의 성공 응답은 기존처럼 직접 객체/배열이므로 이 Model로 파싱하지 않습니다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;

  /// API마다 담기는 값이 다릅니다. 값이 없거나 실패 응답이면 null입니다.
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

  /// 오류 응답 body를 공통 형식으로 읽습니다. 형식이 다르면 null입니다.
  static CommonResponse<Object?>? tryParseError(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value);
    } catch (_) {
      return null;
    }
  }
}

import 'package:dio/dio.dart';

/// 서버 오류 body(`{ isSuccess, code, message, result }`)에서 code를 꺼냅니다.
/// 형식이 다르거나 통신 자체가 실패했으면 null입니다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버 오류 body의 message를 꺼냅니다. 형식이 다르면 null입니다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청의 토큰 없음·무효·만료입니다. 현재 세션을 정리할 후보입니다.
///
/// 로그인 입력 오류 `AUTH401_1`은 여기에 넣지 않습니다. (로그인 Form 오류)
/// 403(`RATING403_1`)도 권한 부족이지 로그인 만료가 아니므로 넣지 않습니다.
const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

bool isSessionExpiredError(DioException error) =>
    sessionExpiredCodes.contains(apiErrorCode(error));

import 'package:dio/dio.dart';

/// 실패 body {isSuccess, code, message, result}에서 code만 꺼냄
/// 공통 형식 아니면 null (네트워크 끊김 등)
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버 message (사용자용 문장)
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 세션 정리 대상인 401 code
/// AUTH401_1(로그인 비밀번호 틀림)은 로그인 Form 오류라 여기 안 넣음
const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

bool isSessionExpired(DioException error) =>
    sessionExpiredCodes.contains(apiErrorCode(error));

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'movie_log_logging_interceptor.dart';

/// 워크북 자체 백엔드(MovieLog API) 전용 Dio Client입니다.
/// TMDB Client와 baseUrl·헤더가 다르므로 절대 하나로 합치지 않습니다.
/// TMDB Token(Authorization 헤더)을 이 Client에 넣지 않습니다.
BaseOptions _movieLogOptions() => BaseOptions(
  baseUrl: 'https://workbook.devnoco.com',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
);

/// 공개 요청용입니다. (로그인, 회원가입, 중복 확인, 유저별 평점 조회)
/// AuthInterceptor가 없으므로 MovieLog JWT가 붙지 않습니다.
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  // 비밀번호·토큰을 가린 로그만 Debug 빌드에서 남깁니다.
  if (kDebugMode) {
    dio.interceptors.add(MovieLogLoggingInterceptor(label: 'MovieLog 공개'));
  }
  return dio;
}

/// 보호 요청용입니다. (내 정보 조회·수정, 평점 등록·수정·삭제)
/// AuthInterceptor가 secure storage의 토큰을 `Authorization: Bearer ...`로 붙입니다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  // 로그는 Header가 붙은 뒤에 남겨야 "붙었는지"를 확인할 수 있으므로 뒤에 등록합니다.
  if (kDebugMode) {
    dio.interceptors.add(MovieLogLoggingInterceptor(label: 'MovieLog 보호'));
  }
  return dio;
}

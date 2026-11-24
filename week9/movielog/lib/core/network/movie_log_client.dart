import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'tmdb_logging_interceptor.dart';

/// 워크북 서버 공통 옵션
/// TMDB랑 baseUrl, 인증이 달라서 Dio 따로 만듦
BaseOptions _movieLogOptions() => BaseOptions(
  baseUrl: 'https://workbook.devnoco.com',
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
);

/// 공개 요청용: 로그인, 회원가입, 중복 확인, 유저별 평점 조회
/// Interceptor 없음 → 토큰 안 실림
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  if (kDebugMode) dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog'));
  return dio;
}

/// 보호 요청용: 내 정보, 평점 등록·수정·삭제
/// AuthInterceptor 먼저 등록 → 로그 Interceptor는 Authorization 가린 채로 찍음
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) {
    dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog 보호'));
  }
  return dio;
}

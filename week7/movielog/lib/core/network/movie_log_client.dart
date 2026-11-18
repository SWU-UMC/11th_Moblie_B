import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'tmdb_logging_interceptor.dart';

/// 워크북 서버용 Dio
/// TMDB랑 baseUrl, 인증이 달라서 따로 만듦
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(TmdbLoggingInterceptor(tag: 'MovieLog'));
  }

  return dio;
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// TMDB 요청/응답/오류 로그를 한 형식으로 남깁니다.
/// Authorization 값은 원문 대신 마스킹해서 출력합니다.
class TmdbLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }
    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[TMDB 응답 Body] ${response.data}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[TMDB 오류] ${err.requestOptions.uri}');
    // 401(Token 오류)처럼 서버가 응답한 경우 Status Code도 함께 남깁니다.
    debugPrint('[TMDB 오류 내용] ${err.response?.statusCode} ${err.message}');
    handler.next(err);
  }
}

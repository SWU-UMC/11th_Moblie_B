import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// TMDB Client를 거치는 모든 요청·응답·오류를 같은 형식으로 콘솔에 남깁니다.
///
/// Authorization 값은 원문을 남기지 않고 마스킹합니다.
class TmdbLoggingInterceptor extends Interceptor {
  /// 응답 Body가 길어 콘솔이 넘치지 않도록 앞부분만 남깁니다.
  static const _maxBodyLength = 500;

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
    final body = '${response.data}';
    debugPrint(
      '[TMDB 응답 Body] ${body.length > _maxBodyLength ? '${body.substring(0, _maxBodyLength)}…' : body}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[TMDB 오류] ${err.requestOptions.uri}');
    debugPrint(
      '[TMDB 오류 내용] ${err.response?.statusCode ?? '-'} ${err.type.name} ${err.message}',
    );
    handler.next(err);
  }
}

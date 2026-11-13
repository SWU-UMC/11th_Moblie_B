import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 요청/응답/에러 로그 찍는 인터셉터
/// Authorization은 마스킹해서 출력
class TmdbLoggingInterceptor extends Interceptor {
  /// 로그 앞에 붙일 태그 (워크북 API는 'MovieLog')
  TmdbLoggingInterceptor({this.tag = 'TMDB'});

  final String tag;

  /// 응답이 너무 길면 앞부분만 출력
  static const _maxBodyLength = 500;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }
    debugPrint('[$tag 요청] ${options.method} ${options.uri}');
    debugPrint('[$tag 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[$tag 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[$tag 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    final body = '${response.data}';
    debugPrint(
      '[$tag 응답 Body] ${body.length > _maxBodyLength ? '${body.substring(0, _maxBodyLength)}…' : body}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[$tag 오류] ${err.requestOptions.uri}');
    debugPrint(
      '[$tag 오류 내용] ${err.response?.statusCode ?? '-'} ${err.type.name} ${err.message}',
    );
    handler.next(err);
  }
}

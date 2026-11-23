import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// MovieLog API 요청/응답 로그입니다. Debug 빌드에서만 등록합니다.
///
/// 토큰과 비밀번호는 원문을 절대 남기지 않습니다.
/// - 요청 Header의 Authorization → `Bearer ***` (붙어 있는지만 확인합니다)
/// - 요청 body의 password, 응답 body의 accessToken → `***`
class MovieLogLoggingInterceptor extends Interceptor {
  MovieLogLoggingInterceptor({this.label = 'MovieLog'});

  /// 공개용/보호용 Client를 Console에서 구분하는 이름입니다.
  final String label;

  static const _secretKeys = {'password', 'accessToken'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasAuth = options.headers.containsKey('Authorization');
    debugPrint('[$label 요청] ${options.method} ${options.uri.path}');
    debugPrint(
      '[$label 요청 Header] Authorization: ${hasAuth ? 'Bearer ***' : '(없음)'}',
    );
    if (options.data != null) {
      debugPrint('[$label 요청 Body] ${maskSecrets(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[$label 응답] ${response.statusCode} ${response.requestOptions.uri.path}',
    );
    debugPrint('[$label 응답 Body] ${maskSecrets(response.data)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 서버 code(AUTH401_3 등)는 남기되 Header·토큰은 남기지 않습니다.
    debugPrint(
      '[$label 오류] ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.uri.path} ${maskSecrets(err.response?.data)}',
    );
    handler.next(err);
  }

  /// Map/List 안의 비밀 값을 `***`로 바꾼 사본을 돌려줍니다. 원본은 바꾸지 않습니다.
  @visibleForTesting
  static Object? maskSecrets(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _secretKeys.contains(entry.key)
              ? '***'
              : maskSecrets(entry.value),
      };
    }
    if (data is List) return data.map(maskSecrets).toList();
    return data;
  }
}

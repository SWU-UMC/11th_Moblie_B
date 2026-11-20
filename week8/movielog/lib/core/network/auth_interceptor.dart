import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 보호 API에만 MovieLog JWT 붙이는 Interceptor
/// 보호용 Dio에만 등록함 (공개용 Dio, TMDB Dio엔 안 붙임)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  static const protectedHost = 'workbook.devnoco.com';
  final TokenStorage _storage;

  /// host + path 둘 다 맞을 때만 보호 요청으로 봄
  /// 외부 이미지 URL, 다른 서버로 토큰 새는 것 막음
  static bool isProtected(Uri uri) {
    final path = uri.path;
    return uri.host == protectedHost &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 이전 요청 토큰 재사용 안 하게 먼저 지움
    options.headers.remove('Authorization');
    if (!isProtected(options.uri)) {
      handler.next(options);
      return;
    }
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 기기 저장소 실패는 서버 401이랑 다른 오류로 구분
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}

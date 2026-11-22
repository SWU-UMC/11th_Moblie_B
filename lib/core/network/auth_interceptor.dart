import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._sessionVersion);
  final TokenStorage _storage;
  final int Function() _sessionVersion;
  bool _isProtected(RequestOptions options) {
    final uri = options.uri;
    return uri.scheme == 'https' &&
        uri.host == 'workbook.devnoco.com' &&
        uri.port == 443 &&
        (uri.path == '/v7/members/me' ||
            uri.path == '/v7/ratings' ||
            RegExp(r'^/v7/ratings/[0-9]+$').hasMatch(uri.path));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.removeWhere(
      (key, value) => key.toLowerCase() == 'authorization',
    );
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }
    // A protected redirect must never forward the JWT to another host.
    options.followRedirects = false;
    final version = _sessionVersion();
    try {
      final token = await _storage.readAccessToken();
      if (version != _sessionVersion()) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: StateError('세션이 변경되었습니다.'),
          ),
        );
        return;
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// MovieLog 보호 요청에만 `Authorization: Bearer {MovieLog JWT}`를 붙입니다.
///
/// 보호용 Client(createAuthMovieLogClient)에만 등록합니다.
/// TMDB Client에는 절대 등록하지 않습니다. (TMDB Token과 MovieLog JWT를 섞지 않습니다.)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  static const host = 'workbook.devnoco.com';

  /// 내 정보와 평점 등록·수정·삭제만 보호 경로입니다.
  /// 유저별 평점 조회(`/v7/members/{memberId}/ratings`)는 공개 API라 여기에 없습니다.
  static bool isProtected(RequestOptions options) {
    final uri = options.uri;
    final path = uri.path;
    return uri.host == host &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isProtected(options)) {
      handler.next(options);
      return;
    }
    // 이전 요청이나 다른 Client의 토큰을 재사용하지 않도록 먼저 지웁니다.
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버 401과 기기 저장소 실패는 다른 오류입니다. 토큰 없이 보내지 않습니다.
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

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 보호 API에만 MovieLog JWT 붙이는 Interceptor
/// 보호용 Dio에만 등록함 (공개용 Dio, TMDB Dio엔 안 붙임)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  static const protectedHost = 'workbook.devnoco.com';
  final TokenStorage _storage;

  static final _favoriteMoviePath = RegExp(r'^/v8/favorites/[1-9]\d*$');

  /// host + path + method 다 맞을 때만 보호 요청으로 봄
  /// 외부 이미지 URL, 다른 서버로 토큰 새는 것 막음
  static bool isProtected(Uri uri, String method) {
    // MovieLog 서버 아니면(TMDB 등) 절대 안 붙임
    if (uri.host != protectedHost) return false;
    final path = uri.path;
    final upper = method.toUpperCase();

    // 8주차 보호 경로 (/v7 → /v8)
    final w8Protected =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');

    // 9주차 즐겨찾기: 등록(POST)·목록(GET) / 여부 조회(GET)·해제(DELETE)
    final favorites =
        (path == '/v8/favorites' && (upper == 'GET' || upper == 'POST')) ||
        (_favoriteMoviePath.hasMatch(path) &&
            (upper == 'GET' || upper == 'DELETE'));

    // Challenge: 평점 + 즐겨찾기 한 번에 저장
    final movieRecord = path == '/v8/movie-records' && upper == 'POST';

    return w8Protected || favorites || movieRecord;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 이전 요청 토큰 재사용 안 하게 먼저 지움
    options.headers.remove('Authorization');
    if (!isProtected(options.uri, options.method)) {
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

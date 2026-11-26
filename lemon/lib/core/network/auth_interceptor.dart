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

  static final _favoriteMoviePath = RegExp(r'^/v8/favorites/[1-9]\d*$');

  /// 보호 요청(JWT를 붙일 요청)인지 판단합니다.
  /// 유저별 평점 조회(`/v8/members/{memberId}/ratings`)·로그인·회원가입·중복 확인은
  /// 공개 API라 여기에 없습니다.
  static bool isProtected(RequestOptions options) {
    // MovieLog 서버가 아닌 곳(TMDB 등)에는 JWT를 붙이지 않습니다.
    if (options.uri.host != host) return false;
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    // 8주차의 보호 경로(/v7 → /v8): 내 정보, 평점 등록·수정·삭제
    final w8Protected =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');

    // 9주차 즐겨찾기: 등록(POST)·목록(GET) / 여부 조회(GET)·해제(DELETE)
    final favorites =
        (path == '/v8/favorites' && (method == 'GET' || method == 'POST')) ||
        (_favoriteMoviePath.hasMatch(path) &&
            (method == 'GET' || method == 'DELETE'));

    // 영화 기록 저장(Challenge에서만 사용)
    final movieRecord = path == '/v8/movie-records' && method == 'POST';

    return w8Protected || favorites || movieRecord;
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

import 'package:dio/dio.dart';

/// 워크북 자체 백엔드(MovieLog API) 전용 Dio Client입니다.
/// TMDB Client와 baseUrl·헤더가 다르므로 절대 하나로 합치지 않습니다.
/// TMDB Token(Authorization 헤더)을 이 Client에 넣지 않습니다.
///
/// 회원가입 요청에는 비밀번호가 들어가므로 요청 body를 찍는 LogInterceptor를 달지 않습니다.
Dio createMovieLogClient() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}

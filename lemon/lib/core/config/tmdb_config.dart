import 'package:flutter_dotenv/flutter_dotenv.dart';

/// `.env`에서 TMDB Token을 읽는 코드를 한 곳에 모읍니다.
abstract final class TmdbConfig {
  static String get accessToken => dotenv.env['TMDB_ACCESS_TOKEN'] ?? '';
}

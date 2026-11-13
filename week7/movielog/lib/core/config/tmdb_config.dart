import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TMDB 토큰은 .env에서만 읽음 (코드에 직접 안 씀)
abstract final class TmdbConfig {
  static const accessTokenKey = 'TMDB_ACCESS_TOKEN';

  /// .env 로드 전이거나 값 없으면 '' → 401 뜸
  static String get accessToken =>
      dotenv.isInitialized ? dotenv.env[accessTokenKey] ?? '' : '';
}

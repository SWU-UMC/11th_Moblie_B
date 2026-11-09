import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TMDB Token을 읽는 곳을 한 군데로 모읍니다. 값은 .env에만 두고 코드에 적지 않습니다.
abstract final class TmdbConfig {
  static const accessTokenKey = 'TMDB_ACCESS_TOKEN';

  /// .env를 아직 불러오지 않았거나 값이 없으면 빈 문자열 (요청은 401로 실패)
  static String get accessToken =>
      dotenv.isInitialized ? dotenv.env[accessTokenKey] ?? '' : '';
}

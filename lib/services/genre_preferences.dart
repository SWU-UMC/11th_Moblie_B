import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 선택한 장르를 기기에 저장합니다.
/// 민감하지 않은 단순 값만 저장하고, JWT·비밀번호는 여기에 두지 않습니다.
class GenrePreferences {
  GenrePreferences({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// TMDB 장르 ID를 저장합니다. 값이 없으면 "전체"입니다.
  static const lastGenreIdKey = 'last_selected_genre_id';

  final SharedPreferencesAsync _prefs;

  Future<int?> loadLastGenreId() => _prefs.getInt(lastGenreIdKey);

  Future<void> saveLastGenreId(int? genreId) => genreId == null
      ? _prefs.remove(lastGenreIdKey)
      : _prefs.setInt(lastGenreIdKey, genreId);
}

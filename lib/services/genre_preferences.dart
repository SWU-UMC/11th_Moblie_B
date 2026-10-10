import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 선택한 장르를 기기에 저장합니다.
/// 민감하지 않은 단순 값만 저장하고, JWT·비밀번호는 여기에 두지 않습니다.
class GenrePreferences {
  GenrePreferences({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const lastGenreKey = 'last_selected_genre';

  final SharedPreferencesAsync _prefs;

  Future<String?> loadLastGenre() => _prefs.getString(lastGenreKey);

  Future<void> saveLastGenre(String genre) =>
      _prefs.setString(lastGenreKey, genre);
}

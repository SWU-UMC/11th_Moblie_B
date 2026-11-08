import 'package:shared_preferences/shared_preferences.dart';

class GenrePreference {
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const selectedGenreKey = 'selected_genre';
  final SharedPreferencesAsync _preferences;

  Future<String> read() async {
    return await _preferences.getString(selectedGenreKey) ?? '전체';
  }

  Future<void> save(String genre) async {
    // 단순 설정인 장르만 저장합니다. 계정 정보와 영화 객체는 저장하지 않습니다.
    await _preferences.setString(selectedGenreKey, genre);
  }
}

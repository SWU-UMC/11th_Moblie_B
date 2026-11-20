import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie_sort.dart';

/// 장르·정렬 같은 간단한 설정 로컬 저장용
/// (shared_preferences라 민감한 값은 저장 X)
class MoviePreferences {
  MoviePreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// 5주차부터 장르 이름 말고 TMDB id로 저장
  static const selectedGenreIdsKey = 'selected_genre_ids';
  static const sortKey = 'movie_sort';

  /// 8주차 Challenge: 로그인 이메일 저장
  /// 이메일만 저장 (비밀번호·토큰은 여기 절대 안 넣음)
  static const savedEmailKey = 'saved_login_email';

  final SharedPreferencesAsync _preferences;

  /// 없으면 [] = 전체
  Future<List<int>> readGenreIds() async {
    final saved = await _preferences.getStringList(selectedGenreIdsKey);
    return [...?saved?.map(int.tryParse).whereType<int>()];
  }

  Future<void> saveGenreIds(List<int> genreIds) async {
    if (genreIds.isEmpty) {
      await _preferences.remove(selectedGenreIdsKey);
      return;
    }
    await _preferences.setStringList(
      selectedGenreIdsKey,
      genreIds.map((id) => '$id').toList(),
    );
  }

  Future<MovieSort> readSort() async {
    return MovieSort.fromName(await _preferences.getString(sortKey));
  }

  Future<void> saveSort(MovieSort sort) async {
    await _preferences.setString(sortKey, sort.name);
  }

  /// 저장한 이메일 없으면 null
  Future<String?> readSavedEmail() => _preferences.getString(savedEmailKey);

  Future<void> saveEmail(String email) =>
      _preferences.setString(savedEmailKey, email.trim());

  Future<void> clearSavedEmail() => _preferences.remove(savedEmailKey);
}

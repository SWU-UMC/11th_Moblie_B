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
}

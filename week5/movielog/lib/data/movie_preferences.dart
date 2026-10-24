import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie_sort.dart';

/// 영화 목록 화면의 간단한 설정값을 로컬에 저장합니다.
///
/// shared_preferences는 보안 저장소가 아니므로 마지막 선택 장르, 정렬 방식처럼
/// 중요하지 않은 값만 저장합니다. (토큰·비밀번호는 flutter_secure_storage)
class MoviePreferences {
  MoviePreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// 5주차부터 장르 이름 대신 TMDB 장르 id를 저장합니다.
  static const selectedGenreIdsKey = 'selected_genre_ids';
  static const sortKey = 'movie_sort';

  final SharedPreferencesAsync _preferences;

  /// 저장된 장르가 없으면 빈 List(= 전체)
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

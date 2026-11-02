import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie_sort.dart';

/// 영화 목록 화면의 간단한 설정값을 로컬에 저장합니다.
///
/// shared_preferences는 보안 저장소가 아니므로 마지막 선택 장르, 정렬 방식처럼
/// 중요하지 않은 값만 저장합니다. (토큰·비밀번호는 flutter_secure_storage)
class MoviePreferences {
  MoviePreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const selectedGenresKey = 'selected_genres';
  static const sortKey = 'movie_sort';

  final SharedPreferencesAsync _preferences;

  /// 저장된 장르가 없으면 빈 Set(= 전체)
  Future<Set<String>> readGenres() async {
    final genres = await _preferences.getStringList(selectedGenresKey);
    return {...?genres};
  }

  Future<void> saveGenres(Set<String> genres) async {
    if (genres.isEmpty) {
      await _preferences.remove(selectedGenresKey);
      return;
    }
    await _preferences.setStringList(selectedGenresKey, genres.toList());
  }

  Future<MovieSort> readSort() async {
    return MovieSort.fromName(await _preferences.getString(sortKey));
  }

  Future<void> saveSort(MovieSort sort) async {
    await _preferences.setString(sortKey, sort.name);
  }
}

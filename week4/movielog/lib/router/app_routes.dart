/// 앱에서 사용하는 Route 경로
abstract final class AppRoutes {
  static const start = '/start';
  static const register = '/register';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// 영화 상세: /movies/:movieId
  static const movieDetail = '/movies/:movieId';
  static const movieIdParam = 'movieId';
  static String movieDetailOf(int movieId) => '/movies/$movieId';

  /// 영화 목록 장르 필터 Query Parameter: /movies?genre=드라마,SF
  static const genreQueryKey = 'genre';

  static String moviesWithGenres(Set<String> genres) {
    if (genres.isEmpty) return movies;
    return Uri(
      path: movies,
      queryParameters: {genreQueryKey: genres.join(',')},
    ).toString();
  }

  static Set<String> genresFromQuery(Map<String, String> queryParameters) {
    final raw = queryParameters[genreQueryKey];
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((genre) => genre.isNotEmpty).toSet();
  }
}

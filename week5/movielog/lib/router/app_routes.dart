/// 앱에서 사용하는 Route 경로
abstract final class AppRoutes {
  static const start = '/start';
  static const register = '/register';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// 영화 상세: /movies/:movieId (TMDB 영화 id)
  static const movieDetail = '/movies/:movieId';
  static const movieIdParam = 'movieId';
  static String movieDetailOf(int movieId) => '/movies/$movieId';
}

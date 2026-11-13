/// 라우트 경로
abstract final class AppRoutes {
  static const start = '/start';
  static const register = '/register';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// 내가 등록한 평점 (/my/ratings)
  static const myRatingsSegment = 'ratings';
  static const myRatings = '/my/ratings';

  /// 영화 상세 /movies/:movieId
  static const movieDetail = '/movies/:movieId';
  static const movieIdParam = 'movieId';
  static String movieDetailOf(int movieId) => '/movies/$movieId';
}

/// 라우트 경로
abstract final class AppRoutes {
  static const start = '/start';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const movies = '/movies';
  static const my = '/my';

  /// 내가 등록한 평점 (/my/ratings)
  static const myRatingsSegment = 'ratings';
  static const myRatings = '/my/ratings';

  /// 프로필 수정 (/my/profile/edit)
  static const profileEditSegment = 'profile/edit';
  static const profileEdit = '/my/profile/edit';

  /// 9주차 내 즐겨찾기 (/my/favorites)
  static const myFavoritesSegment = 'favorites';
  static const myFavorites = '/my/favorites';

  /// 9주차 영화 검색 (/movies/search)
  /// :movieId보다 먼저 등록해야 search가 영화 id로 안 읽힘
  static const movieSearch = '/movies/search';

  /// 영화 상세 /movies/:movieId
  static const movieDetail = '/movies/:movieId';
  static const movieIdParam = 'movieId';
  static String movieDetailOf(int movieId) => '/movies/$movieId';
}

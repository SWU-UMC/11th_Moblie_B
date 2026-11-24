import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

/// 내 즐겨찾기 카드 한 장 = MovieLog 즐겨찾기 + TMDB 영화 정보
/// movie null이면 TMDB 조회 실패 → placeholder + 그 카드만 재조회
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
    this.isRetrying = false,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  /// 이 카드만 TMDB 다시 부르는 중
  final bool isRetrying;

  bool get hasMovie => movie != null;
}

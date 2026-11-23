import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

/// 내 즐겨찾기 카드 하나입니다. MovieLog 즐겨찾기와 TMDB 영화 정보를 movieId로 합칩니다.
/// [movie]가 null이면 TMDB 조회에 실패한 카드라 placeholder와 재조회 버튼을 보여줍니다.
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  bool get hasMovie => movie != null;
}

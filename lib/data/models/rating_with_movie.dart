import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 평점 한 건과 그 movieId로 TMDB에서 찾은 영화를 한 쌍으로 묶습니다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB에서 찾지 못했거나 불러오지 못했으면 null입니다.
  /// 이때도 평점은 그대로 보여주고 제목·포스터만 placeholder로 표시합니다.
  final TmdbMovieDto? movie;
}

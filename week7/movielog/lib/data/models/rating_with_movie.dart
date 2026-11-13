import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 평점 + 해당 영화 TMDB 정보
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB에 없는 영화면 null
  final TmdbMovieDto? movie;
}

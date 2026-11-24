import 'favorite_response_dto.dart';
import 'rating_dto.dart';

/// Challenge: POST /v8/movie-records 요청 body
/// 평점 + 즐겨찾기를 서버가 한 트랜잭션으로 저장 (하나라도 실패하면 둘 다 안 됨)
class CreateMovieRecordRequest {
  const CreateMovieRecordRequest({
    required this.movieId,
    required this.score,
    required this.addToFavorites,
    this.comment,
  });

  /// TMDB 영화 id
  final int movieId;

  /// 1~5 정수
  final int score;
  final String? comment;

  /// 필수 boolean (false면 응답 favorite null이 정상)
  final bool addToFavorites;

  Map<String, dynamic> toJson() {
    final trimmed = comment?.trim();
    return {
      'movieId': movieId,
      'score': score,
      if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      'addToFavorites': addToFavorites,
    };
  }
}

/// 201 result {rating, favorite}
/// rating은 7주차 RatingDto, favorite은 FavoriteResponseDto 재사용
class MovieRecordResult {
  const MovieRecordResult({required this.rating, this.favorite});

  factory MovieRecordResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('MovieRecordResult는 JSON 객체여야 함');
    }
    final rawFavorite = json['favorite'];
    return MovieRecordResult(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: rawFavorite == null
          ? null
          : FavoriteResponseDto.fromJson(rawFavorite),
    );
  }

  final RatingDto rating;

  /// addToFavorites false면 null
  final FavoriteResponseDto? favorite;
}

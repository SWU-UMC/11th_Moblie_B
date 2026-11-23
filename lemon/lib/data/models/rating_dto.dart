/// 평점 한 건입니다. 유저별 평점 조회의 배열 원소이자,
/// v8 등록·수정 응답의 result입니다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  final int ratingId;

  /// TMDB 영화 id입니다.
  final int movieId;
  final int score;

  /// 후기는 nullable이므로 값이 없을 수 있습니다.
  final String? comment;
  final DateTime createdAt;

  /// v7에서 추가된 마지막 수정 시각입니다. v6 응답처럼 없으면 null입니다.
  final DateTime? updatedAt;

  factory RatingDto.fromJson(Map<String, dynamic> json) => RatingDto(
    ratingId: (json['ratingId'] as num).toInt(),
    movieId: (json['movieId'] as num).toInt(),
    score: (json['score'] as num).toInt(),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: switch (json['updatedAt']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}

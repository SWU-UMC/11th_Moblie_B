/// 즐겨찾기 하나 (등록 result / 내 목록 배열 원소)
/// 제목·포스터 없음 → movieId로 TMDB에서 따로 가져와 합침
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('FavoriteResponseDto는 JSON 객체여야 함');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;

  /// TMDB 영화 id (해제·여부 조회 path에도 이 값 씀)
  final int movieId;
  final DateTime createdAt;
}

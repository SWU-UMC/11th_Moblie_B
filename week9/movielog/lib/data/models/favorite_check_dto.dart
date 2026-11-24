/// GET /v8/favorites/{movieId} result
/// 응답엔 isFavorite만 있고 movieId 없음 → 요청한 movieId를 따로 넘겨받음
class FavoriteCheckDto {
  const FavoriteCheckDto({required this.movieId, required this.isFavorite});

  factory FavoriteCheckDto.fromJson(Object? json, {required int movieId}) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('FavoriteCheckDto는 JSON 객체여야 함');
    }
    final value = json['isFavorite'];
    if (value is! bool) {
      throw const FormatException('isFavorite는 bool이어야 함');
    }
    return FavoriteCheckDto(movieId: movieId, isFavorite: value);
  }

  final int movieId;
  final bool isFavorite;
}

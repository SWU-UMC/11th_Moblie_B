/// MovieLog에서 다루는 영화 한 편의 정보 (Mock Data)
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtimeMinutes,
    required this.averageRating,
    required this.ratingCount,
    required this.posterAsset,
    required this.synopsis,
  });

  final int id;
  final String title;

  /// 첫 번째 장르가 대표 장르입니다.
  final List<String> genres;
  final int year;
  final int runtimeMinutes;

  /// 5점 만점 평균 평점
  final double averageRating;
  final int ratingCount;
  final String posterAsset;
  final String synopsis;

  String get mainGenre => genres.first;
}

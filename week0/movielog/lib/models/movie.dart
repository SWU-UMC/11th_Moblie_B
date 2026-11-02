/// MovieLog에서 다루는 영화 한 편의 정보
class Movie {
  const Movie({
    required this.title,
    required this.year,
    this.rating,
  });

  final String title;
  final int year;

  /// 아직 평점을 남기지 않은 영화는 null
  final double? rating;

  @override
  String toString() => '$title ($year)';
}

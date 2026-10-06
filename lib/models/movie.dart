class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtimeMinutes,
    required this.posterPath,
    required this.rating,
    required this.reviewCount,
    this.tags = const [],
    this.synopsis = '',
  });

  final String id;
  final String title;
  final List<String> genres;
  final int year;
  final int runtimeMinutes;
  final String posterPath;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String synopsis;
}

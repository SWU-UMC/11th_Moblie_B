/// TMDB 영화 한 편 (Popular·Discover의 results 항목, 또는 /movie/{id} 상세 응답)
class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.genreIds,
    required this.voteAverage,
    required this.popularity,
    this.voteCount = 0,
    this.runtime,
  });

  /// TMDB 영화 id. 평점 저장 때 MovieLog API의 movieId로 그대로 사용합니다.
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final List<int> genreIds;

  /// 10점 만점 평균 평점
  final double voteAverage;
  final double popularity;
  final int voteCount;

  /// 상세 응답에만 있는 상영 시간(분)
  final int? runtime;

  /// "2024-05-01" → "2024", 날짜가 없으면 null
  String? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return date.substring(0, 4);
  }

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    // 목록 응답은 genre_ids, 상세 응답은 genres([{id, name}])로 장르를 줍니다.
    final rawGenreIds = json['genre_ids'] as List<dynamic>?;
    final rawGenres = json['genres'] as List<dynamic>?;
    final genreIds = rawGenreIds != null
        ? rawGenreIds.map((value) => (value as num).toInt()).toList()
        : (rawGenres ?? const [])
              .map(
                (genre) =>
                    ((genre as Map<String, dynamic>)['id'] as num).toInt(),
              )
              .toList();

    return TmdbMovieDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '제목 없음',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      genreIds: genreIds,
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
      popularity: (json['popularity'] as num? ?? 0).toDouble(),
      voteCount: (json['vote_count'] as num? ?? 0).toInt(),
      runtime: (json['runtime'] as num?)?.toInt(),
    );
  }
}

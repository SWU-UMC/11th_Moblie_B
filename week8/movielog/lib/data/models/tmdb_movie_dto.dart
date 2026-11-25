/// TMDB 영화 (목록 results / 상세 응답 둘 다 이걸로 파싱)
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

  /// 평점 API movieId로도 이 값 그대로 씀
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final List<int> genreIds;

  /// 10점 만점
  final double voteAverage;
  final double popularity;
  final int voteCount;

  /// 러닝타임(분), 상세 응답에만 있음
  final int? runtime;

  /// release_date에서 연도만 (없으면 null)
  String? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return date.substring(0, 4);
  }

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    // 목록은 genre_ids, 상세는 genres로 와서 둘 다 처리
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

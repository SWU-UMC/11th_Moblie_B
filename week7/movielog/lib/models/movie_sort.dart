import '../data/models/tmdb_movie_dto.dart';

/// 정렬 방식 (불러온 30개 안에서 정렬, 로컬에 저장)
enum MovieSort {
  popularity('인기순'),
  rating('평점순'),
  latest('최신순'),
  title('제목순');

  const MovieSort(this.label);

  final String label;

  List<TmdbMovieDto> apply(List<TmdbMovieDto> movies) {
    final sorted = [...movies];
    switch (this) {
      case MovieSort.popularity:
        sorted.sort((a, b) => b.popularity.compareTo(a.popularity));
      case MovieSort.rating:
        sorted.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
      case MovieSort.latest:
        sorted.sort(
          (a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''),
        );
      case MovieSort.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
    }
    return sorted;
  }

  /// 저장된 문자열 → enum, 모르는 값이면 인기순
  static MovieSort fromName(String? name) => MovieSort.values.firstWhere(
    (sort) => sort.name == name,
    orElse: () => MovieSort.popularity,
  );
}

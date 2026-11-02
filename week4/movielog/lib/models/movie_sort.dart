import 'movie.dart';

/// 영화 목록 정렬 방식 (로컬에 저장해 다음 실행 때 복원)
enum MovieSort {
  rating('평점순'),
  latest('최신순'),
  title('제목순');

  const MovieSort(this.label);

  final String label;

  List<Movie> apply(List<Movie> movies) {
    final sorted = [...movies];
    switch (this) {
      case MovieSort.rating:
        sorted.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case MovieSort.latest:
        sorted.sort((a, b) => b.year.compareTo(a.year));
      case MovieSort.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
    }
    return sorted;
  }

  /// 저장된 문자열을 다시 enum으로. 모르는 값이면 기본값(평점순)
  static MovieSort fromName(String? name) => MovieSort.values.firstWhere(
    (sort) => sort.name == name,
    orElse: () => MovieSort.rating,
  );
}

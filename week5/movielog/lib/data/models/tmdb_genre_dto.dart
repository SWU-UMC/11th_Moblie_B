/// TMDB 공식 장르 ({id, name}). 장르 이름을 직접 정하지 않고 Genre API 값을 씁니다.
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

import 'movie.dart';

// 연습 4: nullable 닉네임을 안전한 기본값으로
String displayName(String? nickname) {
  final trimmed = nickname?.trim();
  if (trimmed == null || trimmed.isEmpty) return '이름 없음';
  return trimmed;
}

void main() {
  // 연습 2: 영화 3개를 List<Movie>에 담기
  final movies = <Movie>[
    const Movie(
      id: 1,
      title: '별빛 아래 우리',
      genre: '드라마',
      year: 2024,
      posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
      minutes: 124,
      averageRating: 4.5,
      synopsis: '작은 천문대에서 만난 두 사람이 서로의 상처를 치유하는 이야기.',
    ),
    const Movie(
      id: 2,
      title: '우주의 끝에서',
      genre: 'SF',
      year: 2024,
      posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
      minutes: 118,
      averageRating: 4.2,
      synopsis: '미지의 행성에서 들려온 신호를 따라가는 탐사대의 이야기.',
    ),
    const Movie(
      id: 3,
      title: '새로운 영화',
      genre: '애니메이션',
      year: 2023,
      posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
      minutes: 102,
      averageRating: 4.9,
      synopsis: '연습용 영화 소개.',
    ),
  ];

  // 연습 3: for로 출력
  for (final movie in movies) {
    print(movie.title);
  }

  // 연습 3: map으로 출력
  movies.map((m) => m.title).forEach(print);

  // 연습 4: nullable 닉네임 처리
  String? nickname;
  print(displayName(nickname)); // 이름 없음
  print(displayName('  무비러버  ')); // 무비러버
}
import '../movie.dart';

// 연습 4: nullable 닉네임을 안전한 기본값으로
String displayName(String? nickname) {
  final trimmed = nickname?.trim();
  if (trimmed == null || trimmed.isEmpty) return '이름 없음';
  return trimmed;
}

void main() {
  // 연습 2: 영화 3개를 List<Movie>에 담기
  final movies = <Movie>[
    const Movie(id: 1, title: '별빛 아래 우리'),
    const Movie(id: 2, title: '우주의 끝에서'),
    const Movie(id: 3, title: '새로운 영화'),
  ];

  // 연습 3: for로 출력
  for (final movie in movies) {
    print(movie.title);
  }

  // 연습 3: map으로 출력
  movies.map((m) => m.title).forEach(print);

  // 연습 4: nullable 닉네임 처리
  String? nickname;
  print(displayName(nickname));       // 이름 없음
  print(displayName('  무비러버  ')); // 무비러버
}
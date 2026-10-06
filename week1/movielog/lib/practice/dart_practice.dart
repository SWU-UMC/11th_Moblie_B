// Mission 2. Dart 연습
// 실행: dart run lib/practice/dart_practice.dart
// ignore_for_file: avoid_print

import 'package:movielog/models/movie.dart';

/// nullable 닉네임을 안전한 기본값으로 변환한다.
/// null이거나 공백뿐이면 '게스트'를 돌려준다.
String safeNickname(String? nickname) {
  final trimmed = nickname?.trim();
  return (trimmed == null || trimmed.isEmpty) ? '게스트' : trimmed;
}

void main() {
  // 영화 3개를 List<Movie>에 담는다.
  final List<Movie> movies = [
    const Movie(title: '별빛 아래 우리', year: 2024, rating: 4.5),
    const Movie(title: '우주의 끝에서', year: 2023),
    const Movie(title: '네 번째 오후', year: 2025, rating: 3.8),
  ];

  // for로 영화 제목 출력
  print('--- for ---');
  for (final movie in movies) {
    print(movie.title);
  }

  // map으로 영화 제목 출력
  print('--- map ---');
  final titles = movies.map((movie) => movie.title).toList();
  print(titles.join(', '));

  // nullable 평점은 ??로 기본 문구를 준다.
  print('--- 평점 ---');
  for (final movie in movies) {
    print('$movie: ${movie.rating?.toString() ?? '평점 없음'}');
  }

  // nullable 닉네임을 안전한 기본값으로 변환
  print('--- 닉네임 ---');
  String? nickname;
  print(safeNickname(nickname)); // 게스트
  print(safeNickname('   ')); // 게스트
  print(safeNickname(' 제로 ')); // 제로
}

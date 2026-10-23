import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/services/fake_movie_service.dart';

void main() {
  const service = FakeMovieService(
    delay: Duration.zero,
    slowDelay: Duration.zero,
  );

  test('성공 모드는 Mock 영화 목록을 반환한다', () async {
    expect(await service.fetchMovies(), movies);
  });

  test('빈 목록 모드는 빈 List를 반환한다', () async {
    expect(await service.fetchMovies(mode: MovieLoadMode.empty), isEmpty);
  });

  test('실패 모드는 MovieLoadException으로 완료된다', () async {
    expect(
      service.fetchMovies(mode: MovieLoadMode.failure),
      throwsA(isA<MovieLoadException>()),
    );
  });

  test('기본 지연 시간은 Loading이 보이도록 800ms 이상이다', () {
    expect(
      const FakeMovieService().delay,
      greaterThanOrEqualTo(const Duration(milliseconds: 800)),
    );
  });
}

import '../data/mock_movies.dart';
import '../models/movie.dart';

/// Mock 응답 종류. 화면 상태(Success·Empty·Error·Timeout)를 확인할 때 바꿔 씁니다.
enum MovieLoadMode {
  success('성공'),
  empty('빈 목록'),
  failure('실패'),
  slow('응답 지연');

  const MovieLoadMode(this.label);

  final String label;
}

/// 영화 목록을 불러오지 못했을 때의 오류. 화면에는 [message]만 사용합니다.
class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

/// 실제 API 대신 Future.delayed로 결과를 늦게 돌려주는 Mock Service.
///
/// 화면은 이 Service가 내부에서 무엇을 하는지 모르고 Future만 기다립니다.
// TODO(5주차 유저별 평점 조회 API): 같은 fetchMovies 호출 경계를 유지한 채 실제 API Service로 교체
class FakeMovieService {
  const FakeMovieService({
    this.delay = const Duration(seconds: 1),
    this.slowDelay = const Duration(seconds: 10),
  });

  /// Loading 화면이 보이는 시간 (최소 800ms 이상)
  final Duration delay;

  /// [MovieLoadMode.slow]일 때의 지연 시간 (Timeout 확인용)
  final Duration slowDelay;

  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    await Future<void>.delayed(mode == MovieLoadMode.slow ? slowDelay : delay);

    return switch (mode) {
      MovieLoadMode.success || MovieLoadMode.slow => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}

import '../data/mock_movies.dart';
import '../models/movie.dart';

/// FakeMovieService가 어떤 결과로 끝날지 정하는 모드입니다.
enum MovieLoadMode {
  /// Mock 영화 목록을 반환합니다.
  success,

  /// 빈 목록을 반환합니다.
  empty,

  /// 항상 Exception으로 끝납니다.
  error,

  /// 첫 호출만 실패하고, 재시도부터는 성공합니다.
  errorOnce;

  /// `--dart-define=MOVIE_LOAD_MODE=empty`처럼 실행 시 모드를 고를 수 있습니다.
  static MovieLoadMode fromEnvironment() {
    const name = String.fromEnvironment('MOVIE_LOAD_MODE');
    return values.asNameMap()[name] ?? success;
  }
}

/// 실제 서버 대신 Mock 영화 목록을 비동기로 돌려주는 Service입니다.
class FakeMovieService {
  FakeMovieService({MovieLoadMode? mode})
    : mode = mode ?? MovieLoadMode.fromEnvironment();

  final MovieLoadMode mode;
  int _callCount = 0;

  // TODO(5주차 유저별 평점 조회 API): 같은 호출 경계로 실제 API Service에 교체합니다.
  Future<List<Movie>> fetchMovies() async {
    _callCount++;
    // 네트워크 요청처럼 보이도록 1초 지연합니다. (Loading 최소 800ms)
    await Future.delayed(const Duration(seconds: 1));

    switch (mode) {
      case MovieLoadMode.success:
        return mockMovies;
      case MovieLoadMode.empty:
        return [];
      case MovieLoadMode.error:
        throw Exception('FakeMovieService: 영화 목록 요청 실패');
      case MovieLoadMode.errorOnce:
        if (_callCount == 1) {
          throw Exception('FakeMovieService: 첫 요청 실패');
        }
        return mockMovies;
    }
  }
}

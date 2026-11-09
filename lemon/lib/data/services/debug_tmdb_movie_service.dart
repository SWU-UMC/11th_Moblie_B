import 'package:dio/dio.dart';

import '../models/tmdb_movie_dto.dart';
import '../models/tmdb_movie_page.dart';
import 'tmdb_movie_service.dart';

/// 영화 목록 요청이 어떤 결과로 끝날지 정하는 모드입니다.
/// 실제 TMDB는 거의 항상 성공하므로 Empty/Error 화면 확인에 사용합니다.
enum MovieLoadMode {
  /// 실제 TMDB 응답을 그대로 사용합니다.
  success,

  /// 영화 목록을 빈 결과로 돌려줍니다.
  empty,

  /// 영화 목록 요청이 항상 실패합니다.
  error,

  /// 첫 요청만 실패하고, 재시도부터는 실제 응답을 사용합니다.
  errorOnce,

  /// 실제 응답에서 첫 번째 영화의 poster_path만 null로 바꿉니다.
  noPoster;

  /// `--dart-define=MOVIE_LOAD_MODE=empty`처럼 실행 시 모드를 고를 수 있습니다.
  /// 값이 없으면 success를 쓰고, 오타처럼 알 수 없는 값이면 바로 알려줍니다.
  static MovieLoadMode fromEnvironment() {
    const name = String.fromEnvironment('MOVIE_LOAD_MODE');
    if (name.isEmpty) return success;

    final mode = values.asNameMap()[name];
    if (mode == null) {
      throw ArgumentError.value(
        name,
        'MOVIE_LOAD_MODE',
        '${values.map((mode) => mode.name).join(', ')} 중 하나여야 합니다',
      );
    }
    return mode;
  }
}

/// Popular/Discover 결과만 모드에 맞게 바꾸는 개발용 Service입니다.
/// 장르 목록은 항상 실제 TMDB 응답을 사용합니다.
class DebugTmdbMovieService extends TmdbMovieService {
  DebugTmdbMovieService(super.dio, {required this.mode});

  final MovieLoadMode mode;
  final _failedOnce = <String>{};

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) =>
      _apply('/movie/popular', () => super.fetchPopular(page: page));

  @override
  Future<TmdbMoviePageDto> discoverMovies({required int page, int? genreId}) =>
      _apply(
        '/discover/movie',
        () => super.discoverMovies(page: page, genreId: genreId),
      );

  Future<TmdbMoviePageDto> _apply(
    String path,
    Future<TmdbMoviePageDto> Function() request,
  ) async {
    switch (mode) {
      case MovieLoadMode.success:
        return request();
      case MovieLoadMode.empty:
        // Loading 화면이 보이도록 네트워크 요청처럼 잠시 기다립니다.
        await Future<void>.delayed(const Duration(seconds: 1));
        return const TmdbMoviePageDto(
          page: 1,
          results: [],
          totalPages: 1,
          totalResults: 0,
        );
      case MovieLoadMode.error:
        await Future<void>.delayed(const Duration(seconds: 1));
        throw _fakeError(path);
      case MovieLoadMode.errorOnce:
        if (_failedOnce.add(path)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          throw _fakeError(path);
        }
        return request();
      case MovieLoadMode.noPoster:
        return _withoutFirstPoster(await request());
    }
  }

  TmdbMoviePageDto _withoutFirstPoster(TmdbMoviePageDto page) {
    if (page.page != 1 || page.results.isEmpty) return page;
    final first = page.results.first;
    final noPoster = TmdbMovieDto(
      id: first.id,
      title: first.title,
      overview: first.overview,
      posterPath: null,
      backdropPath: first.backdropPath,
      releaseDate: first.releaseDate,
      genreIds: first.genreIds,
      voteAverage: first.voteAverage,
      popularity: first.popularity,
    );
    return TmdbMoviePageDto(
      page: page.page,
      results: [noPoster, ...page.results.skip(1)],
      totalPages: page.totalPages,
      totalResults: page.totalResults,
    );
  }

  DioException _fakeError(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    message: 'MOVIE_LOAD_MODE=${mode.name}: 일부러 실패시킨 요청',
  );
}

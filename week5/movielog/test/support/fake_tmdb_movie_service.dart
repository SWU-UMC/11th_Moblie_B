import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

const actionGenre = TmdbGenreDto(id: 28, name: '액션');
const dramaGenre = TmdbGenreDto(id: 18, name: '드라마');
const sfGenre = TmdbGenreDto(id: 878, name: 'SF');

TmdbMovieDto fakeMovie(int id, {List<int> genreIds = const [18]}) =>
    TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '영화 $id 줄거리',
      // 테스트에서는 네트워크 이미지를 쓰지 않도록 null (placeholder 표시)
      posterPath: null,
      backdropPath: null,
      releaseDate: '2024-01-${(id % 28 + 1).toString().padLeft(2, '0')}',
      genreIds: genreIds,
      voteAverage: 7.5,
      popularity: 1000.0 - id,
    );

DioException fakeNetworkError(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
  message: 'Connection failed',
);

/// 실제 TMDB 대신 미리 만든 영화로 응답하는 Service.
///
/// 영화 1~45 중 짝수 id는 액션(28), 홀수 id는 드라마(18), 5의 배수는 SF(878)도 포함.
class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    this.popularCount = 20,
    this.poolSize = 45,
    this.pageSize = 20,
    this.overlapBetweenPages = false,
  }) : super(Dio());

  final int popularCount;
  final int poolSize;
  final int pageSize;

  /// true면 다음 페이지 첫 영화가 이전 페이지 마지막 영화와 같습니다(중복 제거 확인용).
  final bool overlapBetweenPages;

  bool failPopular = false;
  bool failDiscover = false;
  bool failGenres = false;
  bool failDetail = false;

  /// null이 아니면 discover 응답을 이 Completer가 끝날 때까지 늦춥니다.
  Completer<void>? discoverGate;

  final discoverCalls = <({int page, List<int>? genreIds})>[];
  int genreCalls = 0;

  late final List<TmdbMovieDto> pool = [
    for (var id = 1; id <= poolSize; id++)
      fakeMovie(id, genreIds: [id.isEven ? 28 : 18, if (id % 5 == 0) 878]),
  ];

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    if (failPopular) throw fakeNetworkError('/movie/popular');
    final results = pool.take(popularCount).toList();
    return TmdbMoviePageDto(
      page: 1,
      results: results,
      totalPages: 1,
      totalResults: results.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    discoverCalls.add((page: page, genreIds: genreIds));
    final gate = discoverGate;
    if (gate != null) await gate.future;
    if (failDiscover) throw fakeNetworkError('/discover/movie');

    final matched = genreIds == null || genreIds.isEmpty
        ? pool
        : pool.where((m) => m.genreIds.any(genreIds.contains)).toList();
    final totalPages = (matched.length / pageSize).ceil();
    var start = (page - 1) * pageSize;
    if (overlapBetweenPages && page > 1) start -= 1;
    final results = matched.skip(start).take(pageSize).toList();

    return TmdbMoviePageDto(
      page: page,
      results: results,
      totalPages: totalPages,
      totalResults: matched.length,
    );
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genreCalls++;
    if (failGenres) throw fakeNetworkError('/genre/movie/list');
    return const [actionGenre, dramaGenre, sfGenre];
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    if (failDetail) throw fakeNetworkError('/movie/$movieId');
    for (final movie in pool) {
      if (movie.id == movieId) return movie;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/movie/$movieId'),
      response: Response(
        requestOptions: RequestOptions(path: '/movie/$movieId'),
        statusCode: 404,
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

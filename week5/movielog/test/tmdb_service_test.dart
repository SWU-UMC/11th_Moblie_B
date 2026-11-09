import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/tmdb_logging_interceptor.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

/// 실제 네트워크 대신 요청을 기록하고 정해진 JSON으로 응답하는 Adapter
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final Map<String, dynamic> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _page(List<Map<String, dynamic>> results) => {
  'page': 1,
  'results': results,
  'total_pages': 3,
  'total_results': 60,
};

void main() {
  late _RecordingAdapter adapter;
  late TmdbMovieService service;

  setUp(() {
    adapter = _RecordingAdapter((options) {
      if (options.path == '/genre/movie/list') {
        return {
          'genres': [
            {'id': 28, 'name': '액션'},
            {'id': 18, 'name': '드라마'},
          ],
        };
      }
      return _page([
        {
          'id': 550,
          'title': '파이트 클럽',
          'poster_path': null,
          'genre_ids': [18],
          'vote_average': 8.4,
          'popularity': 120.5,
        },
      ]);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'))
      ..httpClientAdapter = adapter;
    service = TmdbMovieService(dio);
  });

  test('Discover에 여러 장르를 보내면 with_genres를 |(OR)로 연결한다', () async {
    await service.discoverMovies(page: 2, genreIds: [28, 12]);

    final query = adapter.requests.single.queryParameters;
    expect(adapter.requests.single.path, '/discover/movie');
    expect(query['with_genres'], '28|12');
    expect(query['page'], 2);
    expect(query['language'], 'ko-KR');
    expect(query['sort_by'], 'popularity.desc');
    expect(query['include_adult'], false);
  });

  test('"전체"(장르 없음)는 with_genres를 보내지 않는다', () async {
    await service.discoverMovies(page: 1, genreIds: const []);
    await service.discoverMovies(page: 1);

    for (final request in adapter.requests) {
      expect(request.queryParameters.containsKey('with_genres'), isFalse);
    }
  });

  test('Popular 응답을 페이지 DTO로 바꾸고 poster_path null을 그대로 둔다', () async {
    final page = await service.fetchPopular();

    expect(adapter.requests.single.path, '/movie/popular');
    expect(page.totalPages, 3);
    expect(page.results.single.id, 550);
    expect(page.results.single.posterPath, isNull);
    expect(page.results.single.voteAverage, 8.4);
  });

  test('Genre API는 language=ko로 요청하고 id·name을 그대로 쓴다', () async {
    final genres = await service.fetchGenres();

    expect(adapter.requests.single.queryParameters['language'], 'ko');
    expect(genres.map((g) => (g.id, g.name)), [(28, '액션'), (18, '드라마')]);
  });

  test('상세 응답의 genres([{id,name}])도 genreIds로 바꾼다', () {
    final movie = TmdbMovieDto.fromJson({
      'id': 1,
      'title': '상세',
      'genres': [
        {'id': 28, 'name': '액션'},
        {'id': 12, 'name': '모험'},
      ],
      'runtime': 124,
      'release_date': '2024-05-01',
    });

    expect(movie.genreIds, [28, 12]);
    expect(movie.runtime, 124);
    expect(movie.releaseYear, '2024');
    expect(movie.voteAverage, 0);
  });

  test('로그 Interceptor는 Authorization 원문을 남기지 않는다', () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = originalDebugPrint);

    final dio =
        Dio(
            BaseOptions(
              baseUrl: 'https://api.themoviedb.org/3',
              headers: {'Authorization': 'Bearer secret-token-value'},
            ),
          )
          ..httpClientAdapter = adapter
          ..interceptors.add(TmdbLoggingInterceptor());
    await TmdbMovieService(dio).fetchPopular();

    final allLogs = logs.join('\n');
    expect(allLogs, contains('[TMDB 요청] GET'));
    expect(allLogs, contains('Bearer ***'));
    expect(allLogs, isNot(contains('secret-token-value')));
  });
}

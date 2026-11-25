import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'support/fake_movie_log_services.dart';

/// 요청 기록 + 정해둔 응답
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(
  _RecordingAdapter adapter, {
  FakeTokenStorage? storage,
  String baseUrl = 'https://workbook.devnoco.com',
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
  if (storage != null) dio.interceptors.add(AuthInterceptor(storage));
  return dio;
}

Map<String, dynamic> _ok(String code, Object? result) => {
  'isSuccess': true,
  'code': code,
  'message': 'ok',
  'result': result,
};

const _favoriteJson = {
  'favoriteId': 3,
  'movieId': 550,
  'createdAt': '2026-09-06T12:14:03.000Z',
};

void main() {
  group('AuthInterceptor v8 보호 경로', () {
    bool protected(String path, String method) => AuthInterceptor.isProtected(
      Uri.parse('https://workbook.devnoco.com$path'),
      method,
    );

    test('즐겨찾기: 등록·목록 / 여부·해제만 보호, 8주차 경로는 /v8로', () {
      expect(protected('/v8/favorites', 'POST'), isTrue);
      expect(protected('/v8/favorites', 'GET'), isTrue);
      expect(protected('/v8/favorites/550', 'GET'), isTrue);
      expect(protected('/v8/favorites/550', 'DELETE'), isTrue);
      expect(protected('/v8/movie-records', 'POST'), isTrue);
      expect(protected('/v8/members/me', 'PATCH'), isTrue);
      expect(protected('/v8/ratings/3', 'DELETE'), isTrue);

      // 규칙 밖 method·path는 토큰 안 붙임
      expect(protected('/v8/favorites', 'DELETE'), isFalse);
      expect(protected('/v8/favorites/0', 'GET'), isFalse);
      expect(protected('/v8/favorites/abc', 'GET'), isFalse);
      expect(protected('/v7/members/me', 'GET'), isFalse);
      expect(protected('/v8/auth/login', 'POST'), isFalse);
    });

    test('TMDB 등 다른 host엔 같은 path여도 안 붙임', () {
      expect(
        AuthInterceptor.isProtected(
          Uri.parse('https://api.themoviedb.org/v8/favorites'),
          'GET',
        ),
        isFalse,
      );
    });

    test('즐겨찾기 요청에 저장된 JWT가 Bearer로 실림', () async {
      final storage = FakeTokenStorage('jwt-token');
      final adapter = _RecordingAdapter((_) => (200, _ok('COMMON200', [])));
      await FavoriteApiService(_dio(adapter, storage: storage))
          .fetchMyFavorites();
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer jwt-token',
      );
    });
  });

  group('FavoriteApiService (/v8/favorites)', () {
    test('등록 POST body {movieId}, 201 result → FavoriteResponseDto', () async {
      final adapter = _RecordingAdapter(
        (_) => (201, _ok('COMMON201', _favoriteJson)),
      );
      final favorite = await FavoriteApiService(_dio(adapter))
          .addFavorite(movieId: 550);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v8/favorites');
      expect(request.data, {'movieId': 550});
      expect(favorite.favoriteId, 3);
      expect(favorite.movieId, 550);
      expect(favorite.createdAt, DateTime.utc(2026, 9, 6, 12, 14, 3));
    });

    test('내 목록 GET: result 배열, 비어 있으면 []', () async {
      var body = _ok('COMMON200', [_favoriteJson]);
      final adapter = _RecordingAdapter((_) => (200, body));
      final service = FavoriteApiService(_dio(adapter));

      final list = await service.fetchMyFavorites();
      expect(adapter.requests.single.uri.path, '/v8/favorites');
      expect(list.single.movieId, 550);

      body = _ok('COMMON200', []);
      expect(await service.fetchMyFavorites(), isEmpty);
    });

    test('여부 GET /v8/favorites/{movieId}: 응답에 movieId 없어도 요청 값으로 채움', () async {
      final adapter = _RecordingAdapter(
        (_) => (200, _ok('COMMON200', {'isFavorite': true})),
      );
      final check = await FavoriteApiService(_dio(adapter))
          .checkFavorite(movieId: 550);
      expect(adapter.requests.single.uri.path, '/v8/favorites/550');
      expect(check.movieId, 550);
      expect(check.isFavorite, isTrue);
    });

    test('isFavorite가 bool 아니면 FormatException', () {
      expect(
        () => FavoriteCheckDto.fromJson({'isFavorite': 'yes'}, movieId: 1),
        throwsFormatException,
      );
    });

    test('해제 DELETE: 평점 v6(204)랑 다르게 200 + result null이 성공', () async {
      final adapter = _RecordingAdapter((_) => (200, _ok('COMMON200', null)));
      await FavoriteApiService(_dio(adapter)).deleteFavorite(movieId: 550);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      // path엔 favoriteId(3) 말고 movieId
      expect(request.uri.path, '/v8/favorites/550');
    });

    test('FAVORITE409_1·FAVORITE404_1은 서버 여부로 다시 맞출 오류', () {
      expect(
        needsFavoriteSync(
          fakeCodeError('/v8/favorites', 409, 'FAVORITE409_1', ''),
        ),
        isTrue,
      );
      expect(
        needsFavoriteSync(
          fakeCodeError('/v8/favorites/1', 404, 'FAVORITE404_1', ''),
        ),
        isTrue,
      );
      // 회원 없음 404는 즐겨찾기 없음이랑 다름
      expect(
        needsFavoriteSync(fakeCodeError('/x', 404, 'MEMBER404_1', '')),
        isFalse,
      );
    });
  });

  group('Challenge: POST /v8/movie-records', () {
    test('body에 movieId·정수 score·comment·필수 addToFavorites', () async {
      final adapter = _RecordingAdapter(
        (_) => (
          201,
          _ok('COMMON201', {
            'rating': {
              'ratingId': 9,
              'movieId': 550,
              'score': 3,
              'comment': '예시 후기',
              'createdAt': '2026-11-23T00:00:00.000Z',
            },
            'favorite': _favoriteJson,
          }),
        ),
      );
      final result = await RatingApiService(Dio(), _dio(adapter))
          .createMovieRecord(
            const CreateMovieRecordRequest(
              movieId: 550,
              score: 3,
              comment: ' 예시 후기 ',
              addToFavorites: true,
            ),
          );
      final request = adapter.requests.single;
      expect(request.uri.path, '/v8/movie-records');
      expect(request.data, {
        'movieId': 550,
        'score': 3,
        'comment': '예시 후기',
        'addToFavorites': true,
      });
      expect(result.rating.ratingId, 9);
      expect(result.favorite?.favoriteId, 3);
    });

    test('addToFavorites false면 favorite null이 정상', () {
      final result = MovieRecordResult.fromJson({
        'rating': {
          'ratingId': 1,
          'movieId': 2,
          'score': 5,
          'comment': null,
          'createdAt': '2026-11-23T00:00:00.000Z',
        },
        'favorite': null,
      });
      expect(result.favorite, isNull);
      expect(
        const CreateMovieRecordRequest(
          movieId: 2,
          score: 5,
          addToFavorites: false,
        ).toJson(),
        {'movieId': 2, 'score': 5, 'addToFavorites': false},
      );
    });
  });

  group('TMDB page·검색', () {
    test('Search: query·page·ko-KR·include_adult false', () async {
      final adapter = _RecordingAdapter(
        (_) => (
          200,
          {'page': 2, 'results': [], 'total_pages': 3, 'total_results': 41},
        ),
      );
      final page = await TmdbMovieService(
        _dio(adapter, baseUrl: 'https://api.themoviedb.org/3'),
      ).searchMovies(page: 2, query: '별빛');
      final request = adapter.requests.single;
      expect(request.uri.path, '/3/search/movie');
      expect(request.queryParameters, {
        'query': '별빛',
        'page': 2,
        'language': 'ko-KR',
        'include_adult': false,
      });
      expect(page.totalPages, 3);
    });
  });

  group('mapBounded', () {
    test('결과는 입력 순서 그대로, 동시에 최대 N개만 실행', () async {
      var running = 0;
      var maxRunning = 0;
      final result = await mapBounded(List.generate(12, (i) => i), 5, (
        value,
      ) async {
        running++;
        maxRunning = running > maxRunning ? running : maxRunning;
        await Future<void>.delayed(Duration(milliseconds: 12 - value));
        running--;
        return value * 10;
      });
      expect(result, List.generate(12, (i) => i * 10));
      expect(maxRunning, 5);
    });

    test('빈 입력은 바로 [], concurrency 0 이하는 ArgumentError', () async {
      expect(await mapBounded(<int>[], 5, (v) async => v), isEmpty);
      expect(() => mapBounded([1], 0, (v) async => v), throwsArgumentError);
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

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

Dio _dio(_RecordingAdapter adapter, {FakeTokenStorage? storage}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..httpClientAdapter = adapter;
  if (storage != null) dio.interceptors.add(AuthInterceptor(storage));
  return dio;
}

Map<String, dynamic> _ok(String code, Object? result) => {
  'isSuccess': true,
  'code': code,
  'message': 'ok',
  'result': result,
};

const _ratingJson = {
  'ratingId': 17,
  'movieId': 155,
  'score': 4,
  'comment': '테스트',
  'createdAt': '2026-11-19T12:35:18.674Z',
  'updatedAt': '2026-11-19T12:35:18.674Z',
};

const _memberJson = {
  'email': 'movie@example.com',
  'nickname': '무비러버',
  'createdAt': '2026-10-10T03:00:00.000Z',
};

Future<DioException> _catch(Future<void> Function() call) async {
  try {
    await call();
  } on DioException catch (error) {
    return error;
  }
  throw StateError('DioException이 나와야 함');
}

void main() {
  group('AuthInterceptor', () {
    test('보호 host·path에만 Bearer, 공개 요청·다른 host엔 안 붙임', () {
      bool protected(String url) =>
          AuthInterceptor.isProtected(Uri.parse(url), 'GET');
      expect(protected('https://workbook.devnoco.com/v8/members/me'), isTrue);
      expect(protected('https://workbook.devnoco.com/v8/ratings'), isTrue);
      expect(protected('https://workbook.devnoco.com/v8/ratings/3'), isTrue);
      expect(protected('https://workbook.devnoco.com/v8/auth/login'), isFalse);
      expect(
        protected('https://workbook.devnoco.com/v8/members/3/ratings'),
        isFalse,
      );
      expect(protected('https://api.themoviedb.org/v8/ratings'), isFalse);
      expect(protected('https://image.tmdb.org/t/p/w342/a.jpg'), isFalse);
    });

    test('보호 요청은 저장된 토큰을 매번 새로 읽어 붙이고, 이전 헤더는 지움', () async {
      final storage = FakeTokenStorage('first');
      final adapter = _RecordingAdapter(
        (_) => (200, _ok('COMMON200', _memberJson)),
      );
      final service = MemberApiService(_dio(adapter, storage: storage));

      await service.fetchMe();
      storage.token = 'second';
      await service.fetchMe();
      expect(adapter.requests[0].headers['Authorization'], 'Bearer first');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer second');

      storage.token = null; // 로그아웃 후엔 헤더 없음
      await service.fetchMe();
      expect(adapter.requests[2].headers.containsKey('Authorization'), isFalse);
    });

    test('공개 요청은 토큰이 있어도 Authorization 안 보냄', () async {
      final storage = FakeTokenStorage('secret');
      final adapter = _RecordingAdapter((_) => (200, {'available': true}));
      await SignUpService(_dio(adapter, storage: storage)).checkNickname('제로');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('저장소 읽기 실패는 서버 401이 아니라 unknown 오류', () async {
      final storage = FakeTokenStorage('x')..failRead = true;
      final adapter = _RecordingAdapter(
        (_) => (200, _ok('COMMON200', _memberJson)),
      );
      final error = await _catch(
        () => MemberApiService(_dio(adapter, storage: storage)).fetchMe(),
      );
      expect(error.type, DioExceptionType.unknown);
      expect(error.response, isNull);
      expect(adapter.requests, isEmpty); // 요청 자체를 안 보냄
    });
  });

  group('로그인·내 정보', () {
    test(
      '로그인 POST /v8/auth/login, result에서 accessToken·nickname (memberId 없음)',
      () async {
        final adapter = _RecordingAdapter(
          (_) => (
            200,
            _ok('COMMON200', {'nickname': '무비러버', 'accessToken': 'jwt'}),
          ),
        );
        final result = await AuthApiService(_dio(adapter)).login(
          const LoginRequest(email: ' movie@example.com ', password: ' Pw1! '),
        );
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '/v8/auth/login');
        expect(request.data, {
          'email': 'movie@example.com',
          'password': ' Pw1! ',
        });
        expect(result.accessToken, 'jwt');
        expect(result.nickname, '무비러버');
        expect(result.toString(), isNot(contains('jwt'))); // 출력에 토큰 원문 X
      },
    );

    test('로그인 실패 AUTH401_1은 Form 오류, AUTH401_2/3/4만 세션 만료', () async {
      final adapter = _RecordingAdapter(
        (_) => (
          401,
          {
            'isSuccess': false,
            'code': 'AUTH401_1',
            'message': '이메일 또는 비밀번호가 올바르지 않습니다.',
            'result': null,
          },
        ),
      );
      final error = await _catch(
        () =>
            AuthApiService(_dio(adapter))
                .login(const LoginRequest(email: 'a@b.c', password: 'x')),
      );
      expect(apiErrorCode(error), 'AUTH401_1');
      expect(isSessionExpired(error), isFalse);
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        expect(isSessionExpired(fakeCodeError('/x', 401, code, '')), isTrue);
      }
      // 네트워크 실패는 401 아님
      expect(isSessionExpired(fakeHttpError('/x')), isFalse);
    });

    test(
      'GET·PATCH /v8/members/me → MemberInfo (email·nickname·createdAt)',
      () async {
        final adapter = _RecordingAdapter(
          (_) => (200, _ok('COMMON200', _memberJson)),
        );
        final service = MemberApiService(_dio(adapter));
        final me = await service.fetchMe();
        expect(me.nickname, '무비러버');
        expect(me.createdAt, DateTime.utc(2026, 10, 10, 3));

        await service.updateNickname('새닉네임');
        final patch = adapter.requests.last;
        expect(patch.method, 'PATCH');
        expect(patch.uri.path, '/v8/members/me');
        expect(patch.data, {'nickname': '새닉네임'});
      },
    );
  });

  group('회원가입 (v8)', () {
    test('중복 확인·가입 모두 v8 경로', () async {
      final adapter = _RecordingAdapter(
        (options) => options.method == 'POST'
            ? (
                201,
                _ok('COMMON201', {
                  'memberId': 20,
                  'email': 'zero@example.com',
                  'nickname': '제로',
                }),
              )
            : (200, {'available': true}),
      );
      final service = SignUpService(_dio(adapter));
      await service.checkNickname('제로');
      await service.checkEmail('zero@example.com');
      final result = await service.signUp(
        const CreateMemberRequest(
          email: 'zero@example.com',
          password: 'Password1!',
          nickname: '제로',
        ),
      );
      expect(adapter.requests.map((r) => r.uri.path), [
        '/v8/members/nickname/%EC%A0%9C%EB%A1%9C',
        '/v8/members/email/zero%40example.com',
        '/v8/members',
      ]);
      expect(result.result?.memberId, 20);
    });
  });

  group('평점 (v8)', () {
    test(
      '등록 POST /v8/ratings: body에 memberId 없음, 201 result는 Rating 객체',
      () async {
        final adapter = _RecordingAdapter(
          (_) => (201, _ok('COMMON201', _ratingJson)),
        );
        final service = RatingApiService(Dio(), _dio(adapter));
        final rating = await service.createRating(
          const CreateRatingRequest(movieId: 155, score: 4, comment: '테스트'),
        );
        final request = adapter.requests.single;
        expect(request.uri.path, '/v8/ratings');
        expect(request.data, {'movieId': 155, 'score': 4, 'comment': '테스트'});
        expect((request.data as Map).containsKey('memberId'), isFalse);
        expect(rating.ratingId, 17);
        expect(rating.movieId, 155);
      },
    );

    test(
      '수정 PATCH /v8/ratings/{id}: comment null도 보냄, result Rating',
      () async {
        final adapter = _RecordingAdapter(
          (_) => (200, _ok('COMMON200', _ratingJson)),
        );
        final rating = await RatingApiService(Dio(), _dio(adapter))
            .updateRating(
              ratingId: 17,
              request: const UpdateRatingRequest(score: 5),
            );
        final request = adapter.requests.single;
        expect(request.uri.path, '/v8/ratings/17');
        expect(request.data, {'score': 5, 'comment': null});
        expect(rating.ratingId, 17);
      },
    );

    test('삭제 DELETE: v6(204)랑 다르게 200 + result null이 성공', () async {
      final adapter = _RecordingAdapter((_) => (200, _ok('COMMON200', null)));
      await RatingApiService(Dio(), _dio(adapter)).deleteRating(17);
      expect(adapter.requests.single.uri.path, '/v8/ratings/17');
      expect(adapter.requests.single.method, 'DELETE');
    });

    test('유저별 조회는 공개 Dio로 /v8/members/{id}/ratings, 배열 그대로', () async {
      final public = _RecordingAdapter((_) => (200, [_ratingJson]));
      final auth = _RecordingAdapter((_) => (500, null));
      final ratings = await RatingApiService(
        _dio(public),
        _dio(auth),
      ).fetchMemberRatings(20);
      expect(public.requests.single.uri.path, '/v8/members/20/ratings');
      expect(auth.requests, isEmpty);
      expect(ratings.single.comment, '테스트');
    });

    test('도메인 오류 code별 문구 (403·404·409), 모르는 code는 서버 message', () {
      expect(
        writeErrorMessage(fakeCodeError('/r', 403, 'RATING403_1', 'x')),
        '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
      );
      expect(
        writeErrorMessage(fakeCodeError('/r', 404, 'RATING404_1', 'x')),
        '이미 삭제됐거나 없는 평점이에요.',
      );
      expect(
        writeErrorMessage(fakeCodeError('/r', 409, 'RATING409_1', 'x')),
        '이미 이 영화에 평점을 남겼어요.',
      );
      expect(
        writeErrorMessage(
          fakeCodeError('/r', 400, 'COMMON400', '평점은 5점 이하여야 합니다.'),
        ),
        '평점은 5점 이하여야 합니다.',
      );
      expect(
        writeErrorMessage(fakeHttpError('/r')),
        '요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
    });
  });

  group('요청 Model', () {
    test('평점 등록: comment 비어 있으면 안 넣음 / 수정: null도 보냄', () {
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 5,
          comment: '  ',
        ).toJson(),
        {'movieId': 550, 'score': 5},
      );
      expect(const UpdateRatingRequest(score: 3).toJson(), {
        'score': 3,
        'comment': null,
      });
    });

    test('서버 평점은 1~5 정수만', () {
      expect(validateServerScore(5.0), 5);
      for (final bad in [0.0, 3.5, 6.0]) {
        expect(() => validateServerScore(bad), throwsArgumentError);
      }
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

/// 요청 기록 + 정해둔 응답 (body null이면 본문 없음)
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
    if (body == null) return ResponseBody.fromString('', status);
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

Dio _dio(_RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
      ..httpClientAdapter = adapter;

Map<String, dynamic> _common(int status, String message, [Object? result]) => {
  'isSuccess': status < 300,
  'code': 'COMMON$status',
  'message': message,
  'result': result,
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
  group('요청 Model (toJson)', () {
    test('회원가입: 이메일·닉네임만 trim, 비밀번호는 그대로', () {
      const request = CreateMemberRequest(
        email: ' zero@example.com ',
        password: ' Pass word1! ',
        nickname: ' 제로 ',
      );
      expect(request.toJson(), {
        'email': 'zero@example.com',
        'password': ' Pass word1! ',
        'nickname': '제로',
      });
    });

    test('평점 등록: comment 비어 있으면 아예 안 넣음', () {
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 5,
          comment: '  ',
        ).toJson(),
        {'movieId': 550, 'score': 5},
      );
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: ' 좋아요 ',
        ).toJson(),
        {'movieId': 550, 'score': 4, 'comment': '좋아요'},
      );
    });

    test('평점 수정: comment는 null이어도 항상 같이 보냄 (전체 교체)', () {
      expect(const UpdateRatingRequest(score: 3).toJson(), {
        'score': 3,
        'comment': null,
      });
      expect(const UpdateRatingRequest(score: 3, comment: '유지').toJson(), {
        'score': 3,
        'comment': '유지',
      });
    });

    test('서버 평점은 1~5 정수만 (반 점, 범위 밖은 예외)', () {
      expect(validateServerScore(1), 1);
      expect(validateServerScore(5.0), 5);
      for (final bad in [0.0, 0.5, 3.5, 6.0]) {
        expect(() => validateServerScore(bad), throwsArgumentError);
      }
    });
  });

  group('SignUpService (v6)', () {
    test('중복 확인은 v6 경로, 성공은 wrapper 없는 {available}', () async {
      final adapter = _RecordingAdapter((_) => (200, {'available': true}));
      final service = SignUpService(_dio(adapter));

      expect(await service.checkNickname(' 제로 '), isTrue);
      expect(await service.checkEmail('zero@example.com'), isTrue);
      expect(
        adapter.requests[0].uri.path,
        '/v6/members/nickname/%EC%A0%9C%EB%A1%9C',
      );
      expect(
        adapter.requests[1].uri.path,
        '/v6/members/email/zero%40example.com',
      );
    });

    test('회원가입 POST 201 → CommonResponse<SignUpResult>에서 memberId', () async {
      final adapter = _RecordingAdapter(
        (_) => (
          201,
          _common(201, '회원가입에 성공했습니다.', {
            'memberId': 4,
            'email': 'zero@example.com',
            'nickname': '제로',
          }),
        ),
      );
      final response = await SignUpService(_dio(adapter)).signUp(
        const CreateMemberRequest(
          email: 'zero@example.com',
          password: 'Password1!',
          nickname: '제로',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v6/members');
      expect(request.data, containsPair('nickname', '제로'));
      expect(response.isSuccess, isTrue);
      expect(response.code, 'COMMON201');
      expect(response.result?.memberId, 4);
    });

    test('400·409 실패는 서버 message 그대로, 공통 형식 아니면 기본 문구', () async {
      for (final (status, body, expected) in [
        (
          400,
          _common(400, '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.'),
          '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
        ),
        (409, _common(409, '이미 사용 중인 이메일입니다.'), '이미 사용 중인 이메일입니다.'),
        (502, {'error': 'Bad Gateway'}, '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
      ]) {
        final service = SignUpService(
          _dio(_RecordingAdapter((_) => (status, body))),
        );
        final error = await _catch(
          () => service.signUp(
            const CreateMemberRequest(
              email: 'a@b.c',
              password: 'x',
              nickname: 'ab',
            ),
          ),
        );
        expect(writeSignUpErrorMessage(error), expected);
      }
    });
  });

  group('RatingApiService (v6)', () {
    test('등록 POST: TMDB movieId·정수 score를 body로, 201이면 성공', () async {
      final adapter = _RecordingAdapter(
        (_) => (201, _common(201, '평점 등록에 성공했습니다.', 6)),
      );
      await RatingApiService(_dio(adapter)).createRating(
        memberId: 4,
        request: const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: '테스트',
        ),
      );
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v6/members/4/ratings');
      expect(request.data, {'movieId': 550, 'score': 4, 'comment': '테스트'});
    });

    test('수정 PATCH: score와 comment(null 포함)를 같이 보냄', () async {
      final adapter = _RecordingAdapter(
        (_) => (200, _common(200, '평점 수정에 성공했습니다.')),
      );
      await RatingApiService(_dio(adapter)).updateRating(
        memberId: 4,
        ratingId: 6,
        request: const UpdateRatingRequest(score: 3),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/v6/members/4/ratings/6');
      expect(request.data, {'score': 3, 'comment': null});
    });

    test('삭제 DELETE: 204 본문 없음을 파싱하지 않고 성공', () async {
      final adapter = _RecordingAdapter((_) => (204, null));
      await RatingApiService(_dio(adapter))
          .deleteRating(memberId: 4, ratingId: 6);
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/v6/members/4/ratings/6');
    });

    test('400/403/404/409는 서버 message로 구분, 403·404만 다시 조회', () async {
      for (final (status, message, refresh) in [
        (400, '별점은 5점 이하여야 합니다.', false),
        (403, '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.', true),
        (404, '존재하지 않는 평점입니다.', true),
        (409, '이미 이 영화에 평점을 남기셨습니다.', false),
      ]) {
        final service = RatingApiService(
          _dio(_RecordingAdapter((_) => (status, _common(status, message)))),
        );
        final error = await _catch(
          () => service.updateRating(
            memberId: 4,
            ratingId: 6,
            request: const UpdateRatingRequest(score: 3),
          ),
        );
        expect(writeErrorMessage(error), message);
        expect(
          shouldRefreshAfterRatingError(error),
          refresh,
          reason: '$status',
        );
      }
    });

    test('조회 GET 실패도 v6 공통 형식이면 서버 message', () async {
      final adapter = _RecordingAdapter(
        (_) => (404, _common(404, '존재하지 않는 유저입니다.')),
      );
      final error = await _catch(
        () => RatingApiService(_dio(adapter)).fetchMyRatings(99999999),
      );
      expect(adapter.requests.single.path, '/v6/members/99999999/ratings');
      expect(writeMyRatingsErrorMessage(error), '존재하지 않는 유저입니다.');
    });
  });

  test('CommonResponse: 공통 형식 아닌 body는 null', () {
    expect(CommonResponse.tryParseError({'message': 'x'}), isNull);
    expect(CommonResponse.tryParseError('html'), isNull);
    expect(CommonResponse.tryParseError(_common(409, '중복'))?.code, 'COMMON409');
  });
}

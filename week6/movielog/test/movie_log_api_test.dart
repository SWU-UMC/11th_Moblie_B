import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

/// 네트워크 대신 요청 경로 기록하고 정해둔 응답 주는 Adapter
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final (int, Object) Function(RequestOptions options) respond;
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

Dio _dio(_RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
      ..httpClientAdapter = adapter;

void main() {
  test('닉네임·이메일 중복 확인은 공백을 빼고 경로를 인코딩해 v5로 요청한다', () async {
    final adapter = _RecordingAdapter((_) => (200, {'available': false}));
    final service = MemberCheckService(_dio(adapter));

    expect(await service.checkNickname(' 무비 러버 '), isFalse);
    expect(await service.checkEmail('movie@example.com'), isFalse);

    expect(
      adapter.requests[0].uri.toString(),
      'https://workbook.devnoco.com/v5/members/nickname/%EB%AC%B4%EB%B9%84%20%EB%9F%AC%EB%B2%84',
    );
    expect(
      adapter.requests[1].uri.toString(),
      'https://workbook.devnoco.com/v5/members/email/movie%40example.com',
    );
  });

  test('유저별 평점 응답을 그대로(Wrapper 없이) RatingDto 목록으로 바꾼다', () async {
    final adapter = _RecordingAdapter(
      (_) => (
        200,
        [
          {
            'ratingId': 2,
            'movieId': 680,
            'score': 4,
            'comment': '다시 봐도 좋다',
            'createdAt': '2026-10-28T19:00:08.615Z',
            'updatedAt': '2026-10-28T19:00:08.615Z',
          },
          {
            'ratingId': 3,
            'movieId': 13,
            'score': 3,
            'comment': null,
            'createdAt': '2026-10-28T19:00:08.615Z',
            'updatedAt': '2026-10-28T19:00:08.615Z',
          },
        ],
      ),
    );
    final ratings = await RatingApiService(_dio(adapter)).fetchMyRatings(1);

    expect(adapter.requests.single.path, '/v5/members/1/ratings');
    expect(ratings.map((r) => r.movieId), [680, 13]);
    expect(ratings.last.comment, isNull);
    expect(ratings.first.createdAt, DateTime.utc(2026, 10, 28, 19, 0, 8, 615));
  });

  test('평점이 없으면 빈 List (실패가 아님)', () async {
    final adapter = _RecordingAdapter((_) => (200, <Object>[]));
    expect(await RatingApiService(_dio(adapter)).fetchMyRatings(3), isEmpty);
  });

  test('평점 조회 실패는 상태 코드별로 다른 문구', () async {
    for (final (status, expected) in [
      (400, 'memberId 형식을 다시 확인해 주세요.'),
      (404, '존재하지 않는 회원입니다.'),
      (500, '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
    ]) {
      final adapter = _RecordingAdapter(
        (_) => (
          status,
          {'message': 'error', 'error': 'Error', 'statusCode': status},
        ),
      );
      try {
        await RatingApiService(_dio(adapter)).fetchMyRatings(999999);
        fail('$status 응답은 DioException이어야 합니다.');
      } on DioException catch (error) {
        expect(writeMyRatingsErrorMessage(error), expected);
      }
    }
  });

  test('RatingDto는 comment null을 그대로 null로 둔다', () {
    final rating = RatingDto.fromJson({
      'ratingId': 1,
      'movieId': 550,
      'score': 5,
      'comment': null,
      'createdAt': '2026-09-06T12:14:03.000Z',
    });
    expect(rating.comment, isNull);
    expect(rating.score, 5);
  });
}

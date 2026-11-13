import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

DioException fakeHttpError(String path, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: path),
  response: statusCode == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: path),
          statusCode: statusCode,
        ),
  type: statusCode == null
      ? DioExceptionType.connectionError
      : DioExceptionType.badResponse,
);

/// 정해둔 값으로 중복 여부 응답하는 Fake
class FakeMemberCheckService extends MemberCheckService {
  FakeMemberCheckService({
    this.takenNicknames = const {'무비러버'},
    this.takenEmails = const {'taken@example.com'},
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  bool fail = false;

  /// 있으면 complete 될 때까지 응답 지연
  Completer<void>? gate;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];

  Future<void> _wait() async {
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname);
    await _wait();
    if (fail) throw fakeHttpError('/v5/members/nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email);
    await _wait();
    if (fail) throw fakeHttpError('/v5/members/email');
    return !takenEmails.contains(email.trim());
  }
}

RatingDto fakeRating(
  int ratingId,
  int movieId, {
  int score = 4,
  String? comment,
}) => RatingDto(
  ratingId: ratingId,
  movieId: movieId,
  score: score,
  comment: comment,
  createdAt: DateTime.utc(2026, 9, 6, 12),
);

/// 정해둔 평점 목록 돌려주는 Fake
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings =
          ratings ??
          [
            fakeRating(3, 13, score: 3),
            fakeRating(2, 2, score: 4, comment: '다시 봐도 좋다'),
            fakeRating(1, 3, score: 5, comment: '최고의 영화!'),
          ],
      super(Dio());

  List<RatingDto> ratings;

  /// 이 상태 코드로 실패 (0이면 통신 실패)
  int? failStatus;

  Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    calls++;
    final pending = gate;
    if (pending != null) await pending.future;
    final status = failStatus;
    if (status != null) {
      throw fakeHttpError(
        '/v5/members/$memberId/ratings',
        statusCode: status == 0 ? null : status,
      );
    }
    return ratings;
  }
}

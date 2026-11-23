import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// v7 평점 등록·수정 응답의 result(Rating 객체)를 읽습니다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

/// 유저별 평점 조회는 공통 형식이 아닌 직접 배열입니다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 평점 API(v7)를 호출합니다.
///
/// - 유저별 평점 조회는 공개 API라 공개용 Client로 보냅니다. (토큰 없음)
/// - 등록·수정·삭제는 보호 API라 보호용 Client로 보냅니다. (Authorization: Bearer)
///   경로·body 어디에도 memberId가 없습니다.
///
/// 평점 응답에는 영화 제목·포스터가 없으므로, 화면에서 TMDB 영화와 movieId로 연결합니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 조회입니다. v7 로그인·내 정보 응답에 memberId가 없으므로
  /// "로그인한 내 평점 목록"으로 쓰지 않습니다. (계약 확인 전까지 미사용)
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// 201이면 result에 저장된 Rating 객체가 옵니다. (v6의 ratingId/null과 다릅니다)
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// PATCH지만 전체 교체입니다. comment를 빼면 기존 후기가 null로 덮이므로
  /// 유지하려면 기존 값을 그대로 보냅니다. (Dialog가 기존 별점·코멘트를 채워 둡니다.)
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  /// v7 삭제 성공은 204가 아니라 200 + result null입니다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 쓰기 실패를 사용자 문구로 바꿉니다.
/// 기본은 서버 message를 그대로 보여주고, 다음 행동이 필요한 code만 안내를 덧붙입니다.
String writeErrorMessage(DioException error) {
  final code = apiErrorCode(error);
  if (code == 'RATING409_1') {
    return '이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.';
  }
  if (sessionExpiredCodes.contains(code)) {
    return '로그인이 만료됐어요. 다시 로그인해 주세요.';
  }
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 서버에 이미 없는 평점(`RATING404_1`)입니다. 화면 목록에서 빼서 서버와 맞춥니다.
/// 403(`RATING403_1`)은 권한 부족이라 안내만 하고 로그아웃하지 않습니다.
bool isRatingGone(DioException error) =>
    apiErrorCode(error) == 'RATING404_1' ||
    (apiErrorCode(error) == null && error.response?.statusCode == 404);

/// 평점 쓰기(등록·수정·삭제)가 실패했을 때 Dialog에 보여줄 문구를 담아 던집니다.
class RatingWriteFailure implements Exception {
  const RatingWriteFailure(this.message, {this.sessionExpired = false});

  final String message;

  /// true면 401(AUTH401_2/3/4)이라 세션을 정리했습니다. Dialog는 닫고 로그인으로 이동합니다.
  final bool sessionExpired;

  @override
  String toString() => 'RatingWriteFailure: $message';
}

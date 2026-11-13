import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 회원별 평점 조회·등록·수정·삭제 API(v6)를 호출합니다.
/// 평점 응답에는 영화 제목·포스터가 없으므로, 화면에서 TMDB 영화와 movieId로 연결합니다.
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 성공 응답은 공통 형식이 아닌 직접 배열입니다. 평점이 없으면 빈 배열이 옵니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 201을 성공으로 처리합니다.
  /// 명세 설명은 result가 ratingId라고 하지만 예시는 null이라,
  /// 계약이 확정되기 전에는 result를 파싱하지 않고 성공 뒤 GET으로 목록을 확인합니다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// PATCH지만 전체 교체입니다. comment를 빼면 기존 후기가 null로 덮이므로
  /// 유지하려면 기존 값을 그대로 보냅니다. (Dialog가 기존 코멘트를 채워 둡니다.)
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  /// 성공은 204이고 body가 없습니다. 응답을 JSON으로 파싱하지 않습니다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 조회 실패를 사용자에게 보여줄 문구로 바꿉니다.
/// 400·404·그 외 오류를 하나의 "실패"로 뭉치지 않습니다.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 평점 쓰기 실패의 서버 message를 그대로 보여줍니다.
/// 같은 COMMON404라도 등록은 "유저", 수정·삭제는 "평점"을 가리키므로
/// code로 문구를 새로 만들지 않습니다.
String writeErrorMessage(DioException error) {
  final common = CommonResponse.tryParseError(error.response?.data);
  return common?.message ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// code는 문구가 아니라 다음 UI 행동(다시 조회할지)을 정하는 데만 씁니다.
/// 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이므로 다시 조회해서 맞춥니다.
/// 400(별점 범위)·409(중복 등록)는 값만 고치면 되므로 다시 조회하지 않습니다.
/// body를 공통 형식으로 읽지 못해도 HTTP status가 403·404면 다시 조회합니다.
bool shouldRefreshAfterRatingError(DioException error) {
  final status = error.response?.statusCode;
  if (status == 403 || status == 404) return true;
  final code = CommonResponse.tryParseError(error.response?.data)?.code;
  return code == 'COMMON403' || code == 'COMMON404';
}

/// 평점 쓰기(등록·수정·삭제)가 실패했을 때 Dialog에 보여줄 문구를 담아 던집니다.
class RatingWriteFailure implements Exception {
  const RatingWriteFailure(this.message);

  final String message;

  @override
  String toString() => 'RatingWriteFailure: $message';
}

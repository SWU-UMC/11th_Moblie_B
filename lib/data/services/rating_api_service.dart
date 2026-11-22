import '../models/common_response.dart';
import '../models/rating_request.dart';

import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

class RatingApiService {
  RatingApiService(this._dio);
  final Dio _dio;
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    return (response.data as List<dynamic>)
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) throw StateError('예상하지 못한 등록 응답입니다.');
    _checkWriteResponse(response.data);
  }

  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {
        'score': validateServerScore(score.toDouble()),
        'comment': comment,
      },
    );
    if (response.statusCode != 200) throw StateError('예상하지 못한 수정 응답입니다.');
    _checkWriteResponse(response.data);
  }

  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) throw StateError('예상하지 못한 삭제 응답입니다.');
    // 204 응답은 본문이 없으므로 JSON을 파싱하지 않습니다.
  }

  void _checkWriteResponse(Object? data) {
    final common = CommonResponse<Object?>.fromJson(
      data as Map<String, dynamic>,
      (value) => value,
    );
    if (!common.isSuccess) throw StateError(common.message);
  }
}

String writeErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    try {
      return CommonResponse<Object?>.fromJson(data, (value) => value).message;
    } on FormatException {
      /* 공통 응답이 아닌 오류 */
    } on TypeError {
      /* 계약 외 응답 */
    }
  }
  return '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

bool shouldRefreshAfterRatingError(DioException error) {
  final data = error.response?.data;
  final code = data is Map<String, dynamic> ? data['code'] : null;
  return code == 'COMMON403' || code == 'COMMON404';
}

String writeMyRatingsErrorMessage(DioException error) =>
    writeErrorMessage(error);

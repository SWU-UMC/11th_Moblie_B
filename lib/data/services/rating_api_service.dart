import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_request.dart';
import '../models/rating_dto.dart';

RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) throw StateError('평점 응답 형식이 올바르지 않습니다.');
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (v) => RatingDto.fromJson(v as Map<String, dynamic>),
  );
  if (!common.isSuccess || common.result == null) {
    throw StateError('평점 result가 없습니다.');
  }
  return common.result!;
}

class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);
  final Dio _publicDio;
  final Dio _authDio;
  // 공개 회원별 조회입니다. 로그인 회원의 ID를 JWT에서 추정하지 않습니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return (response.data as List)
        .map((v) => RatingDto.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    if (response.statusCode != 201) throw StateError('예상하지 못한 등록 응답입니다.');
    return parseRatingResult(response.data);
  }

  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: {
        'score': validateServerScore(score.toDouble()),
        'comment': comment,
      },
    );
    if (response.statusCode != 200) throw StateError('예상하지 못한 수정 응답입니다.');
    return parseRatingResult(response.data);
  }

  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw StateError('예상하지 못한 삭제 응답입니다.');
    }
    final common = CommonResponse<Object?>.fromJson(
      response.data as Map<String, dynamic>,
      (v) => v,
    );
    if (!common.isSuccess || common.result != null) {
      throw StateError('삭제 응답을 확인하지 못했습니다.');
    }
  }
}

String writeErrorMessage(DioException error) =>
    apiErrorMessage(error) ?? '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';

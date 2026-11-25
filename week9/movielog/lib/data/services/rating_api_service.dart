import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/movie_record_models.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 공통 응답 result → RatingDto (v8 등록·수정)
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

/// 공개 조회는 wrapper 없이 배열 그대로 옴
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 평점 API (v8, 8주차 v7이랑 계약 같음)
/// 조회는 공개 Dio, 등록·수정·삭제는 보호 Dio
/// 어떤 Dio 쓸지는 Service가 메서드마다 정함 → ViewModel은 몰라도 됨
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 유저별 평점 공개 조회 (토큰 없음, memberId path 유지)
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get<Object?>(
      '/v8/members/$memberId/ratings',
    );
    return parseRatingList(response.data);
  }

  /// 201 + result Rating 객체
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post<Object?>(
      '/v8/ratings',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  /// 200 + result Rating 객체
  /// 전체 교체라 comment null이어도 항상 같이 보냄
  Future<RatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final response = await _authDio.patch<Object?>(
      '/v8/ratings/$ratingId',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  /// v6(204)랑 다르게 200 + result null
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete<Object?>('/v8/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }

  /// Challenge: 평점 + 즐겨찾기 한 번에 저장 (201 result {rating, favorite})
  Future<MovieRecordResult> createMovieRecord(
    CreateMovieRecordRequest request,
  ) async {
    final response = await _authDio.post<Object?>(
      '/v8/movie-records',
      data: request.toJson(),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('영화 기록 응답 형식이 올바르지 않습니다.');
    }
    final result = CommonResponse<MovieRecordResult>.fromJson(
      data,
      MovieRecordResult.fromJson,
    ).result;
    if (result == null) throw StateError('영화 기록 result가 없습니다.');
    return result;
  }
}

/// 평점 쓰기 실패 문구
/// v7·v8은 도메인 code(RATING409_1 등)라 code로 나누고, 모르는 code는 서버 message
String writeErrorMessage(DioException error) {
  switch (apiErrorCode(error)) {
    case 'RATING403_1':
      return '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.';
    case 'RATING404_1':
      return '이미 삭제됐거나 없는 평점이에요.';
    case 'RATING409_1':
      return '이미 이 영화에 평점을 남겼어요.';
    case 'MEMBER404_1':
      return '회원 정보를 찾을 수 없어요.';
    case 'FAVORITE409_1':
      return '이미 즐겨찾기한 영화예요.';
  }
  return apiErrorMessage(error) ?? '요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
}

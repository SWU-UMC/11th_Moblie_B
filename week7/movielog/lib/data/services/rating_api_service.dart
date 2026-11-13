import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 유저별 평점 조회·등록·수정·삭제 API (v6)
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 성공은 wrapper 없이 배열 그대로 옴
  /// 평점 없으면 [] (에러 아님)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>(
      '/v6/members/$memberId/ratings',
    );
    return (response.data ?? const [])
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 201 + 공통 응답
  /// result가 ratingId라는 설명이랑 예시(null)가 달라서 result는 안 읽음
  /// → 등록 후 목록 다시 조회해서 확인
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post<Object?>(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// 200 + 공통 응답 (result null)
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    await _dio.patch<Object?>(
      '/v6/members/$memberId/ratings/$ratingId',
      data: request.toJson(),
    );
  }

  /// 204 + body 없음 → JSON 파싱 안 함
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete<void>(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 쓰기 실패 문구
/// 같은 COMMON404도 등록은 "유저", 수정·삭제는 "평점"이라 서버 message 그대로 씀
String writeErrorMessage(DioException error) {
  return CommonResponse.tryParseError(error.response?.data)?.message ??
      '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// code는 문구 말고 다음 행동 정하는 데만 씀
/// 403·404 → 화면 목록이 서버랑 어긋남 → 다시 조회
/// 400·409 → 값만 고쳐서 다시 하면 됨 → 조회 안 함
bool shouldRefreshAfterRatingError(DioException error) {
  final code = CommonResponse.tryParseError(error.response?.data)?.code;
  return code == 'COMMON403' || code == 'COMMON404';
}

/// 평점 조회 실패 문구
/// v6 조회 실패는 공통 형식이라 서버 message 먼저 씀
String writeMyRatingsErrorMessage(DioException error) {
  final message = CommonResponse.tryParseError(error.response?.data)?.message;
  if (message != null) return message;
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

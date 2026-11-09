import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

/// 유저별 평점 조회 API
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 평점 없으면 [] (에러 아님). 400: id 형식 오류, 404: 없는 회원
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>(
      '/v5/members/$memberId/ratings',
    );
    return (response.data ?? const [])
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// 상태 코드별 에러 문구
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

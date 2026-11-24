import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/favorite_check_dto.dart';
import '../models/favorite_response_dto.dart';

/// 공통 응답 body → CommonResponse (형식 다르면 StateError)
CommonResponse<T> _parseCommon<T>(
  Object? data,
  T Function(Object? value) parseResult,
) {
  if (data is! Map<String, dynamic>) {
    throw StateError('즐겨찾기 응답 형식이 올바르지 않습니다.');
  }
  return CommonResponse<T>.fromJson(data, parseResult);
}

/// MovieLog 즐겨찾기 API (/v8/favorites)
/// 전부 보호 요청이라 AuthInterceptor 달린 보호 Dio만 받음
/// memberId 안 보냄 → 누구 즐겨찾기인지는 서버가 JWT로 판단
class FavoriteApiService {
  FavoriteApiService(this._dio);

  final Dio _dio;

  /// 등록: 201, result에 FavoriteResponseDto
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response = await _dio.post<Object?>(
      '/v8/favorites',
      data: {'movieId': movieId},
    );
    final result = _parseCommon(
      response.data,
      FavoriteResponseDto.fromJson,
    ).result;
    if (result == null) throw StateError('즐겨찾기 등록 result가 없습니다.');
    return result;
  }

  /// 내 목록: 200, result 배열 (없으면 [])
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _dio.get<Object?>('/v8/favorites');
    final body = _parseCommon<List<FavoriteResponseDto>>(response.data, (
      value,
    ) {
      if (value is! List) throw StateError('즐겨찾기 목록은 배열이어야 합니다.');
      return value.map(FavoriteResponseDto.fromJson).toList();
    });
    return body.result ?? const [];
  }

  /// 특정 영화 여부: 응답에 movieId 없어서 요청한 값 같이 넘김
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _dio.get<Object?>('/v8/favorites/$movieId');
    final result = _parseCommon(
      response.data,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    ).result;
    if (result == null) throw StateError('즐겨찾기 여부 result가 없습니다.');
    return result;
  }

  /// 해제: 200 + result null (body를 DTO로 파싱 안 함)
  /// path엔 favoriteId 말고 movieId
  Future<void> deleteFavorite({required int movieId}) async {
    final response = await _dio.delete<Object?>('/v8/favorites/$movieId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 해제 응답: ${response.statusCode}');
    }
  }
}

/// 즐겨찾기 오류 code
const favoriteAlreadyAdded = 'FAVORITE409_1';
const favoriteNotFound = 'FAVORITE404_1';

/// 이미 등록(409)/이미 해제(404) → 서버 현재 여부로 맞춰야 하는 경우
bool needsFavoriteSync(DioException error) {
  final code = apiErrorCode(error);
  return code == favoriteAlreadyAdded || code == favoriteNotFound;
}

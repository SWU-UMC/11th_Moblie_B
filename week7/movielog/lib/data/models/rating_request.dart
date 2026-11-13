/// 서버 평점은 1~5 정수만 됨
/// 별점 위젯이 이미 정수로 막지만 안전장치로 한 번 더 확인
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// POST /v6/members/{memberId}/ratings 요청 body
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  /// TMDB 영화 id (목록 index 아님)
  final int movieId;
  final int score;
  final String? comment;

  /// comment는 선택이라 비어 있으면 아예 안 넣음
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

/// PATCH /v6/members/{memberId}/ratings/{ratingId} 요청 body
/// 부분 수정 아니고 전체 교체 → comment 빼면 기존 후기가 null로 덮임
/// 그래서 comment는 null이어도 항상 같이 보냄
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, this.comment});

  final int score;
  final String? comment;

  Map<String, dynamic> toJson() {
    final trimmed = comment?.trim();
    return {
      'score': score,
      'comment': trimmed == null || trimmed.isEmpty ? null : trimmed,
    };
  }
}

/// 별점 입력(double)을 서버 평점(1~5 정수)으로 바꿉니다.
/// 반 점이나 범위 밖 값을 조용히 toInt()로 바꾸지 않고 바로 알립니다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// 평점 등록 요청 body입니다. (`POST /v6/members/{memberId}/ratings`)
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  /// 영화 배열 index가 아니라 TMDB 영화 id(`TmdbMovieDto.id`)입니다.
  final int movieId;
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    // 코멘트는 선택 항목이라 비어 있으면 빈 문자열 대신 생략합니다.
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

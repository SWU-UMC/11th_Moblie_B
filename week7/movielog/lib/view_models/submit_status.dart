/// 쓰기 요청(회원가입, 평점 등록) 상태
enum SubmitStatus { idle, submitting, success, error }

/// 쓰기 실패를 Dialog까지 올릴 때 쓰는 예외
/// Dialog는 Dio를 몰라도 message만 보여주면 됨
class SubmitFailure implements Exception {
  const SubmitFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

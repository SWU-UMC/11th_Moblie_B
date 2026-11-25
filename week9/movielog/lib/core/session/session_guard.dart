/// 지금 도착한 응답이 "현재 로그인 세션"의 것인지 판정
/// accountId는 GET me로 확인한 email (memberId 추측 안 함)
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  /// AuthSessionBridge가 검증된 새 세션 시작할 때만 호출
  /// 화면·ViewModel·build에서 부르지 않음
  int startSession(String accountId) {
    _accountId = accountId;
    // 같은 계정이어도 토큰 새로 받으면 새 세션
    return ++_generation;
  }

  void invalidate() {
    _accountId = null;
    _generation++;
  }

  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}

/// 9주차 목록 화면 상태 (즐겨찾기·영화 목록·검색)
enum LoadPhase {
  /// 아직 요청 안 함 (검색 화면 첫 진입)
  idle,

  /// 첫 로딩 (조건 바뀐 새 첫 page 포함)
  loading,

  /// 보여줄 목록 있음
  ready,

  /// 요청 성공했는데 결과 없음
  empty,

  /// 첫 조회 실패
  error,
}

// 다음 page 불러오는 중엔 ready 목록 안 지우고
// ViewModel의 isLoadingMore로 따로 구분

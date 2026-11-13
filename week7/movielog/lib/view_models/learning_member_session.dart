import 'package:flutter/foundation.dart';

/// 회원가입으로 받은 memberId 보관 (학습용)
/// 메모리에만 있어서 앱 재시작하면 사라짐
/// memberId 안다고 인증된 건 아님 → JWT 주차에 토큰으로 바꿀 예정
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession({this.memberId, this.nickname});

  int? memberId;
  String? nickname;

  void setMember(int id, {String? nickname}) {
    memberId = id;
    this.nickname = nickname;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    nickname = null;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

/// 회원가입으로 받은 학습용 memberId를 앱 전체에서 함께 읽습니다.
///
/// 메모리 안에만 있으므로 앱을 다시 시작하면 사라집니다.
/// memberId를 알고 있다는 것은 인증이 아닙니다. JWT 주차에는 토큰으로 회원을 식별합니다.
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession({this.memberId});

  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}

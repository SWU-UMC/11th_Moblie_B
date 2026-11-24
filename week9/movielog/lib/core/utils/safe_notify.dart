import 'package:flutter/foundation.dart';

/// 화면이 사라진(dispose) 뒤엔 notifyListeners 안 부르게 막는 mixin
/// 늦게 온 응답이 dispose된 ViewModel에 알림 보내서 에러 나는 것 방지
mixin SafeNotify on ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }
}

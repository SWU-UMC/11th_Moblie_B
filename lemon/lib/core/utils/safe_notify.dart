import 'package:flutter/foundation.dart';

/// 화면이 사라진(dispose) 뒤에는 notifyListeners()를 호출하지 않도록 막습니다.
///
/// ViewModel에 `with SafeNotify`를 붙이고 notifyListeners() 대신 [notifyIfAlive]를,
/// 결과를 반영하기 전에는 [isDisposed]를 확인합니다.
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

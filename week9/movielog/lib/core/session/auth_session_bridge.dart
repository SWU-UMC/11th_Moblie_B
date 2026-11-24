import 'package:flutter/foundation.dart';

import 'session_guard.dart';

/// AuthViewModel 상태 변화를 SessionGuard에 전달만 함
/// 인증 상태의 기준은 8주차 AuthViewModel 그대로
class AuthSessionBridge {
  AuthSessionBridge({
    required this.authSignals,
    required this.sessionVersion,
    required this.verifiedEmail,
  }) {
    authSignals.addListener(_sync);
    _sync();
  }

  final Listenable authSignals;
  final int Function() sessionVersion;

  /// signedIn이고 GET me 끝나서 member 생기기 전까진 null
  final String? Function() verifiedEmail;

  final guard = SessionGuard();
  int? _seenVersion;
  String? _seenEmail;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final version = sessionVersion();
    final email = verifiedEmail();
    // 닉네임 수정 같은 알림은 version·email 그대로라 세션 안 바뀜
    if (version == _seenVersion && email == _seenEmail) return;
    _seenVersion = version;
    _seenEmail = email;
    guard.invalidate();
    if (email != null) guard.startSession(email);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    authSignals.removeListener(_sync);
    guard.invalidate();
  }
}

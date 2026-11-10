import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../data/services/member_check_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);
  final MemberCheckService _service;
  bool _disposed = false;

  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;
  String _currentNickname = '';
  String? _duplicatedNickname;
  int _nicknameVersion = 0;
  bool _validNickname(String value) => value.trim().length >= 2;
  bool get canCheckNickname =>
      !_disposed &&
      _validNickname(_currentNickname) &&
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;
  void onNicknameChanged(String value) {
    _currentNickname = value.trim();
    _nicknameVersion++;
    final duplicate =
        _duplicatedNickname != null && _currentNickname == _duplicatedNickname;
    nicknameCheckStatus = duplicate ? CheckStatus.duplicated : CheckStatus.idle;
    nicknameErrorText = duplicate ? '이미 사용 중인 닉네임입니다.' : null;
    if (!_disposed) notifyListeners();
  }

  Future<void> checkNickname(String value) async {
    final requested = value.trim();
    if (!canCheckNickname || requested != _currentNickname) return;
    final version = ++_nicknameVersion;
    nicknameCheckStatus = CheckStatus.checking;
    nicknameErrorText = null;
    notifyListeners();
    try {
      final available = await _service.checkNickname(requested);
      if (_disposed ||
          version != _nicknameVersion ||
          requested != _currentNickname) {
        return;
      }
      nicknameCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      nicknameErrorText = available ? null : '이미 사용 중인 닉네임입니다.';
      if (!available) _duplicatedNickname = requested;
    } on DioException {
      if (_disposed ||
          version != _nicknameVersion ||
          requested != _currentNickname) {
        return;
      }
      nicknameCheckStatus = CheckStatus.error;
      nicknameErrorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    if (!_disposed && version == _nicknameVersion) notifyListeners();
  }

  CheckStatus emailCheckStatus = CheckStatus.idle;
  String? emailErrorText;
  String _currentEmail = '';
  String? _duplicatedEmail;
  int _emailVersion = 0;
  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  bool get canCheckEmail =>
      !_disposed &&
      _validEmail(_currentEmail) &&
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;
  void onEmailChanged(String value) {
    _currentEmail = value.trim();
    _emailVersion++;
    final duplicate =
        _duplicatedEmail != null && _currentEmail == _duplicatedEmail;
    emailCheckStatus = duplicate ? CheckStatus.duplicated : CheckStatus.idle;
    emailErrorText = duplicate ? '이미 사용 중인 이메일입니다.' : null;
    if (!_disposed) notifyListeners();
  }

  Future<void> checkEmail(String value) async {
    final requested = value.trim();
    if (!canCheckEmail || requested != _currentEmail) return;
    final version = ++_emailVersion;
    emailCheckStatus = CheckStatus.checking;
    emailErrorText = null;
    notifyListeners();
    try {
      final available = await _service.checkEmail(requested);
      if (_disposed || version != _emailVersion || requested != _currentEmail) {
        return;
      }
      emailCheckStatus = available
          ? CheckStatus.available
          : CheckStatus.duplicated;
      emailErrorText = available ? null : '이미 사용 중인 이메일입니다.';
      if (!available) _duplicatedEmail = requested;
    } on DioException {
      if (_disposed || version != _emailVersion || requested != _currentEmail) {
        return;
      }
      emailCheckStatus = CheckStatus.error;
      emailErrorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    if (!_disposed && version == _emailVersion) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nicknameVersion++;
    _emailVersion++;
    super.dispose();
  }
}

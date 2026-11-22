import '../data/models/create_member_request.dart';
import 'submit_status.dart';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../data/services/sign_up_service.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);
  final SignUpService _service;
  bool _disposed = false;

  CheckStatus nicknameCheckStatus = CheckStatus.idle;
  String? nicknameErrorText;
  String _currentNickname = '';
  String? _duplicatedNickname;
  int _nicknameVersion = 0;
  bool _validNickname(String value) =>
      value.trim().length >= 2 && value.trim().length <= 12;
  bool get canCheckNickname =>
      !_disposed &&
      submitStatus != SubmitStatus.submitting &&
      _validNickname(_currentNickname) &&
      nicknameCheckStatus != CheckStatus.checking &&
      nicknameCheckStatus != CheckStatus.duplicated;
  void onNicknameChanged(String value) {
    if (submitStatus == SubmitStatus.submitting) return;
    snackbarMessage = null;
    passwordErrorText = null;
    submitStatus = SubmitStatus.idle;
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
    if (!_disposed &&
        submitStatus != SubmitStatus.submitting &&
        version == _nicknameVersion) {
      notifyListeners();
    }
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
      submitStatus != SubmitStatus.submitting &&
      _validEmail(_currentEmail) &&
      emailCheckStatus != CheckStatus.checking &&
      emailCheckStatus != CheckStatus.duplicated;
  void onEmailChanged(String value) {
    if (submitStatus == SubmitStatus.submitting) return;
    snackbarMessage = null;
    passwordErrorText = null;
    submitStatus = SubmitStatus.idle;
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
    if (!_disposed &&
        submitStatus != SubmitStatus.submitting &&
        version == _emailVersion) {
      notifyListeners();
    }
  }

  SubmitStatus submitStatus = SubmitStatus.idle;
  int? createdMemberId;
  String? passwordErrorText;
  String? snackbarMessage;
  void onPasswordChanged() {
    passwordErrorText = null;
    snackbarMessage = null;
    if (submitStatus != SubmitStatus.submitting) {
      submitStatus = SubmitStatus.idle;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (_disposed ||
        submitStatus == SubmitStatus.submitting ||
        nicknameCheckStatus != CheckStatus.available ||
        emailCheckStatus != CheckStatus.available ||
        request.nickname.trim() != _currentNickname ||
        request.email.trim() != _currentEmail) {
      return;
    }
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();
    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      if (!response.isSuccess || id == null || id < 1) {
        throw StateError('가입 결과에 memberId가 없습니다.');
      }
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } catch (_) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nicknameVersion++;
    _emailVersion++;
    super.dispose();
  }
}

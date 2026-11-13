import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

/// 중복 확인 상태 (버튼 활성화, 에러 표시 둘 다 이 값 기준)
enum CheckStatus {
  /// 확인 전 or 입력 바뀌어서 초기화됨
  idle,

  /// 확인 중
  checking,

  /// 사용 가능
  available,

  /// 중복 (available: false)
  duplicated,

  /// 통신 실패
  error,
}

/// 칸 하나의 중복 확인 상태 (닉네임/이메일 따로 관리)
class _CheckField {
  _CheckField({required this.duplicatedMessage});

  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 현재 입력값 (trim)
  String current = '';

  /// 중복이었던 값들 → 다시 입력하면 API 안 부르고 바로 에러
  final Set<String> duplicatedValues = {};

  /// 입력 바뀌면 +1 해서 이전 응답 무시
  int requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;
}

/// 회원가입 ViewModel (닉네임/이메일 중복 확인 + 가입 POST)
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  static const checkFailedMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';

  final SignUpService _service;

  final _nickname = _CheckField(duplicatedMessage: '이미 사용 중인 닉네임입니다.');
  final _email = _CheckField(duplicatedMessage: '이미 사용 중인 이메일입니다.');

  bool _disposed = false;

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답에서 읽은 실제 id
  int? createdMemberId;

  /// 서버 400 중 비밀번호 형식 오류 → 비밀번호 칸 errorText
  String? passwordErrorText;

  /// 어느 칸에도 못 붙이는 오류 (409 등) → Snackbar
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  /// 둘 다 사용 가능
  bool get isDuplicateCheckDone =>
      _nickname.status == CheckStatus.available &&
      _email.status == CheckStatus.available;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  Future<void> checkNickname(String value) =>
      _check(_nickname, value, _service.checkNickname);
  Future<void> checkEmail(String value) =>
      _check(_email, value, _service.checkEmail);

  void _onChanged(_CheckField field, String value) {
    final trimmed = value.trim();
    if (trimmed == field.current) return;
    field.current = trimmed;
    field.requestVersion++; // 이전 응답 무시
    snackbarMessage = null; // 이전 가입 실패 결과도 같이 무효화

    if (field.duplicatedValues.contains(trimmed)) {
      // 중복이었던 값이면 API 안 부르고 바로 에러
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }
    _notify();
  }

  Future<void> _check(
    _CheckField field,
    String value,
    Future<bool> Function(String) request,
  ) async {
    final requested = value.trim();
    field.current = requested;
    if (requested.isEmpty || !field.canCheck) return;

    final version = ++field.requestVersion;
    field.status = CheckStatus.checking;
    field.errorText = null;
    _notify();

    try {
      final available = await request(requested);
      if (_isStale(field, version, requested)) return;
      if (available) {
        field.status = CheckStatus.available;
        field.errorText = null;
      } else {
        field.status = CheckStatus.duplicated;
        field.errorText = field.duplicatedMessage;
        field.duplicatedValues.add(requested);
      }
    } on DioException catch (error) {
      if (_isStale(field, version, requested)) return;
      debugPrint('중복 확인 실패: ${error.type.name} ${error.response?.statusCode}');
      // 통신 실패는 중복이랑 다른 문구
      field.status = CheckStatus.error;
      field.errorText = checkFailedMessage;
    }
    _notify();
  }

  /// 가입 POST
  /// 중복 확인 뒤에 다른 사람이 같은 값으로 가입할 수 있어서 409가 최종 중복 결과
  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      // memberId 없으면 가입 완료로 안 봄 (계약 오류)
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final status = error.response?.statusCode;
      final message = writeSignUpErrorMessage(error);
      debugPrint('회원가입 실패: $status');
      if (status == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
        if (status == 409) _applyFinalConflict(message);
      }
    } on StateError {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    _notify();
  }

  /// 최종 409면 해당 칸을 중복 상태로 되돌림 → 가입하기 다시 비활성화
  /// 서버는 이메일 먼저 검사해서 이메일 중복이면 닉네임은 안 알려줌
  void _applyFinalConflict(String message) {
    final field = message.contains('이메일')
        ? _email
        : message.contains('닉네임')
        ? _nickname
        : null;
    if (field == null) return;
    field.status = CheckStatus.duplicated;
    field.errorText = field.duplicatedMessage;
    field.duplicatedValues.add(field.current);
  }

  bool _isStale(_CheckField field, int version, String requested) =>
      _disposed ||
      version != field.requestVersion ||
      field.current != requested;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.requestVersion++;
    _email.requestVersion++;
    super.dispose();
  }
}

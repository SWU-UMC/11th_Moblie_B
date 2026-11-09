import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 중복 확인 한 칸(닉네임 또는 이메일)의 상태입니다.
enum CheckStatus {
  /// 아직 확인하지 않았거나, 입력이 바뀌어 이전 결과가 무효화된 상태입니다.
  idle,

  /// 요청이 진행 중인 상태입니다.
  checking,

  /// 서버가 사용 가능하다고 응답한 상태입니다.
  available,

  /// 서버가 이미 사용 중이라고 응답한 상태입니다. (available: false)
  duplicated,

  /// 통신 자체가 실패한 상태입니다. (DioException 등)
  error,
}

/// 회원가입 화면의 닉네임·이메일 중복 확인과 가입 요청 상태를 관리합니다.
/// 두 입력란의 결과가 서로 영향을 주지 않도록 중복 확인 상태를 필드별로 따로 둡니다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service)
    : _nickname = _DuplicateCheck(
        request: _service.checkNickname,
        duplicatedText: '이미 사용 중인 닉네임입니다.',
      ),
      _email = _DuplicateCheck(
        request: _service.checkEmail,
        duplicatedText: '이미 사용 중인 이메일입니다.',
      );

  final SignUpService _service;
  final _DuplicateCheck _nickname;
  final _DuplicateCheck _email;
  bool _disposed = false;

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답에서 읽은 실제 memberId입니다.
  int? createdMemberId;

  /// 서버가 비밀번호 형식을 거부한 400입니다. 비밀번호 입력칸에 붙입니다.
  String? passwordErrorText;

  /// 입력칸 하나에 붙일 수 없는 오류(409, 그 밖의 400, 통신 실패)입니다. Snackbar로 한 번 보여줍니다.
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  /// 비밀번호를 고치면 서버가 거부했던 이전 오류를 지웁니다.
  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    notifyListeners();
  }

  Future<void> checkNickname(String value) => _check(_nickname, value);
  Future<void> checkEmail(String value) => _check(_email, value);

  /// 입력이 바뀌면 이전 중복 확인 결과와 서버 오류를 함께 무효화합니다.
  void _onChanged(_DuplicateCheck field, String value) {
    field.onChanged(value);
    snackbarMessage = null;
    if (submitStatus == SubmitStatus.error) submitStatus = SubmitStatus.idle;
    if (!_disposed) notifyListeners();
  }

  /// 가입 요청을 보냅니다. 비밀번호는 로그에 남기지 않습니다.
  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();

    try {
      final response = await _service.signUp(request);
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      submitStatus = SubmitStatus.error;
      final status = error.response?.statusCode;
      final message = writeSignUpErrorMessage(error);
      if (status == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
        // 중복 확인 뒤 다른 사람이 먼저 가입했다면, 해당 칸을 다시 "중복"으로 되돌립니다.
        if (status == 409) _markConflict(message, request);
      }
    } catch (error) {
      // 201인데 memberId가 없거나 형식이 다른 경우입니다. 가입 완료로 표시하지 않습니다.
      debugPrint('회원가입 응답 확인 실패: ${error.runtimeType}');
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  /// 서버가 이메일을 먼저 검사하므로 409 message에 담긴 쪽만 중복으로 표시합니다.
  void _markConflict(String message, CreateMemberRequest request) {
    if (message.contains('이메일')) _email.markDuplicated(request.email);
    if (message.contains('닉네임')) _nickname.markDuplicated(request.nickname);
  }

  Future<void> _check(_DuplicateCheck field, String value) async {
    final version = field.start(value);
    if (version == null) return;
    notifyListeners();

    final changed = await field.finish(version, isDisposed: () => _disposed);
    if (changed && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.invalidate();
    _email.invalidate();
    super.dispose();
  }
}

/// 입력란 하나의 중복 확인 상태와 무효화 규칙입니다.
class _DuplicateCheck {
  _DuplicateCheck({required this.request, required this.duplicatedText});

  final Future<bool> Function(String value) request;
  final String duplicatedText;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 서버가 "중복"이라고 답한 값들입니다. 다시 입력하면 API 없이 바로 에러로 보여줍니다.
  /// (서버 상태는 바뀔 수 있으므로 최종 기준은 회원가입 요청의 409입니다.)
  final _duplicatedValues = <String>{};
  String _current = '';
  String _requested = '';
  int _requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;

  void onChanged(String value) {
    _current = value.trim();
    // 입력이 바뀌면 기다리던 이전 응답을 무시합니다.
    invalidate();
    if (_duplicatedValues.contains(_current)) {
      status = CheckStatus.duplicated;
      errorText = duplicatedText;
    } else {
      status = CheckStatus.idle;
      errorText = null;
    }
  }

  void invalidate() => _requestVersion++;

  /// 가입 요청의 409로 중복이 확정된 값을 기록합니다.
  void markDuplicated(String value) {
    final duplicated = value.trim();
    _duplicatedValues.add(duplicated);
    if (_current != duplicated) return;
    invalidate();
    status = CheckStatus.duplicated;
    errorText = duplicatedText;
  }

  /// 요청을 시작할 수 있으면 상태를 checking으로 바꾸고 요청 버전을 돌려줍니다.
  int? start(String value) {
    final requested = value.trim();
    if (requested.isEmpty || requested != _current || !canCheck) return null;
    _requested = requested;
    status = CheckStatus.checking;
    errorText = null;
    return ++_requestVersion;
  }

  /// 응답을 반영했으면 true입니다. 그사이 입력이 바뀌었거나 화면이 사라졌으면 무시합니다.
  Future<bool> finish(
    int version, {
    required bool Function() isDisposed,
  }) async {
    final requested = _requested;
    bool isStale() =>
        isDisposed() || version != _requestVersion || _current != requested;

    try {
      final available = await request(requested);
      if (isStale()) return false;
      if (available) {
        status = CheckStatus.available;
        errorText = null;
      } else {
        status = CheckStatus.duplicated;
        errorText = duplicatedText;
        _duplicatedValues.add(requested);
      }
    } catch (error) {
      // 통신 실패와 응답 파싱 실패는 "중복"과 다른 문구로 보여줍니다.
      debugPrint('중복 확인 실패: $error');
      if (isStale()) return false;
      status = CheckStatus.error;
      errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    return true;
  }
}

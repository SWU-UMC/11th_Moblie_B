import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

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

/// 회원가입 화면의 닉네임·이메일 중복 확인 상태를 관리합니다.
/// 두 입력란의 결과가 서로 영향을 주지 않도록 상태를 필드별로 따로 둡니다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(MemberCheckService service)
    : _nickname = _DuplicateCheck(
        request: service.checkNickname,
        duplicatedText: '이미 사용 중인 닉네임입니다.',
      ),
      _email = _DuplicateCheck(
        request: service.checkEmail,
        duplicatedText: '이미 사용 중인 이메일입니다.',
      );

  final _DuplicateCheck _nickname;
  final _DuplicateCheck _email;
  bool _disposed = false;

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);
  void onEmailChanged(String value) => _onChanged(_email, value);

  Future<void> checkNickname(String value) => _check(_nickname, value);
  Future<void> checkEmail(String value) => _check(_email, value);

  void _onChanged(_DuplicateCheck field, String value) {
    field.onChanged(value);
    if (!_disposed) notifyListeners();
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

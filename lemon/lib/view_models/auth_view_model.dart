import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// 앱 전체의 로그인 상태입니다. Router가 이 값만 보고 화면을 정합니다.
enum AuthStatus {
  /// 앱 시작 직후 저장된 토큰을 읽고 GET me로 검증하는 중입니다. (Splash)
  initializing,

  /// 로그인하지 않았거나, 로그아웃·세션 만료로 정리된 상태입니다.
  signedOut,

  /// 로그인 요청 중입니다. 로그인 화면에 머뭅니다.
  authenticating,

  /// 로그인됐습니다. 보호 화면에 들어갈 수 있습니다.
  signedIn,

  /// 네트워크·저장소 문제로 세션을 확인하지 못했습니다. 토큰은 지우지 않고 재시도를 기다립니다.
  retryRequired,
}

/// 내 정보(GET me) 로딩 상태입니다. 인증 상태와 따로 둡니다.
enum MemberLoadStatus { idle, loading, success, error }

/// 로그인·세션 복원·로그아웃·세션 만료를 한곳에서 관리합니다.
///
/// - 토큰 문자열이 있다는 이유만으로 signedIn을 확정하지 않습니다. (재시작은 GET me 검증 후)
/// - 로그인 실패(AUTH401_1)와 보호 요청의 만료(AUTH401_2/3/4)를 같은 처리로 묶지 않습니다.
/// - 이전 세션에서 늦게 도착한 응답이 새 세션을 바꾸지 않도록 [sessionVersion]을 확인합니다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;

  /// 로그인 화면·Splash에 보여줄 문구입니다. (로그인 실패, 세션 확인 실패 등)
  String? message;

  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// 내 정보를 불러오지 못했을 때의 문구입니다. 로그인 문구와 섞지 않습니다.
  String? memberMessage;

  /// 세션 만료로 로그아웃됐을 때만 켜집니다. 로그인 화면이 Snackbar를 한 번 보여주고 끕니다.
  /// 직접 로그아웃·로그인 실패에서는 켜지지 않습니다.
  bool sessionExpired = false;

  /// 저장된 토큰을 지우는 중입니다. 이 동안 새 로그인을 막습니다.
  bool storageCleanupInProgress = false;

  /// 로그아웃·만료 때 저장된 토큰 삭제가 실패했습니다.
  /// 토큰이 남아 있으면 재시작 때 끝낸 세션이 복원되므로, 삭제가 성공할 때까지
  /// 로그아웃을 끝난 것으로 보지 않고 로그인 화면에서 [retryTokenCleanup]을 제공합니다.
  bool tokenCleanupFailed = false;

  int _sessionVersion = 0;

  /// 로그인·복원·로그아웃마다 1씩 오릅니다. 요청 시작 때 값과 응답 때 값이 다르면 버립니다.
  int get sessionVersion => _sessionVersion;

  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool get isSignedIn => status == AuthStatus.signedIn;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  late final _statusNotifier = ValueNotifier<AuthStatus>(status);

  /// Router의 refreshListenable용입니다. 로그인 상태(status)가 바뀔 때만 알립니다.
  /// 닉네임 수정·내 정보 로딩처럼 상태가 그대로인 알림으로 redirect를 다시 돌리면
  /// 진행 중인 화면 이동(pop 등)과 겹쳐 이전 위치로 되돌아갈 수 있습니다.
  ValueListenable<AuthStatus> get statusListenable => _statusNotifier;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
    _statusNotifier.value = status;
  }

  /// 앱 시작 시 저장된 토큰을 읽고, 있으면 GET me로 서버 검증을 받은 뒤에만 signedIn입니다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || tokenCleanupFailed || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    _resetMember();
    _notify();

    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verified = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verified;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      final code = apiErrorCode(error);
      // 토큰 무효·만료이거나, 토큰의 회원이 사라졌으면 저장된 토큰을 지웁니다.
      if (sessionExpiredCodes.contains(code) || code == 'MEMBER404_1') {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠시 끊긴 것만으로 유효한 토큰을 지우지 않습니다.
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 네트워크를 확인하고 다시 시도해 주세요.';
    } catch (error) {
      if (!_isCurrent(version)) return;
      debugPrint('세션 복원 실패: ${error.runtimeType}');
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    _notify();
  }

  /// 로그인 API 성공 → 토큰 저장 → signedIn. 내 정보는 탭 화면(MainNavigationShell)이 불러옵니다.
  /// 비밀번호는 요청에만 쓰고 저장하지 않습니다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        tokenCleanupFailed ||
        status == AuthStatus.authenticating) {
      return;
    }
    status = AuthStatus.authenticating;
    _resetMember();
    sessionExpired = false;
    message = null;
    final version = ++_sessionVersion;
    _notify();

    try {
      final result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isCurrent(version)) return;
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      // 로그인 Form의 오류입니다. 세션 만료 Snackbar(sessionExpired)는 켜지 않습니다.
      message = switch (apiErrorCode(error)) {
        'AUTH401_1' => '이메일 또는 비밀번호를 확인해 주세요.',
        'COMMON400' => apiErrorMessage(error) ?? '입력값을 확인해 주세요.',
        _ => '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      };
    } catch (error) {
      if (!_isCurrent(version)) return;
      debugPrint('로그인 처리 실패: ${error.runtimeType}');
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  /// 내 정보를 한 번 불러와 [member]에 보관합니다. 마이페이지·프로필 수정이 같은 값을 씁니다.
  /// 앱 재시작은 restoreSession()이 이미 채웠으므로 다시 부르지 않습니다.
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    memberMessage = null;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답은 버립니다.
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error) ||
          apiErrorCode(error) == 'MEMBER404_1') {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패는 로그아웃하지 않고 재시도할 수 있게 둡니다.
      memberStatus = MemberLoadStatus.error;
      memberMessage = '내 정보를 불러오지 못했어요.';
    } catch (error) {
      if (!_isCurrent(version)) return;
      debugPrint('내 정보 응답 확인 실패: ${error.runtimeType}');
      memberStatus = MemberLoadStatus.error;
      memberMessage = '내 정보를 불러오지 못했어요.';
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 교체합니다. GET me를 다시 부르지 않습니다.
  void updateMember(MemberInfo updated, {required int sessionVersion}) {
    if (!_isCurrent(sessionVersion) || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  /// 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때 부릅니다.
  ///
  /// [sessionVersion]은 그 요청을 보낼 때의 값입니다. 이미 로그아웃했거나 새로 로그인한 뒤
  /// 늦게 도착한 401이라면 아무것도 하지 않습니다. 동시에 여러 401이 와도 한 번만 정리합니다.
  Future<void> expireSession({required int sessionVersion}) async {
    if (!_isCurrent(sessionVersion) || status != AuthStatus.signedIn) return;
    await _clearCurrentSession(expired: true);
  }

  /// 사용자가 직접 누른 로그아웃입니다. 만료 Snackbar는 켜지 않습니다.
  /// 기기의 토큰과 메모리 세션만 비우며, 서버에서 토큰이 즉시 폐기된다고 보장하지 않습니다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  /// 로그인 화면이 만료 안내를 보여준 뒤 부릅니다. 같은 Snackbar가 반복되지 않게 합니다.
  void consumeSessionExpired() {
    sessionExpired = false;
  }

  /// 개발용(Debug 빌드 전용): 저장된 토큰을 서버가 거부하는 값으로 바꿉니다.
  /// 만료를 기다리지 않고 다음 보호 요청에서 실제 서버의 AUTH401_3을 받아 보기 위한 것입니다.
  /// 메모리 상태는 바꾸지 않으므로, 다음 요청(또는 앱 재시작)이 401을 받아야 로그아웃됩니다.
  Future<void> debugInvalidateStoredToken() async {
    if (!kDebugMode || _disposed || status != AuthStatus.signedIn) return;
    await _storage.saveAccessToken('movielog-debug-invalid-token');
  }

  /// 세션 버전 증가 → 메모리 정리 → signedOut(→ Router가 /login으로 이동) → 저장된 토큰 삭제.
  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    _resetMember();
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();

    try {
      // 진행 중이던 토큰 저장이 끝난 뒤 지워야 삭제 후에 토큰이 다시 써지지 않습니다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했어도 삭제는 시도합니다.
      }
      await _storage.deleteAccessToken();
      tokenCleanupFailed = false;
    } catch (_) {
      tokenCleanupFailed = true;
      if (_isCurrent(version)) message = _cleanupFailedMessage;
    } finally {
      storageCleanupInProgress = false;
      _notify();
    }
  }

  static const _cleanupFailedMessage = '저장된 로그인 정보를 지우지 못했어요. 다시 시도해 주세요.';

  /// 실패한 토큰 삭제를 다시 시도합니다. 성공해야 로그아웃이 끝납니다.
  Future<void> retryTokenCleanup() async {
    if (_disposed || !tokenCleanupFailed || storageCleanupInProgress) return;
    storageCleanupInProgress = true;
    message = null;
    _notify();
    try {
      await _storage.deleteAccessToken();
      tokenCleanupFailed = false;
    } catch (_) {
      message = _cleanupFailedMessage;
    } finally {
      storageCleanupInProgress = false;
      _notify();
    }
  }

  void _resetMember() {
    member = null;
    memberStatus = MemberLoadStatus.idle;
    memberMessage = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    _statusNotifier.dispose();
    super.dispose();
  }
}

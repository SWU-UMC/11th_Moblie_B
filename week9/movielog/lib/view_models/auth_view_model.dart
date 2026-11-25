import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';
import 'session_ratings.dart';

/// 앱 인증 상태
/// initializing: 저장소·GET me 확인 중 (Splash)
/// retryRequired: 확인 실패 (네트워크 등) → 토큰 안 지우고 재시도
enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

/// 내 정보(GET me) 불러오기 상태
enum MemberLoadStatus { idle, loading, success, error }

/// 로그인·세션 복원·만료·로그아웃을 한곳에서 관리
/// 화면 이동은 안 함 → status만 바꾸면 Router redirect가 보냄
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._authApi,
    this._memberApi,
    this._storage, {
    this._sessionRatings,
  });

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;
  final SessionRatings? _sessionRatings;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// 로그인 Form·Splash에 보여줄 문구
  String? message;

  /// 만료로 쫓겨났을 때만 true (직접 로그아웃·로그인 실패는 false)
  /// 로그인 화면이 Snackbar 띄우고 consume함
  bool sessionExpired = false;

  /// 토큰 지우는 중엔 새 로그인 막음
  bool storageCleanupInProgress = false;

  /// 로그인·로그아웃·만료마다 +1
  /// 이전 세션에서 늦게 온 응답이 새 세션 덮지 않게 비교용
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool get isSignedIn => status == AuthStatus.signedIn;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 시작: 토큰 읽기 → GET me 성공해야 signedIn
  /// 토큰 있다는 것만으로 signedIn 안 함 (만료 토큰일 수 있음)
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
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
      if (isSessionExpired(error)) {
        // 토큰 무효·만료 → 지우고 로그인으로
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패로 유효한 토큰 지우면 안 됨 → 재시도
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요.';
    }
    if (_isCurrent(version)) _notify();
  }

  /// 로그인 → 토큰 저장 → signedIn
  /// 내 정보는 MainScreen이 loadMember()로 불러옴 (여기서 GET me 중복 안 함)
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    final version = ++_sessionVersion;
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    // 다른 계정으로 로그인해도 이전 세션 평점 안 보이게
    _sessionRatings?.clear();
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
      message = _loginErrorMessage(error);
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  /// 로그인 실패 문구: 비밀번호 틀림 / 입력 형식 / 네트워크 따로
  String _loginErrorMessage(DioException error) {
    switch (apiErrorCode(error)) {
      case 'AUTH401_1':
        // Form 오류 (세션 만료 아님 → sessionExpired 안 켬)
        return '이메일 또는 비밀번호를 확인해 주세요.';
      case 'COMMON400':
        return apiErrorMessage(error) ?? '입력값을 확인해 주세요.';
    }
    return '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }

  /// 내 정보 GET me (MainScreen 진입 시 한 번)
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦은 응답 무시
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpired(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패는 로그아웃 안 함 → 재시도 가능
      memberStatus = MemberLoadStatus.error;
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 교체 (GET me 다시 안 부름)
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    _notify();
  }

  /// 다른 ViewModel이 보호 API에서 AUTH401_2/3/4 받았을 때 호출
  /// 그 요청 보낼 때의 version 넘기면 이전 세션의 늦은 401은 무시
  Future<void> expireSession({int? version}) async {
    if (version != null && version != _sessionVersion) return;
    await _clearCurrentSession(expired: true);
  }

  /// 직접 로그아웃 → 만료 Snackbar 안 띄움
  /// 클라이언트 토큰만 지움 (서버 토큰 폐기 보장 아님)
  Future<void> logout() => _clearCurrentSession(expired: false);

  /// 로그인 화면이 Snackbar 띄우기 전에 먼저 끔 (중복 표시 방지)
  void consumeSessionExpired() {
    sessionExpired = false;
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    // 동시 401 여러 개 와도 이미 로그아웃 상태면 한 번만 처리
    if (expired && status == AuthStatus.signedOut) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _sessionRatings?.clear();
    _notify();

    try {
      // 저장 중이던 토큰 있으면 끝난 뒤 지움 (지운 뒤 저장되는 것 방지)
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장 실패여도 삭제는 시도
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱을 다시 실행해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}

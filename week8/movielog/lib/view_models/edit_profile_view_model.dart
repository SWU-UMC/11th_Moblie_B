import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필(닉네임) 수정
/// 입력칸 문제(길이·중복)는 nicknameError, 나머지(네트워크)는 message → Snackbar
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  /// 서버 규칙(2~12자)이랑 같은 검사를 먼저 함
  static String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.isEmpty) return '닉네임을 입력해 주세요.';
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  /// Challenge: 뒤로가기 확인 Dialog 띄울지 판단
  bool hasChanges(String input) {
    final current = _auth.member?.nickname;
    return current != null && input.trim() != current;
  }

  /// 입력 바뀌면 이전 오류 지움
  void onNicknameChanged() {
    if (nicknameError == null && message == null) return;
    nicknameError = null;
    message = null;
    _notify();
  }

  /// true면 저장 완료 (화면이 Snackbar + 뒤로)
  Future<bool> save(String input) async {
    if (isSaving) return false; // 중복 탭 방지
    final version = _auth.sessionVersion;
    if (_disposed || !_auth.isSignedIn || _auth.member == null) return false;

    final nickname = input.trim();
    nicknameError = validateNickname(nickname);
    message = null;
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임이랑 같으면 요청 없이 완료 (자기 닉네임은 409 아님)
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (!_isCurrent(version)) return false;
      _auth.updateMember(updated); // 마이페이지가 바로 새 닉네임 보여줌
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return false;
      status = EditProfileStatus.failure;
      final code = apiErrorCode(error);
      if (sessionExpiredCodes.contains(code)) {
        // 안내·이동은 로그인 화면이랑 Router가 처리
        await _auth.expireSession(version: version);
        return false;
      }
      switch (code) {
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 유지
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
        default:
          // 네트워크 실패는 로그아웃 안 함 → 다시 저장 가능
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.';
      }
    } catch (_) {
      if (!_isCurrent(version)) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  bool _isCurrent(int version) =>
      !_disposed && version == _auth.sessionVersion && _auth.isSignedIn;

  /// 화면 나간 뒤 온 응답이 notify 안 하게 막음
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import '../widgets/max_runes_formatter.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필(닉네임) 수정 화면의 저장 상태입니다.
///
/// 입력칸 문제(길이·중복)는 [nicknameError]로 필드 아래에,
/// 입력과 무관한 문제(네트워크 등)는 [message]로 Snackbar에 보여줍니다.
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  static const minLength = 2;
  static const maxLength = 12;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  /// 서버에 보내기 전에 확인할 수 있는 규칙은 먼저 검사해 불필요한 요청을 줄입니다.
  /// 서버처럼 코드포인트 기준으로 셉니다.
  String? validateNickname(String value) {
    final length = runeLength(value.trim());
    if (length < minLength || length > maxLength) {
      return '닉네임은 $minLength~$maxLength자로 입력해 주세요.';
    }
    return null;
  }

  /// 입력을 고치면 이전 오류를 지웁니다. 입력값 자체는 화면이 그대로 유지합니다.
  void onNicknameChanged() {
    if (nicknameError == null && status != EditProfileStatus.failure) return;
    nicknameError = null;
    if (status == EditProfileStatus.failure) status = EditProfileStatus.idle;
    _notify();
  }

  /// 저장에 성공했으면 true입니다.
  Future<bool> save(String input) async {
    if (isSaving || _disposed) return false; // 중복 탭 방지
    final version = _auth.sessionVersion;
    if (!_auth.isSignedIn || _auth.member == null) return false;

    final nickname = input.trim();
    message = null;
    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료로 처리합니다. (같은 값은 409도 아니지만 보낼 이유가 없습니다)
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    _notify();

    bool isStale() =>
        _disposed || version != _auth.sessionVersion || !_auth.isSignedIn;

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (isStale()) return false;
      _auth.updateMember(updated, sessionVersion: version);
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (isStale()) return false;
      status = EditProfileStatus.failure;
      switch (apiErrorCode(error)) {
        case 'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4':
          // 안내 Snackbar와 이동은 로그인 화면과 Router가 맡습니다.
          await _auth.expireSession(sessionVersion: version);
          return false;
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 유지합니다.
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
        default:
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.'; // 로그아웃하지 않습니다.
      }
    } catch (error) {
      if (isStale()) return false;
      debugPrint('프로필 수정 응답 확인 실패: ${error.runtimeType}');
      status = EditProfileStatus.failure;
      message = '수정 결과를 확인하지 못했어요.';
    }
    _notify();
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

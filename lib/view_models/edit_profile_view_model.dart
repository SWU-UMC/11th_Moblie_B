import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);
  final MemberApiService _memberApi;
  final AuthViewModel _auth;
  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;
  bool _current(int version) =>
      !_disposed &&
      version == _auth.sessionVersion &&
      _auth.status == AuthStatus.signedIn;
  String? validateNickname(String value) =>
      value.trim().length < 2 || value.trim().length > 12
      ? '닉네임은 2~12자로 입력해 주세요.'
      : null;
  Future<bool> save(String input) async {
    final version = _auth.sessionVersion;
    if (!_current(version) ||
        _auth.member == null ||
        status == EditProfileStatus.saving) {
      return false;
    }
    final nickname = input.trim();
    message = null;
    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      notifyListeners();
      return false;
    }
    if (nickname == _auth.member!.nickname) {
      status = EditProfileStatus.success;
      notifyListeners();
      return true;
    }
    status = EditProfileStatus.saving;
    notifyListeners();
    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (!_current(version)) return false;
      _auth.updateMember(updated);
      status = EditProfileStatus.success;
      notifyListeners();
      return true;
    } on DioException catch (error) {
      if (!_current(version)) return false;
      status = EditProfileStatus.failure;
      if (isSessionExpiredError(error)) {
        await _auth.expireSession(expectedVersion: version);
        return false;
      }
      switch (apiErrorCode(error)) {
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.';
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
          await _auth.loadMember(force: true);
        default:
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.';
      }
    } catch (_) {
      if (!_current(version)) return false;
      status = EditProfileStatus.failure;
      message = '프로필 수정 응답을 확인하지 못했어요.';
    }
    if (_current(version)) notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

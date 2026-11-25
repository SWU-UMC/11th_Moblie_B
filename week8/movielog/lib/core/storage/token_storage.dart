import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// accessToken 저장·조회·삭제 규칙을 한곳에 모음
/// 인증 흐름(AuthViewModel)은 어디에 어떻게 저장되는지 몰라도 됨
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// Android Keystore / iOS Keychain 기반 보안 저장소
/// shared_preferences는 평문이라 토큰 저장에 안 씀
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 액세스 토큰(JWT) 저장·조회·삭제를 한곳에 모읍니다.
///
/// 인증 흐름은 이 추상화에만 의존하므로, 테스트에서는 메모리 저장소로 바꿔 끼웁니다.
/// 비밀번호는 어떤 저장소에도 저장하지 않습니다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// iOS Keychain · Android Keystore(암호화된 저장 영역)를 쓰는 실제 구현입니다.
/// 장르 같은 비민감 설정은 계속 shared_preferences에 둡니다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: accessTokenKey, value: token);

  @override
  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: accessTokenKey);
}

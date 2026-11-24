import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);
  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'movielog.access_token';
  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);
  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  @override
  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);
}

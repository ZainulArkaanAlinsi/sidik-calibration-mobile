import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tempat nyimpen token login.
///
/// Pakai secure storage (Keystore di Android), bukan SharedPreferences —
/// token JWT itu sama nilainya kayak password: siapa pun yang punya, bisa
/// jalan sebagai user itu. Jangan pernah ditaruh di plain text.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Dipakai di test — nggak nyentuh Keystore.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

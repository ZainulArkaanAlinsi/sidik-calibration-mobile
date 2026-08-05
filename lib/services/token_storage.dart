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
    : _storage = storage ?? const FlutterSecureStorage(mOptions: _macOs);

  /// macOS: JANGAN pakai data protection keychain (default paket = `true`).
  ///
  /// Keychain jenis itu mewajibkan entitlement `keychain-access-groups`, dan
  /// entitlement itu cuma sah kalau app di-sign pakai sertifikat developer
  /// beneran. Build lokal (`flutter run`/`flutter build macos` tanpa akun
  /// Apple) itu **adhoc**, `TeamIdentifier=not set` — jadi nulis token selalu
  /// gagal dengan errSecMissingEntitlement (-34018).
  ///
  /// Efeknya sempat nyamar parah: `AsyncValue.guard` di `auth_provider.dart`
  /// nelen exception-nya dan layar login nampilin "Nggak bisa nyambung ke
  /// server" — padahal lagi MODE MOCK yang nggak punya server sama sekali.
  /// Berjam-jam kebuang ngoprek backend, IP, dan adb gara-gara pesan itu.
  ///
  /// `false` = keychain klasik, yang nggak nuntut entitlement dan jalan di
  /// build tanpa sertifikat. Android (Keystore), iOS, & Windows nggak kena
  /// opsi ini sama sekali — `mOptions` cuma dibaca di macOS.
  static const _macOs = MacOsOptions(usesDataProtectionKeychain: false);

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

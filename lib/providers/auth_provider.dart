import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import '../services/token_storage.dart';

/// GANTI SATU BARIS INI begitu `POST /api/login` dari backend siap:
/// `MockAuthService()` → `ApiAuthService(ref.watch(apiClientProvider))`.
/// Layar Login & provider di bawah nggak perlu disentuh.
final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

/// User yang lagi login. `null` = belum login.
///
/// `AsyncValue` dipakai supaya UI dapat 3 state gratis: `loading` (lagi cek
/// token / lagi kirim login), `error` (kredensial salah), `data` (sukses) —
/// persis 3 state yang diminta di catatan harian.
final authProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<User?> {
  AuthService get _auth => ref.read(authServiceProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  /// Jalan sekali waktu app dibuka: ada token tersimpan? masih valid?
  @override
  Future<User?> build() async {
    final token = await _storage.read();
    if (token == null) return null;

    try {
      return await _auth.me(token);
    } on AuthException {
      // Token kadaluarsa/dicabut → buang, user balik ke layar login.
      // Jangan lempar error ke UI: ini bukan salahnya user.
      await _storage.clear();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final session = await _auth.login(email: email, password: password);
      await _storage.write(session.token);
      return session.user;
    });
  }

  Future<void> logout() async {
    final token = await _storage.read();
    state = const AsyncValue.loading();

    if (token != null) {
      try {
        await _auth.logout(token);
      } on AuthException {
        // Logout di server gagal? Nggak masalah — yang penting token lokal
        // dibuang, user beneran keluar dari app ini.
      }
    }

    await _storage.clear();
    state = const AsyncValue.data(null);
  }
}

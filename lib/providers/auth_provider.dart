import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import '../services/token_storage.dart';
import 'navigation_provider.dart';

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

  /// [identifier] = Employee ID (mis. `ASM-0001`) atau email.
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final session = await _auth.login(
        identifier: identifier,
        password: password,
      );
      await _storage.write(session.token);
      return session.user;
    });
  }

  /// Daftar akun baru. Sengaja **nggak** ngubah `state` jadi logged-in:
  /// akunnya masih `pending` nunggu approval admin, jadi user tetap di luar.
  /// Lempar [AuthException] kalau gagal — layar Register yang nampilin.
  Future<void> register(RegisterData data) async {
    await _auth.register(data);
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

    // Buang state yang nempel ke sesi lama. Tanpa ini, user berikutnya yang
    // login bakal mendarat di tab terakhir punya user sebelumnya (mis. logout
    // dari Profil → login → langsung di Profil, bukan Dashboard).
    // Nanti pas ada data alat/kalibrasi yang di-cache, provider-nya juga
    // WAJIB di-invalidate di sini — biar data user lama nggak kelihatan sama
    // user baru.
    ref.invalidate(selectedTabProvider);

    state = const AsyncValue.data(null);
  }
}

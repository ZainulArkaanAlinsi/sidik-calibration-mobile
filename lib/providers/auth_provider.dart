import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/user.dart';
import '../services/api_auth_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import '../services/token_storage.dart';
import 'navigation_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Sekarang **nembak API asli** (endpoint auth-nya udah live sejak 14 Jul).
///
/// Mock-nya masih ada buat jaring pengaman: kalau backend lagi mati atau lagi
/// ngoding UI tanpa server, jalanin dengan
/// `flutter run --dart-define=USE_MOCK=true`.
final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useMock) return MockAuthService();
  return ApiAuthService(ref.watch(apiClientProvider));
});

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

  /// Minta link reset password. Sama kayak register: nggak nyentuh `state`
  /// auth, karena user tetap belum login. Layar Reset Password yang nanganin
  /// loading/sukses/error-nya sendiri.
  Future<void> requestPasswordReset(String email) async {
    await _auth.requestPasswordReset(email);
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

  /// Cabut semua sesi di semua perangkat. Balikin jumlah sesi yang kecabut.
  ///
  /// **Gagalnya ditangani beda dari [logout], dan itu disengaja.** Kalau
  /// `logout` gagal di server, token lokal tetap dibuang — user beneran keluar
  /// dari HP ini, dan itu emang yang dia minta.
  ///
  /// `logoutAll` beda: yang dia minta itu "matiin sesi di HP saya yang ilang".
  /// Kalau panggilan ke server gagal, sesi di HP itu **masih hidup**. Ngeluarin
  /// dia dari HP ini doang malah bahaya — layarnya balik ke login, dia ngira
  /// beres, padahal HP yang ilang itu masih bisa dipakai orang. Jadi kalau
  /// gagal: error dilempar, user tetap login di sini, dan dia bisa nyoba lagi.
  Future<int> logoutAll() async {
    final token = await _storage.read();
    if (token == null) {
      throw const AuthException('Sesi kamu udah nggak ada. Login ulang ya.');
    }

    // Sengaja nggak di-`guard`: kalau gagal, biarin exception-nya naik ke layar
    // Profil, dan `state` nggak disentuh sama sekali (user tetap login).
    final dicabut = await _auth.logoutAll(token);

    // Token yang lagi dipakai ikut mati juga di server, jadi buang di sini.
    await _storage.clear();
    ref.invalidate(selectedTabProvider);
    state = const AsyncValue.data(null);

    return dicabut;
  }
}

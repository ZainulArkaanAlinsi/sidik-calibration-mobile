import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Sesi yang tersimpan NGGAK boleh ilang cuma gara-gara servernya lagi nggak
/// kejangkau.
///
/// **Dua keluhan yang ternyata satu bug.** `AuthController.build()` dulu
/// nangkep `on AuthException` — semua-semuanya — lalu ngehapus token. Tapi
/// `ApiClient` ngelempar `AuthException` juga buat kegagalan jaringan:
///
///     on SocketException { throw AuthException('Nggak bisa nyambung...') }
///     catch (_)          { throw AuthException('Server nggak nyaut...') }
///
/// Jadi wifi ngadat sedetik waktu aplikasi dibuka = token dihapus permanen,
/// dan teknisi mesti ngetik ulang kata sandi. "Server nggak nyaut" dan
/// "ke-logout terus" itu satu kejadian: pesannya muncul duluan, penghapusan
/// tokennya nyusul diam-diam.
///
/// Kejadian di macOS MAUPUN Android — yang salah kode bersamanya, bukan
/// penyimpanan platformnya. Makanya yang diuji di sini `AuthController`
/// langsung, bukan lewat layar.
///
/// Yang DIJAGA cuma satu: apa yang tersisa di penyimpanan. Layarnya sendiri
/// tetap jatuh ke Login seperti sebelumnya — sengaja, karena `AsyncError` juga
/// dipakai jalur gagal-login, dan mbedakan keduanya itu pekerjaan tersendiri.
class _AuthGagalJaringan implements AuthService {
  int panggilanMe = 0;

  @override
  Future<User> me(String token) async {
    panggilanMe++;
    // Persis yang dilempar `ApiClient` waktu koneksi mati.
    throw const AuthException('Server nggak nyaut. Coba lagi sebentar.');
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> register(RegisterData data) => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout(String token) => throw UnimplementedError();

  @override
  Future<int> logoutAll(String token) => throw UnimplementedError();
}

/// Server yang BENERAN nolak tokennya — kadaluarsa atau dicabut admin.
class _AuthTokenDitolak extends _AuthGagalJaringan {
  @override
  Future<User> me(String token) async {
    panggilanMe++;
    throw const ApiException('Token nggak berlaku.', status: 401);
  }
}

void main() {
  test('server nggak kejangkau → token TETAP tersimpan', () async {
    final simpanan = InMemoryTokenStorage('token-teknisi');
    final layanan = _AuthGagalJaringan();

    final wadah = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(simpanan),
        authServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(wadah.dispose);

    // Dipantau lewat `listen`, bukan `await ...future`: waktu `build()`
    // ngelempar, future-nya nggak pernah beres di sini dan test-nya nyangkut
    // sampai batas 30 detik. Yang dibutuhin cuma KEADAAN akhirnya.
    wadah.listen(authProvider, (_, _) {});

    final batas = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(batas) && wadah.read(authProvider).isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    // Layarnya tetap jatuh ke Login seperti dulu — itu DISENGAJA, lihat
    // catatan di `AuthController.build()`. Yang diuji di sini bukan layarnya,
    // tapi apa yang tersisa di penyimpanan.
    expect(wadah.read(authProvider).value, isNull);

    expect(
      await simpanan.read(),
      'token-teknisi',
      reason: 'TOKEN KEHAPUS gara-gara jaringan ngadat — ini inti bugnya',
    );
    // Riverpod 3 nyoba ulang sendiri provider yang gagal, jadi angkanya lebih
    // dari sekali — dan itu justru bagus: begitu jaringannya balik, sesinya
    // pulih tanpa teknisi ngapa-ngapain. Yang dijaga di sini cuma bahwa
    // servernya BENERAN ditanya, bukan berapa kali.
    expect(layanan.panggilanMe, greaterThanOrEqualTo(1));
  });

  test('token beneran ditolak server (401) → token DIBUANG, balik ke login',
      () async {
    final simpanan = InMemoryTokenStorage('token-kadaluarsa');
    final layanan = _AuthTokenDitolak();

    final wadah = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(simpanan),
        authServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(wadah.dispose);

    expect(
      await wadah.read(authProvider.future),
      isNull,
      reason: 'token yang ditolak server memang harus mendarat di layar login',
    );

    expect(
      await simpanan.read(),
      isNull,
      reason: 'token yang udah nggak sah jangan ditinggal di HP',
    );
  });

  test('belum pernah masuk → nggak manggil server sama sekali', () async {
    final simpanan = InMemoryTokenStorage(null);
    final layanan = _AuthGagalJaringan();

    final wadah = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(simpanan),
        authServiceProvider.overrideWithValue(layanan),
      ],
    );
    addTearDown(wadah.dispose);

    expect(await wadah.read(authProvider.future), isNull);
    expect(layanan.panggilanMe, 0);
  });
}

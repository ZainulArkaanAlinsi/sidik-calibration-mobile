import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/user.dart';
import '../services/api_auth_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import '../services/token_storage.dart';
import 'avatar_provider.dart';
import 'pendaftaran_push_provider.dart';
import 'navigation_provider.dart';
import 'simpanan_pelanggan_provider.dart';

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
    } on ApiException catch (e) {
      // CUMA penolakan token yang bikin tokennya dibuang.
      //
      // Dulu di sini `on AuthException` — semua-semuanya. Masalahnya
      // `ApiClient` ngelempar AuthException juga buat KEGAGALAN JARINGAN:
      //
      //     on SocketException { throw AuthException('Nggak bisa nyambung...') }
      //     catch (_)          { throw AuthException('Server nggak nyaut...') }
      //
      // Jadi wifi ngadat sedetik waktu aplikasi dibuka = token DIHAPUS, dan
      // orangnya mesti ngetik ulang kata sandinya. Itu dua keluhan yang selama
      // ini dikira terpisah — "server nggak nyaut" dan "ke-logout terus" —
      // padahal satu kejadian: pesan pertama muncul, penghapusan token
      // nyusul diam-diam.
      //
      // Kejadian di macOS MAUPUN Android, karena yang salah kode bersamanya,
      // bukan penyimpanan platformnya.
      if (e.status == 401 || e.status == 403) {
        await _storage.clear();
      }
      return null;
    } on AuthException {
      // Jaringan mati / server nggak nyaut / timeout. Layarnya tetap jatuh ke
      // Login seperti dulu — yang BERUBAH cuma satu: tokennya NGGAK dihapus.
      // Jadi begitu jaringannya balik dan aplikasinya dibuka lagi, sesinya
      // pulih sendiri tanpa teknisi ngetik kata sandi apa pun.
      //
      // Sengaja `return null`, bukan `rethrow`. Sempat kucoba rethrow biar
      // bisa nampilin layar "server nggak kejangkau" dengan tombol coba lagi,
      // dan itu MERUSAK jalur login: gagal login juga menghasilkan
      // `AsyncError`, jadi salah ketik kata sandi ikut kelempar ke layar itu
      // dan pesan kesalahannya ilang. Lima test auth nangkep itu. Layar
      // khusus buat keadaan offline layak dibikin, tapi butuh cara mbedain
      // "gagal verifikasi sesi tersimpan" dari "gagal masuk" — dan itu
      // pekerjaan sendiri, bukan efek samping perbaikan ini.
      return null;
    }
  }

  /// [identifier] = Employee ID (mis. `SDK-0001`) atau email.
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

  /// Set password baru (langkah kedua reset). Nggak nyentuh `state` — user
  /// tetap belum login; abis ini dia login pakai password barunya.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _auth.resetPassword(email: email, newPassword: newPassword);
  }

  Future<void> logout() async {
    final token = await _storage.read();
    state = const AsyncValue.loading();

    if (token != null) {
      // Cabut DULUAN, selagi token akunnya masih ada. Kalau ditaruh sesudah
      // `_storage.clear()`, nggak ada lagi yang bisa dipakai buat memanggil
      // server, dan HP yang dipakai gantian bakal terus nerima kabar kerja
      // orang sebelumnya — nomor sesi & nama alat pelanggan di layar kunci.
      await _cabutTokenPerangkat(token);

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

    await _buangSimpananAkun();

    state = const AsyncValue.data(null);
  }

  /// Buang data akun yang tersimpan DI DISK.
  ///
  /// Provider Riverpod ikut mati sendiri waktu pohon widget pindah ke layar
  /// login (auto-dispose), tapi isi SharedPreferences **nggak ikut sama
  /// sekali**: dia bertahan melewati logout, melewati aplikasi ditutup,
  /// melewati HP dimatikan.
  ///
  /// Satu APK dipakai teknisi dan admin, dan HP lab dipakai gantian — jadi
  /// tanpa ini, nama pelanggan lab sebelumnya muncul di layar orang berikutnya.
  /// Kebocoran antar pelanggan yang nggak ninggalin satu pun error, dan yang
  /// nggak akan ketahuan siapa pun yang mengetes cuma dengan satu akun.
  ///
  /// Dipanggil dari DUA jalur — [logout] dan [logoutAll]. Ketinggalan di salah
  /// satunya bikin "keluarkan sesi saya di semua perangkat" justru meninggalkan
  /// lebih banyak sisa daripada logout biasa.
  ///
  /// Gagalnya didiamkan, sama alasannya dengan pencabutan token push: orang
  /// yang menekan logout harus beneran keluar, apa pun kata penyimpanan
  /// lokalnya.
  Future<void> _buangSimpananAkun() async {
    try {
      await ref.read(simpananPelangganProvider).bersihkan();
    } catch (_) {
      // Lihat docblock: logout nggak boleh gagal gara-gara ini.
    }

    // Kunci avatar GLOBAL yang lama disapu di sini — cuma yang lama.
    //
    // Laci per-orang (`avatar.v1.<id>`) sengaja TIDAK dibuang: beda dari
    // simpanan pelanggan yang bisa diambil ulang dari server, foto profil nggak
    // punya salinan di mana pun. Membuangnya tiap logout bikin teknisi
    // kehilangan fotonya permanen tiap ganti shift. Kebocorannya sudah ditutup
    // bentuk kuncinya — lihat `sapuKunciAvatarLama`.
    //
    // Dipisah try/catch sendiri, bukan digabung ke atas: kalau pembersihan
    // pelanggan gagal, sapuan ini tetap harus jalan.
    try {
      await sapuKunciAvatarLama();
    } catch (_) {
      // Lihat docblock: logout nggak boleh gagal gara-gara ini.
    }
  }

  /// Cabut pendaftaran push perangkat ini.
  ///
  /// Gagalnya DIDIAMKAN sepenuhnya — orang yang nekan logout harus beneran
  /// keluar, apa pun kata server soal token perangkatnya. Konsekuensinya
  /// ditanggung sadar: token yang gagal dicabut masih terdaftar sampai layanan
  /// push nolak dia permanen. Itu sebabnya server MEMINDAHKAN kepemilikan
  /// token waktu orang lain login di HP yang sama, bukan cuma nambah baris.
  Future<void> _cabutTokenPerangkat(String tokenAkun) async {
    try {
      final tokenPerangkat = await ref.read(sumberTokenPushProvider).token();
      if (tokenPerangkat == null) return;

      await ref
          .read(pendaftaranPushServiceProvider)
          .cabut(tokenAkun, tokenPerangkat);
    } catch (_) {
      // Lihat docblock: logout nggak boleh gagal gara-gara ini.
    }
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

    await _buangSimpananAkun();

    state = const AsyncValue.data(null);

    return dicabut;
  }
}

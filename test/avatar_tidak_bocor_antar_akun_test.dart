import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/avatar_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Foto profil nggak ikut pindah akun di HP yang dipakai gantian.
///
/// ## Kenapa berkas ini ada
///
/// `avatarPathProvider` dulu menyimpan path fotonya di SATU kunci global
/// (`avatar_path`) dan nggak menyentuh `authProvider` sama sekali. Dua-duanya
/// perlu, dan dua-duanya nggak ada:
///
///  - Kunci global artinya laci yang dibaca orang berikutnya sama persis
///    dengan laci orang sebelumnya.
///  - Tanpa `ref.watch(authProvider)`, provider yang sudah punya nilai nggak
///    punya sebab apa pun buat membuangnya waktu akunnya ganti.
///
/// Auto-dispose Riverpod 3 nggak menolong di sini, dan itu bagian yang paling
/// gampang salah dikira aman: yang tersimpan di `SharedPreferences` **nggak
/// ikut auto-dispose sama sekali**. Provider boleh lahir ulang sebersih apa
/// pun; `build()`-nya tetap membaca disk yang sama.
///
/// Yang terlihat teknisi: Teknisi A pasang foto → logout → Teknisi B login →
/// foto A terpasang sebagai identitas B, bersebelahan dengan nama dan email B.
///
/// ## Kenapa dua akunnya se-lab
///
/// `SDK-0001` (id 1) dan `SDK-0002` (id 2) dua-duanya `organization_id: 1`.
/// Dipilih sengaja: kunci berbasis ORGANISASI — pola yang dipakai
/// `SimpananPelanggan` — bakal tetap bocor di pasangan ini. Foto profil milik
/// satu manusia, bukan satu lab.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer wadah() {
    final w = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        // Logout mencabut token push sebelum membuang token akun. Tanpa
        // override ini jalannya test ikut bergantung pada platform host.
        sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
      ],
    );
    addTearDown(w.dispose);
    return w;
  }

  /// Baca avatar sesudah `build()` sempat menyelesaikan bacaan disknya.
  ///
  /// `_muat()` itu async dan sengaja nggak di-`await` di `build()` (state awal
  /// selalu null, foto menyusul). Langganannya ditahan supaya provider nggak
  /// dibuang auto-dispose di tengah kerja async-nya — persis alasan yang sama
  /// dengan catatan di `simpanan_pelanggan_test.dart`.
  Future<String?> avatar(ProviderContainer w) async {
    w.listen(avatarPathProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return w.read(avatarPathProvider);
  }

  Future<void> login(ProviderContainer w, String id) =>
      w.read(authProvider.notifier).login(identifier: id, password: 'rahasia123');

  Future<void> logout(ProviderContainer w) =>
      w.read(authProvider.notifier).logout();

  group('avatar per akun', () {
    /// Bukti yang nggak bisa hijau karena kebetulan.
    ///
    /// Bukan cuma "foto B kosong" — itu bisa lolos walau providernya nggak
    /// pernah lahir ulang, karena kosong juga yang keluar kalau bacaannya belum
    /// selesai. Yang diuji di sini DUA nilai berbeda yang masing-masing pulang
    /// ke pemiliknya, bolak-balik.
    test('foto A dan foto B nggak pernah ketuker', () async {
      final w = wadah();

      await login(w, 'SDK-0001');
      await w.read(avatarPathProvider.notifier).setPath('/foto/budi.jpg');
      expect(await avatar(w), '/foto/budi.jpg');

      await logout(w);
      await login(w, 'SDK-0002');

      // Inti bug-nya: sebelum diperbaiki, di sini yang keluar '/foto/budi.jpg'.
      expect(
        await avatar(w),
        isNull,
        reason: 'Foto akun sebelumnya kebawa ke akun berikutnya.',
      );

      await w.read(avatarPathProvider.notifier).setPath('/foto/andi.jpg');
      expect(await avatar(w), '/foto/andi.jpg');

      // Balik ke A: fotonya sendiri harus utuh, bukan foto B dan bukan kosong.
      await logout(w);
      await login(w, 'SDK-0001');
      expect(
        await avatar(w),
        '/foto/budi.jpg',
        reason: 'Laci A kebuang atau ketimpa laci B.',
      );

      // Dan sekali lagi ke B, supaya bukan cuma "yang terakhir menang".
      await logout(w);
      await login(w, 'SDK-0002');
      expect(await avatar(w), '/foto/andi.jpg');
    });

    /// JANGAN kebablasan: foto sendiri bertahan melewati logout.
    ///
    /// Beda dari `SimpananPelanggan` yang isinya dibuang di logout — dia cache
    /// yang bisa diambil ulang dari server. Foto profil nggak punya salinan di
    /// mana pun, jadi membuangnya tiap logout bikin teknisi kehilangan fotonya
    /// permanen tiap ganti shift. Kalau test ini merah, perbaikannya menukar
    /// satu bug dengan bug lain.
    test('foto sendiri selamat dari logout', () async {
      final w = wadah();

      await login(w, 'SDK-0001');
      await w.read(avatarPathProvider.notifier).setPath('/foto/budi.jpg');
      await logout(w);
      await login(w, 'SDK-0001');

      expect(await avatar(w), '/foto/budi.jpg');
    });

    test('sebelum login, nggak ada laci yang ditulis', () async {
      final w = wadah();

      await w.read(avatarPathProvider.notifier).setPath('/foto/nyasar.jpg');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('avatar.')),
        isEmpty,
        reason: 'Foto kesimpen ke laci bersama waktu belum ada yang login.',
      );

      // Sesudah login, layar orang itu nggak boleh mewarisi apa pun.
      await login(w, 'SDK-0001');
      expect(await avatar(w), isNull);
    });
  });

  group('balapan di dalam satu akun', () {
    /// Bacaan disk yang telat selesai nggak boleh menimpa pilihan yang lebih
    /// baru — walau akunnya sama.
    ///
    /// Penjagaan `idPengguna` nggak menangkap urutan ini: dua-duanya milik
    /// akun yang sama, jadi syaratnya terpenuhi dan foto lama tetap mendarat.
    /// Yang terlihat teknisi: dia memilih foto, fotonya muncul sebentar, lalu
    /// berganti sendiri jadi yang lama tanpa ada yang menyentuh apa pun.
    ///
    /// Urutan di test ini deterministik, bukan kebetulan: `w.listen` menjalankan
    /// `build()` sampai `_muat` menggantung di bacaan disknya, dan `setPath`
    /// di baris berikutnya jalan SEBELUM bacaan itu pulang.
    test('pilihan baru nggak ketimpa bacaan disk yang lebih tua', () async {
      SharedPreferences.setMockInitialValues({'avatar.v1.1': '/foto/lama.jpg'});

      final w = wadah();
      await login(w, 'SDK-0001');

      // Sengaja TANPA pump: bacaan awalnya ditinggal menggantung.
      w.listen(avatarPathProvider, (_, _) {});
      await w.read(avatarPathProvider.notifier).setPath('/foto/baru.jpg');

      expect(
        await avatar(w),
        '/foto/baru.jpg',
        reason: 'Bacaan disk yang lebih tua menimpa foto yang barusan dipilih.',
      );
    });

    /// Simpanan yang masih di jalan menyimpan nilai yang DIBAWANYA SENDIRI,
    /// bukan `state` yang dibaca belakangan.
    ///
    /// Bedanya kelihatan waktu akunnya keluar sebelum simpanannya mendarat:
    /// `build()` memulangkan state ke null, dan tulisan yang membaca `state`
    /// belakangan bakal MENGHAPUS laci pemiliknya — foto yang barusan dipilih
    /// hilang permanen, karena dia nggak punya salinan di server.
    ///
    /// Catatan jujur soal test ini: dia mengunci perilaku yang benar, tapi
    /// merahnya pada kode lama bergantung siapa yang menang balapan. Yang
    /// dijamin cuma satu arah — dengan nilai yang ditangkap, dia hijau
    /// SELALU, bukan kadang-kadang.
    test('simpanan yang masih di jalan nggak kehapus waktu akunnya keluar',
        () async {
      final w = wadah();
      await login(w, 'SDK-0001');
      w.listen(avatarPathProvider, (_, _) {});

      // Sengaja nggak di-`await`: itu persis yang terjadi waktu teknisi
      // menekan "keluar" sedetik sesudah memilih foto.
      final simpan = w.read(avatarPathProvider.notifier).setPath('/foto/budi.jpg');
      await logout(w);
      await simpan;

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('avatar.v1.1'),
        '/foto/budi.jpg',
        reason: 'Logout di tengah simpanan justru menghapus foto pemiliknya.',
      );
    });
  });

  group('kunci global lama', () {
    test('nggak pernah dibaca, jadi nggak diwariskan ke siapa pun', () async {
      SharedPreferences.setMockInitialValues({
        'avatar_path': '/foto/orang-sebelumnya.jpg',
      });

      final w = wadah();
      await login(w, 'SDK-0001');

      expect(
        await avatar(w),
        isNull,
        reason: 'Kunci global lama dipindahkan ke orang yang kebetulan login '
            'duluan — itu persis kebocoran yang mau ditutup.',
      );
    });

    test('disapu waktu logout', () async {
      SharedPreferences.setMockInitialValues({
        'avatar_path': '/foto/orang-sebelumnya.jpg',
      });

      final w = wadah();
      await login(w, 'SDK-0001');
      await logout(w);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('avatar_path'), isNull);
    });
  });
}

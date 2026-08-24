import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/versi_service.dart';

/// Pemberitahuan "ada versi baru" — dan satu aturan yang gampang salah tanpa
/// menghasilkan error apa pun.
///
/// `'1.4.9'.compareTo('1.4.12')` memulangkan angka POSITIF, karena sebagai
/// huruf `'9' > '1'`. Dibandingkan begitu, teknisi yang memegang 1.4.9
/// dianggap LEBIH BARU daripada 1.4.12 dan tidak pernah ditawari
/// pemutakhiran — diam-diam, sampai ada yang sadar dia ketinggalan
/// berbulan-bulan.
void main() {
  VersiAplikasi rilis(String versi) =>
      VersiAplikasi(versi: versi, urlUnduh: 'https://x/app.apk');

  group('bandingkanVersi', () {
    test('ruas dibandingkan sebagai ANGKA, bukan huruf', () {
      // Inti seluruh berkas ini.
      expect(bandingkanVersi('1.4.9', '1.4.12'), -1);
      expect(bandingkanVersi('1.4.12', '1.4.9'), 1);

      // Buktikan perbandingan teks memang terbalik — supaya kalau suatu hari
      // ada yang "menyederhanakan" ini jadi compareTo, testnya bunyi.
      expect('1.4.9'.compareTo('1.4.12'), greaterThan(0));
    });

    test('sama persis = 0', () {
      expect(bandingkanVersi('1.0.58', '1.0.58'), 0);
    });

    test('panjang ruas beda disamakan dengan nol', () {
      expect(bandingkanVersi('1.4', '1.4.0'), 0);
      expect(bandingkanVersi('1.4', '1.4.1'), -1);
      expect(bandingkanVersi('2', '1.9.9'), 1);
    });

    test('ruas bukan angka dianggap nol, bukan bikin error', () {
      expect(bandingkanVersi('1.0.x', '1.0.0'), 0);
      expect(bandingkanVersi('', '0.0.0'), 0);
    });

    test('lompatan mayor & minor kebaca', () {
      expect(bandingkanVersi('1.9.99', '2.0.0'), -1);
      expect(bandingkanVersi('1.0.100', '1.1.0'), -1);
    });
  });

  group('lebihBaruDari', () {
    test('true cuma kalau memang lebih baru', () {
      expect(rilis('1.0.59').lebihBaruDari('1.0.58'), isTrue);
      expect(rilis('1.0.58').lebihBaruDari('1.0.58'), isFalse);
      expect(rilis('1.0.57').lebihBaruDari('1.0.58'), isFalse);
    });

    test('versi terpasang kosong tidak dianggap ketinggalan', () {
      // `PackageInfo` yang gagal dibaca memulangkan string kosong. Menganggap
      // itu "ketinggalan" bikin banner update nongol terus-terusan di HP yang
      // justru sudah paling baru.
      expect(rilis('1.0.58').lebihBaruDari(''), isFalse);
      expect(rilis('1.0.58').lebihBaruDari('   '), isFalse);
    });
  });

  group('VersiAplikasi.fromJson', () {
    test('membaca jawaban lengkap', () {
      final v = VersiAplikasi.fromJson({
        'tersedia': true,
        'versi': '1.0.58',
        'build': 58,
        'tag': 'v1.0.58+58',
        'url_unduh': 'https://github.com/x/y/releases/download/v1.0.58+58/app.apk',
        'ukuran': 52428800,
        'catatan': 'build 58 · fix(enclosure)',
        'wajib': false,
      })!;

      expect(v.versi, '1.0.58');
      expect(v.build, 58);
      expect(v.ukuran, 52428800);
      expect(v.ukuranMb, '50 MB');
      expect(v.wajib, isFalse);
    });

    test('`tersedia: false` jadi null, bukan objek kosong', () {
      // Backend menjawab begini waktu GitHub tidak terjawab, belum ada rilis,
      // atau rilisnya tanpa APK. Ketiganya bukan error.
      expect(
        VersiAplikasi.fromJson({
          'tersedia': false,
          'alasan': 'Belum bisa mengecek versi terbaru sekarang.',
        }),
        isNull,
      );
    });

    test('versi atau url kosong ditolak', () {
      // Tombol unduh yang tidak menuju ke mana-mana lebih buruk daripada tidak
      // ada tombol sama sekali.
      expect(
        VersiAplikasi.fromJson({
          'tersedia': true,
          'versi': '1.0.58',
          'url_unduh': '',
        }),
        isNull,
      );
      expect(
        VersiAplikasi.fromJson({
          'tersedia': true,
          'versi': '',
          'url_unduh': 'https://x/app.apk',
        }),
        isNull,
      );
    });

    test('ukuran nol/hilang tidak memaksa label MB', () {
      final v = VersiAplikasi.fromJson({
        'tersedia': true,
        'versi': '1.0.58',
        'url_unduh': 'https://x/app.apk',
      })!;

      expect(v.ukuran, isNull);
      expect(v.ukuranMb, isNull);
    });
  });

  group('updateTersediaProvider', () {
    Future<VersiAplikasi?> jalankan(MockVersiService layanan) async {
      final wadah = ProviderContainer(
        overrides: [versiServiceProvider.overrideWithValue(layanan)],
      );
      addTearDown(wadah.dispose);

      return wadah.read(updateTersediaProvider.future);
    }

    test('memulangkan rilis kalau memang lebih baru', () async {
      final hasil = await jalankan(MockVersiService(
        terpasang: '1.0.9',
        terbaru: rilis('1.0.12'),
      ));

      expect(hasil?.versi, '1.0.12');
    });

    test('null kalau sudah paling baru', () async {
      final hasil = await jalankan(MockVersiService(
        terpasang: '1.0.58',
        terbaru: rilis('1.0.58'),
      ));

      expect(hasil, isNull);
    });

    test('null kalau yang terpasang justru lebih baru dari rilis', () async {
      // Terjadi di build lokal: pubspec `+2` sengaja lebih kecil dari build CI,
      // tapi kebalikannya bisa muncul waktu ada yang membangun dari laptop
      // dengan angka besar. Jangan menawari "update" ke versi yang lebih tua.
      final hasil = await jalankan(MockVersiService(
        terpasang: '2.0.0',
        terbaru: rilis('1.0.58'),
      ));

      expect(hasil, isNull);
    });

    test('server menjawab tidak tersedia → null, bukan error', () async {
      final hasil = await jalankan(MockVersiService(terbaru: null));

      expect(hasil, isNull);
    });

    test('layanan MELEMPAR pun tetap null — aplikasi harus tetap kebuka', () async {
      // Ini yang paling penting. Pemeriksaan ini jalan waktu aplikasi dibuka,
      // dan teknisi di lapangan sering tanpa sinyal. Kalau provider ini
      // melempar, yang rusak justru pembukaan aplikasinya.
      final hasil = await jalankan(MockVersiService(gagal: true));

      expect(hasil, isNull);
    });
  });

  group('versiTerpasangProvider', () {
    test('versi digabung dengan nomor build buat ditampilkan', () async {
      final wadah = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', build: '58'),
          ),
        ],
      );
      addTearDown(wadah.dispose);

      expect(await wadah.read(versiTerpasangProvider.future), '1.0.58 (build 58)');
    });

    test('build kosong tidak menyisakan tanda kurung menggantung', () async {
      final wadah = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', build: ''),
          ),
        ],
      );
      addTearDown(wadah.dispose);

      expect(await wadah.read(versiTerpasangProvider.future), '1.0.58');
    });
  });
}

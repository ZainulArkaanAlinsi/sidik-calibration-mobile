import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/pengunduh_apk.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';
import 'package:sidik_calibration/services/versi_service.dart';
import 'package:sidik_calibration/widgets/banner_update.dart';

/// Banner "ada versi baru" — pengganti alur bolak-balik unduh manual.
///
/// Yang dijaga di sini bukan tampilannya, tapi tiga aturan yang menentukan
/// apakah teknisi jadi memperbarui atau malah menyimpulkan aplikasinya rusak:
/// bannernya tidak boleh nongol waktu sudah paling baru, tidak boleh memaksa,
/// dan pesan gagalnya harus menyebut apa yang HARUS DILAKUKAN — bukan
/// "coba lagi" untuk hal yang tidak akan pernah berhasil tanpa izin.
class _PengunduhPalsu implements PengunduhApk {
  _PengunduhPalsu(this.hasil, {this.progres = const [0.5, 1.0], this.tahan});

  final HasilPasang hasil;
  final List<double?> progres;

  /// Kalau diisi, unduhannya MENGGANTUNG sampai completer-nya diselesaikan
  /// test. Tanpa ini fake-nya selesai seketika dan keadaan "sedang mengunduh"
  /// tidak pernah sempat teramati — `pump()` sudah melihat keadaan sesudahnya.
  final Completer<void>? tahan;

  String? urlDiminta;
  String? namaDiminta;

  /// Berkas yang diserahkan lewat [pasang] — diisi cuma kalau banner memakai
  /// jalur "sudah siap", bukan mengunduh ulang.
  File? berkasDipasang;

  @override
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    urlDiminta = url;
    namaDiminta = namaBerkas;
    for (final p in progres) {
      onProgres?.call(p);
    }
    if (tahan != null) await tahan!.future;

    return hasil == HasilPasang.gagalUnduh ? null : File('/palsu/$namaBerkas');
  }

  @override
  Future<HasilPasang> pasang(File berkas) async {
    berkasDipasang = berkas;

    return hasil;
  }

  @override
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    final b = await unduh(url, namaBerkas: namaBerkas, onProgres: onProgres);
    if (b == null) return HasilPasang.gagalUnduh;

    return pasang(b);
  }
}

/// Penyiap latar yang dipatok: [siap] menentukan apakah APK-nya sudah ada
/// sebelum teknisi menekan apa pun.
class _PenyiapPalsu implements PenyiapUpdate {
  _PenyiapPalsu({this.siap = false});

  final bool siap;
  int panggilanSiapkan = 0;

  @override
  Future<File?> apkSiap(String versi) async =>
      siap ? File('/palsu/sidik-kalibrasi-$versi.apk') : null;

  @override
  Future<bool> siapkan(VersiAplikasi rilis) async {
    panggilanSiapkan++;

    return siap;
  }
}

void main() {
  VersiAplikasi rilis({String versi = '1.0.60', int? ukuran = 52428800}) =>
      VersiAplikasi(
        versi: versi,
        urlUnduh: 'https://github.com/x/y/releases/download/v$versi/app.apk',
        ukuran: ukuran,
      );

  Future<void> pasang(
    WidgetTester tester, {
    required MockVersiService layanan,
    PengunduhApk? pengunduh,
    PenyiapUpdate? penyiap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          versiServiceProvider.overrideWithValue(layanan),
          penyiapUpdateProvider.overrideWithValue(penyiap ?? _PenyiapPalsu()),
        ],
        child: MaterialApp(
          home: Scaffold(body: BannerUpdate(pengunduh: pengunduh)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('kapan bannernya nongol', () {
    testWidgets('nongol kalau ada versi lebih baru', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
      );

      expect(find.text('Versi 1.0.60 sudah tersedia'), findsOneWidget);
      expect(find.text('Pasang (50 MB)'), findsOneWidget);
    });

    testWidgets('TIDAK nongol kalau sudah paling baru', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(
          terpasang: '1.0.60',
          terbaru: rilis(versi: '1.0.60'),
        ),
      );

      expect(find.textContaining('sudah tersedia'), findsNothing);
    });

    testWidgets('TIDAK nongol kalau versi lebih tua diumumkan', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(
          terpasang: '1.0.60',
          terbaru: rilis(versi: '1.0.9'),
        ),
      );

      // 1.0.9 vs 1.0.60 — kalau dibandingkan sebagai teks, '9' > '6' dan
      // bannernya nongol menawarkan versi yang lebih TUA.
      expect(find.textContaining('sudah tersedia'), findsNothing);
    });

    testWidgets('TIDAK nongol kalau pengecekan gagal', (tester) async {
      // Teknisi di lapangan sering tanpa sinyal. Gagal mengecek bukan keadaan
      // yang perlu ditampilkan.
      await pasang(tester, layanan: MockVersiService(gagal: true));

      expect(find.textContaining('sudah tersedia'), findsNothing);
    });

    testWidgets('ukuran tidak diketahui: tombolnya tetap masuk akal', (
      tester,
    ) async {
      await pasang(
        tester,
        layanan: MockVersiService(
          terpasang: '1.0.58',
          terbaru: rilis(ukuran: null),
        ),
      );

      expect(find.text('Pasang sekarang'), findsOneWidget);
    });
  });

  group('tidak memaksa', () {
    testWidgets('bisa ditutup, dan tidak balik lagi', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
      );
      expect(find.textContaining('sudah tersedia'), findsOneWidget);

      await tester.tap(find.byKey(const Key('banner_update_tutup')));
      await tester.pumpAndSettle();

      expect(find.textContaining('sudah tersedia'), findsNothing);
    });
  });

  group('unduh & pasang', () {
    testWidgets('url dan nama berkas berversi diteruskan ke pengunduh', (
      tester,
    ) async {
      final pengunduh = _PengunduhPalsu(HasilPasang.pemasangDibuka);
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: pengunduh,
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      expect(
        pengunduh.urlDiminta,
        'https://github.com/x/y/releases/download/v1.0.60/app.apk',
      );
      // Nama berversi, bukan `app-release.apk`: yang mendarat di penyimpanan
      // harus bisa dibedakan dari unduhan sebelumnya.
      expect(pengunduh.namaDiminta, 'sidik-kalibrasi-1.0.60.apk');
    });

    testWidgets('berhasil: tidak ada pesan galat', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: _PengunduhPalsu(HasilPasang.pemasangDibuka),
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('banner_update_galat')), findsNothing);
    });

    testWidgets('ditolak sistem: pesannya menyebut layar izin, bukan "coba lagi"', (
      tester,
    ) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: _PengunduhPalsu(HasilPasang.ditolakSistem),
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      // Menekan tombolnya lagi tanpa memberi izin selalu berujung sama, jadi
      // pesannya harus mengarahkan ke Pengaturan.
      expect(
        find.textContaining('Install unknown apps'),
        findsOneWidget,
      );
    });

    testWidgets('gagal unduh: pesannya soal sinyal/penyimpanan', (tester) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: _PengunduhPalsu(HasilPasang.gagalUnduh),
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unduhan gagal'), findsOneWidget);
    });

    testWidgets('sesudah gagal, tombol Pasang masih bisa ditekan lagi', (
      tester,
    ) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: _PengunduhPalsu(HasilPasang.gagalUnduh),
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      // Kalau tombolnya ikut mati sesudah gagal, teknisi yang sinyalnya
      // sempat putus harus menutup & membuka aplikasi buat mencoba lagi.
      expect(find.byKey(const Key('banner_update_pasang')), findsOneWidget);
      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();
    });

    testWidgets('tombol tutup hilang selama mengunduh', (tester) async {
      // Menutup banner di tengah unduhan bikin unduhan 50 MB jalan terus tanpa
      // ada yang menampilkannya — teknisi tidak tahu kuotanya sedang terpakai.
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu(
        HasilPasang.pemasangDibuka,
        progres: const [0.1],
        tahan: tahan,
      );

      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: pengunduh,
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pump(); // unduhan menggantung di `tahan`

      expect(find.byKey(const Key('banner_update_tutup')), findsNothing);
      expect(find.textContaining('Mengunduh'), findsOneWidget);

      tahan.complete();
      await tester.pumpAndSettle();

      // Selesai unduh, tombol tutupnya balik.
      expect(find.byKey(const Key('banner_update_tutup')), findsOneWidget);
    });
  });

  group('sudah disiapkan di latar', () {
    testWidgets('judulnya "siap dipasang", bukan "sudah tersedia"', (
      tester,
    ) async {
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        penyiap: _PenyiapPalsu(siap: true),
      );

      expect(find.text('Versi 1.0.60 siap dipasang'), findsOneWidget);
      expect(find.text('Versi 1.0.60 sudah tersedia'), findsNothing);
    });

    testWidgets('ukuran TIDAK ditulis di tombol — tidak ada yang diunduh', (
      tester,
    ) async {
      // Menulis "50 MB" waktu berkasnya sudah ada itu bohong, dan bikin ragu
      // menekan sesuatu yang sebenarnya instan.
      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        penyiap: _PenyiapPalsu(siap: true),
      );

      expect(find.text('Pasang sekarang'), findsOneWidget);
      expect(find.text('Pasang (50 MB)'), findsNothing);
    });

    testWidgets('menekan Pasang langsung ke pemasang, tanpa mengunduh ulang', (
      tester,
    ) async {
      final pengunduh = _PengunduhPalsu(HasilPasang.pemasangDibuka);

      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: pengunduh,
        penyiap: _PenyiapPalsu(siap: true),
      );

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      // Inti seluruh mekanisme latar: berkasnya diserahkan langsung, dan
      // `unduh()` tidak pernah dipanggil.
      expect(pengunduh.berkasDipasang?.path, contains('1.0.60'));
      expect(pengunduh.urlDiminta, isNull);
    });

    testWidgets('belum siap: tetap pakai jalur unduh, ukuran tetap ditulis', (
      tester,
    ) async {
      // Di jaringan seluler unduhan latar sengaja tidak jalan. Teknisi tidak
      // boleh kehilangan cara memasang — cuma caranya yang lebih lambat, dan
      // ukurannya disebut supaya keputusannya sadar.
      final pengunduh = _PengunduhPalsu(HasilPasang.pemasangDibuka);

      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        pengunduh: pengunduh,
        penyiap: _PenyiapPalsu(siap: false),
      );

      expect(find.text('Pasang (50 MB)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('banner_update_pasang')));
      await tester.pumpAndSettle();

      expect(pengunduh.urlDiminta, isNotNull);
    });

    testWidgets('penyiap latar dipanggil waktu ada pemutakhiran', (
      tester,
    ) async {
      final penyiap = _PenyiapPalsu(siap: false);

      await pasang(
        tester,
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        penyiap: penyiap,
      );

      expect(penyiap.panggilanSiapkan, greaterThan(0));
    });

    testWidgets('TIDAK dipanggil kalau sudah paling baru', (tester) async {
      // Menyiapkan unduhan buat versi yang sudah terpasang itu 50 MB percuma.
      final penyiap = _PenyiapPalsu(siap: false);

      await pasang(
        tester,
        layanan: MockVersiService(
          terpasang: '1.0.60',
          terbaru: rilis(versi: '1.0.60'),
        ),
        penyiap: penyiap,
      );

      expect(penyiap.panggilanSiapkan, 0);
    });
  });
}

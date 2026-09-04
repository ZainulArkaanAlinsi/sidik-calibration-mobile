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
import 'package:sidik_calibration/widgets/pemasang_otomatis.dart';

/// Pemasang yang terbuka SENDIRI — pemotong ketukan kedua.
///
/// Yang dijaga di sini bukan "pemasangnya terbuka". Itu bagian gampangnya, dan
/// satu baris kode sudah cukup. Yang mahal justru empat keadaan waktu dia harus
/// DIAM, karena keempatnya gagal tanpa error dan yang menanggung teknisi di
/// lokasi pelanggan:
///
///   - berkasnya belum terunduh → pemasang menggantung menunggu 68 MB;
///   - sudah pernah dibuka → "Batal" tidak pernah berarti apa-apa;
///   - orangnya sudah pindah ke lembar kerja → ditarik keluar di tengah kerja;
///   - tidak ada pemutakhiran → giliran habis buat hal yang tidak ada.
class _PengunduhPalsu implements PengunduhApk {
  int panggilanPasang = 0;
  File? berkasDipasang;
  String? urlDiminta;

  @override
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    urlDiminta = url;

    return File('/palsu/$namaBerkas');
  }

  @override
  Future<HasilPasang> pasang(File berkas) async {
    panggilanPasang++;
    berkasDipasang = berkas;

    return HasilPasang.pemasangDibuka;
  }

  @override
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    urlDiminta = url;

    return pasang(File('/palsu/$namaBerkas'));
  }
}

class _PenyiapPalsu implements PenyiapUpdate {
  _PenyiapPalsu({this.siap = false, this.tahan});

  final bool siap;

  /// Kalau diisi, [apkSiap] MENGGANTUNG sampai test menyelesaikannya. Dipakai
  /// buat menaruh kejadian lain (mis. pindah layar) di tengah jeda async,
  /// yang tanpa ini tidak pernah bisa disisipkan.
  final Completer<void>? tahan;

  @override
  Future<File?> apkSiap(String versi) async {
    if (tahan != null) await tahan!.future;

    return siap ? File('/palsu/sidik-kalibrasi-$versi.apk') : null;
  }

  @override
  Future<bool> siapkan(VersiAplikasi rilis) async => siap;
}

void main() {
  VersiAplikasi rilis({String versi = '1.0.60', bool wajib = false}) =>
      VersiAplikasi(
        versi: versi,
        urlUnduh: 'https://github.com/x/y/releases/download/v$versi/app.apk',
        ukuran: 52428800,
        wajib: wajib,
      );

  /// Satu `ProviderContainer` dipegang test, bukan dibikin `ProviderScope`
  /// sendiri — supaya penjaga "sekali per proses" bisa diamati melewati
  /// pemasangan ulang widget-nya.
  ProviderContainer wadah({
    required MockVersiService layanan,
    PenyiapUpdate? penyiap,
  }) {
    final c = ProviderContainer(
      overrides: [
        versiServiceProvider.overrideWithValue(layanan),
        penyiapUpdateProvider.overrideWithValue(penyiap ?? _PenyiapPalsu()),
      ],
    );
    addTearDown(c.dispose);

    return c;
  }

  Future<void> pasang(
    WidgetTester tester, {
    required ProviderContainer container,
    required PengunduhApk pengunduh,
    Key? key,
    GlobalKey<NavigatorState>? navigator,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: PemasangOtomatis(
              key: key,
              pengunduh: pengunduh,
              child: const Text('dashboard'),
            ),
          ),
        ),
      ),
    );
  }

  group('membuka pemasang sendiri', () {
    testWidgets('APK sudah terunduh: terbuka tanpa satu pun ketukan', (
      tester,
    ) async {
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      // Tidak ada `tester.tap` di mana pun di test ini — itu intinya.
      expect(pengunduh.panggilanPasang, 1);
      expect(pengunduh.berkasDipasang?.path, contains('1.0.60'));
    });

    testWidgets('berkasnya diserahkan langsung, tidak diunduh ulang', (
      tester,
    ) async {
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      expect(pengunduh.urlDiminta, isNull);
    });

    testWidgets('rilis wajib juga terbuka sendiri', (tester) async {
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(
            terpasang: '1.0.58',
            terbaru: rilis(wajib: true),
          ),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 1);
    });

    testWidgets('memulangkan anaknya apa adanya, tanpa menyisipkan apa pun', (
      tester,
    ) async {
      // Dia membungkus SELURUH isi dashboard. Satu widget tata letak yang
      // diam-diam ikut tersisip — `Column`, `Center`, `SizedBox` — akan
      // mengubah tampilan seluruh layar, dan penyebabnya widget yang namanya
      // tidak ada hubungannya dengan tata letak.
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      Element? langsung;
      tester.element(find.byType(PemasangOtomatis)).visitChildren((e) {
        langsung = e;
      });

      // Anaknya PERSIS di bawahnya, bukan cucu.
      expect(langsung?.widget, isA<Text>());
      expect(find.text('dashboard'), findsOneWidget);
    });
  });

  group('kapan dia harus DIAM', () {
    testWidgets('APK belum terunduh: pemasang TIDAK dibuka', (tester) async {
      // Membuka pemasang buat berkas yang belum ada berarti melempar orang ke
      // layar yang menggantung menunggu 68 MB. Ini keadaan normal di jaringan
      // seluler, bukan kasus pinggir: unduhan latar sengaja tidak jalan di
      // sana, dan bannerlah yang mengurusnya lengkap dengan ukurannya.
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 0);
    });

    testWidgets('sudah versi terbaru: pemasang TIDAK dibuka', (tester) async {
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(
            terpasang: '1.0.60',
            terbaru: rilis(versi: '1.0.60'),
          ),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 0);
    });

    testWidgets('pengecekan versi gagal: pemasang TIDAK dibuka', (
      tester,
    ) async {
      final pengunduh = _PengunduhPalsu();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(gagal: true),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 0);
    });

    testWidgets('sudah pindah ke layar lain: pemasang TIDAK dibuka', (
      tester,
    ) async {
      // Yang paling mahal dari seluruh berkas ini. Teknisi yang membuka
      // aplikasi lalu langsung masuk lembar kerja tidak boleh ditarik keluar
      // begitu jawaban server datang — pekerjaan yang sedang diketik hilang
      // konteksnya, dan itu persis gangguan yang seluruh mekanisme unduh
      // di-latar dibangun buat menghindarinya.
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu();
      final nav = GlobalKey<NavigatorState>();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true, tahan: tahan),
        ),
        pengunduh: pengunduh,
        navigator: nav,
      );
      await tester.pump();

      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('lembar kerja')),
        ),
      );
      await tester.pumpAndSettle();

      // Baru sesudah orangnya pindah, jawabannya datang.
      tahan.complete();
      await tester.pumpAndSettle();

      expect(find.text('lembar kerja'), findsOneWidget);
      expect(pengunduh.panggilanPasang, 0);
    });
  });

  group('sekali per proses', () {
    testWidgets('dipasang ulang: pemasang TIDAK dibuka kedua kalinya', (
      tester,
    ) async {
      // Teknisi menekan "Batal" di layar pemasang lalu balik ke dashboard.
      // Kalau penjaganya ikut umur widget, dia disambut layar yang sama —
      // berulang, tanpa cara keluar selain menerima pemasangannya.
      final pengunduh = _PengunduhPalsu();
      final c = wadah(
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        penyiap: _PenyiapPalsu(siap: true),
      );

      await pasang(
        tester,
        container: c,
        pengunduh: pengunduh,
        key: const Key('pertama'),
      );
      await tester.pumpAndSettle();
      expect(pengunduh.panggilanPasang, 1);

      // Key yang beda memaksa State baru — persis seperti dashboard yang
      // dibongkar-pasang waktu pindah tab atau balik dari layar lain.
      await pasang(
        tester,
        container: c,
        pengunduh: pengunduh,
        key: const Key('kedua'),
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 1);
    });

    testWidgets('gagal cek versi tidak menghabiskan giliran', (tester) async {
      // Giliran diambil PALING AKHIR justru buat ini. Pembukaan aplikasi yang
      // kebetulan tanpa sinyal tidak boleh menghabiskan satu-satunya giliran
      // buat pemutakhiran yang bahkan tidak ketahuan ada — kalau habis, tidak
      // ada lagi yang membuka pemasang sampai aplikasinya ditutup.
      final pengunduh = _PengunduhPalsu();
      final c = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(MockVersiService(gagal: true)),
          penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu(siap: true)),
        ],
      );
      addTearDown(c.dispose);

      await pasang(
        tester,
        container: c,
        pengunduh: pengunduh,
        key: const Key('tanpa-sinyal'),
      );
      await tester.pumpAndSettle();
      expect(pengunduh.panggilanPasang, 0);

      // Sinyal balik: pemeriksaan berikutnya menemukan rilisnya.
      c.invalidate(updateTersediaProvider);
      final c2 = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          ),
          penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu(siap: true)),
          giliranPemasangOtomatisProvider.overrideWithValue(
            c.read(giliranPemasangOtomatisProvider),
          ),
        ],
      );
      addTearDown(c2.dispose);

      await pasang(
        tester,
        container: c2,
        pengunduh: pengunduh,
        key: const Key('sinyal-balik'),
      );
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 1);
    });
  });
}

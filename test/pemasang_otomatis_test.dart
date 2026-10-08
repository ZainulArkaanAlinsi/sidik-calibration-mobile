import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/pemasang_sesi.dart';
import 'package:sidik_calibration/services/pengunduh_apk.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';
import 'package:sidik_calibration/services/versi_service.dart';
import 'package:sidik_calibration/widgets/pemasang_otomatis.dart';

/// Pop-up pembaruan yang muncul SENDIRI waktu aplikasi dibuka di dashboard.
///
/// Permintaan pemilik proyek 8 Okt 2026: "kalau ada versi baru APK, muncul
/// pop-up; tinggal pencet Update, langsung update". Yang dijaga di sini bukan
/// cuma "dialognya muncul" — itu bagian gampangnya. Yang mahal justru keadaan
/// waktu dia harus DIAM atau harus BISA DITUTUP, karena semuanya gagal tanpa
/// error dan yang menanggung teknisi di lokasi pelanggan:
///
///   - sudah pernah muncul → "Nanti" tidak pernah berarti apa-apa;
///   - orangnya sudah pindah ke lembar kerja → disela di tengah kerja;
///   - tidak ada pemutakhiran / desktop → giliran habis buat hal yang tidak ada;
///   - rilis wajib → aplikasinya tetap TIDAK dikunci;
///   - unduhan jalan → tidak bisa ditutup atau ditekan dua kali.
class _PengunduhPalsu implements PengunduhApk {
  _PengunduhPalsu({
    this.hasil = HasilPasang.pemasangDibuka,
    this.lempar = false,
    this.progres = const [],
    this.tahan,
  });

  final HasilPasang hasil;

  /// `pasang` melempar, meniru `OpenFilex.open` yang gagal di platform
  /// channel — satu-satunya cara jalur pasang bisa melempar.
  final bool lempar;

  /// Dilaporkan berurutan lewat `onProgres` sebelum unduhannya selesai.
  final List<double?> progres;

  /// Kalau diisi, unduhannya MENGGANTUNG sampai completer-nya diselesaikan
  /// test — tanpa ini keadaan "sedang mengunduh" tidak pernah teramati.
  final Completer<void>? tahan;

  int panggilanPasang = 0;
  int panggilanUnduhDanPasang = 0;
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
    if (lempar) throw Exception('pemasang meledak di platform channel');

    return hasil;
  }

  @override
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    panggilanUnduhDanPasang++;
    urlDiminta = url;
    for (final p in progres) {
      onProgres?.call(p);
    }
    if (tahan != null) await tahan!.future;
    if (hasil == HasilPasang.gagalUnduh) return HasilPasang.gagalUnduh;

    return pasang(File('/palsu/$namaBerkas'));
  }
}

/// Layanan versi yang MENGGANTUNG sampai test melepasnya — buat menaruh
/// kejadian lain (mis. dashboard ditutup) di dalam jeda `await`-nya.
class _LayananTertahan implements VersiService {
  _LayananTertahan(this.tahan, {this.terbaru});

  final Completer<void> tahan;
  final VersiAplikasi? terbaru;

  @override
  Future<String> versiTerpasang() async => '1.0.58';

  @override
  Future<String> buildTerpasang() async => '58';

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    await tahan.future;

    return terbaru;
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

final _dialog = find.byKey(const Key('dialog_update'));
final _nanti = find.byKey(const Key('dialog_update_nanti'));
final _update = find.byKey(const Key('dialog_update_pasang'));
final _galat = find.byKey(const Key('dialog_update_galat'));

void main() {
  VersiAplikasi rilis({
    String versi = '1.0.60',
    bool wajib = false,
    String? catatan,
  }) => VersiAplikasi(
    versi: versi,
    urlUnduh: 'https://github.com/x/y/releases/download/v$versi/app.apk',
    // 50 MiB → tombol "Update (50 MB)".
    ukuran: 52428800,
    catatan: catatan,
    wajib: wajib,
  );

  /// Satu `ProviderContainer` dipegang test, bukan dibikin `ProviderScope`
  /// sendiri — supaya penjaga "sekali per proses" bisa diamati melewati
  /// pemasangan ulang widget-nya.
  ProviderContainer wadah({
    required VersiService layanan,
    PenyiapUpdate? penyiap,
    bool jalurApk = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        versiServiceProvider.overrideWithValue(layanan),
        penyiapUpdateProvider.overrideWithValue(penyiap ?? _PenyiapPalsu()),
        jalurApkProvider.overrideWithValue(jalurApk),
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

  bool aktif(WidgetTester tester, Finder tombol) =>
      tester.widget<ButtonStyleButton>(tombol).onPressed != null;

  group('dialog muncul sendiri', () {
    testWidgets('APK sudah terunduh: dialog muncul tanpa ketukan, pemasang '
        'BELUM dibuka', (tester) async {
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

      expect(_dialog, findsOneWidget);
      expect(find.text('Versi 1.0.60 tersedia'), findsOneWidget);
      // Berkasnya sudah ada — menulis "50 MB" di tombol itu bohong.
      expect(find.text('Update sekarang'), findsOneWidget);
      expect(find.textContaining('MB'), findsNothing);
      expect(find.text('Nanti'), findsOneWidget);
      // Memasang tetap keputusan orangnya: dialog dulu, pemasang sesudah
      // tombolnya ditekan.
      expect(pengunduh.panggilanPasang, 0);
    });

    testWidgets('APK belum terunduh: dialog TETAP muncul, tombol menyebut '
        'ukuran', (tester) async {
      // Teknisi yang selalu di data seluler tidak pernah punya APK terunduh
      // di latar — justru dia yang paling butuh disapa. Ukurannya ditulis
      // supaya 50 MB kuota itu keputusan sadar.
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(find.text('Update (50 MB)'), findsOneWidget);
    });

    testWidgets('catatan rilis ditampilkan', (tester) async {
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(
            terpasang: '1.0.58',
            terbaru: rilis(catatan: 'feat: Riwayat — kolom pencarian'),
          ),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(find.text('feat: Riwayat — kolom pencarian'), findsOneWidget);
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

      // Anaknya PERSIS di bawahnya, bukan cucu. Dialognya di rute sendiri.
      expect(langsung?.widget, isA<Text>());
      expect(find.text('dashboard'), findsOneWidget);
    });
  });

  group('tombol di dialog', () {
    testWidgets('Nanti menutup dialog tanpa memasang apa pun', (tester) async {
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

      await tester.tap(_nanti);
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(find.text('dashboard'), findsOneWidget);
      expect(pengunduh.panggilanPasang, 0);
      expect(pengunduh.urlDiminta, isNull);
    });

    testWidgets('Update dengan APK siap: berkasnya langsung ke pemasang, '
        'tidak diunduh ulang', (tester) async {
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

      await tester.tap(_update);
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 1);
      expect(pengunduh.berkasDipasang?.path, contains('1.0.60'));
      expect(pengunduh.panggilanUnduhDanPasang, 0);
      expect(pengunduh.urlDiminta, isNull);
      // Pemasang Android sudah di depan; tugas dialognya selesai.
      expect(_dialog, findsNothing);
    });

    testWidgets('Update tanpa APK: progres tampil di dialog, lalu '
        'unduhDanPasang', (tester) async {
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu(progres: const [0.5], tahan: tahan);

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pump(); // unduhan menggantung di `tahan`

      final bilah = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: _dialog,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bilah.value, 0.5);
      expect(find.text('Mengunduh… 50%'), findsOneWidget);

      tahan.complete();
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanUnduhDanPasang, 1);
      expect(
        pengunduh.urlDiminta,
        'https://github.com/x/y/releases/download/v1.0.60/app.apk',
      );
      // Nama yang sama dengan unduhan latar — `apkSiap` mencarinya.
      expect(
        pengunduh.berkasDipasang?.path,
        endsWith('sidik-kalibrasi-1.0.60.apk'),
      );
      expect(_dialog, findsNothing);
    });

    testWidgets('server tanpa Content-Length: bilahnya TAK TENTU, bukan diam '
        'di 0%', (tester) async {
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu(progres: const [null], tahan: tahan);

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pump();

      final bilah = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bilah.value, isNull);
      expect(find.text('Mengunduh…'), findsOneWidget);

      tahan.complete();
      // Bilah tak tentu beranimasi terus; `pumpAndSettle` baru aman sesudah
      // unduhannya selesai dan dialognya tertutup.
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });

    testWidgets('selama mengunduh: tidak bisa ditutup, tombol tidak bisa '
        'ditekan dua kali', (tester) async {
      // Menutup dialog di tengah unduhan bikin 50 MB jalan terus tanpa ada
      // yang menampilkannya; tombol yang bisa ditekan lagi memulai unduhan
      // kedua ke berkas yang sama.
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu(progres: const [0.1], tahan: tahan);

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pump();

      expect(aktif(tester, _update), isFalse);
      expect(aktif(tester, _nanti), isFalse);

      // Ketukan di luar dialog dan tombol kembali Android.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(_dialog, findsOneWidget);

      final dicegat = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(dicegat, isTrue);
      expect(_dialog, findsOneWidget);

      tahan.complete();
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanUnduhDanPasang, 1);
    });

    testWidgets('selesai mengunduh tapi gagal: Nanti bisa ditekan lagi', (
      tester,
    ) async {
      final tahan = Completer<void>();
      final pengunduh = _PengunduhPalsu(
        hasil: HasilPasang.gagalUnduh,
        progres: const [0.3],
        tahan: tahan,
      );

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: false),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pump();
      tahan.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('Unduhan gagal'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(aktif(tester, _nanti), isTrue);

      // Mengetuk di luar dialog juga kembali berarti "Nanti".
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });

    testWidgets('ditolak sistem: pesannya menyebut "Install unknown apps" dan '
        'tombol Update bisa ditekan lagi', (tester) async {
      // Menekan tombolnya lagi tanpa memberi izin selalu berujung sama, jadi
      // pesannya mengarahkan ke Pengaturan — dan menyebut tombol yang memang
      // ada di dialog ini, bukan "Pasang" milik banner.
      final pengunduh = _PengunduhPalsu(hasil: HasilPasang.ditolakSistem);

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(_galat, findsOneWidget);
      expect(find.textContaining('Install unknown apps'), findsOneWidget);
      expect(find.textContaining('tekan Update lagi'), findsOneWidget);

      expect(aktif(tester, _update), isTrue);
      await tester.tap(_update);
      await tester.pumpAndSettle();
      expect(pengunduh.panggilanPasang, 2);
    });

    testWidgets('pemasang Android melempar: galat tampil, dialog TIDAK '
        'terkunci', (tester) async {
      // Tanpa penangkap, `_sibuk` tidak pernah turun — dan dialog yang tidak
      // bisa ditutup itu aplikasi yang terkunci.
      final pengunduh = _PengunduhPalsu(lempar: true);

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: pengunduh,
      );
      await tester.pumpAndSettle();

      await tester.tap(_update);
      await tester.pumpAndSettle();

      expect(pengunduh.panggilanPasang, 1);
      expect(tester.takeException(), isNull);
      expect(_galat, findsOneWidget);
      expect(aktif(tester, _nanti), isTrue);
    });
  });

  /// Rilis wajib TIDAK mengunci aplikasi — keputusan lama di `BannerUpdate`.
  /// Teknisi di lokasi pelanggan tanpa sinyal cukup untuk 50–68 MB harus
  /// tetap bisa mencatat; yang ditahan cuma pengirimannya.
  group('rilis wajib', () {
    testWidgets('judul menyebut WAJIB, menyebut pengiriman ditahan, dan TETAP '
        'punya Nanti', (tester) async {
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(
            terpasang: '1.0.58',
            terbaru: rilis(wajib: true),
          ),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Versi 1.0.60 WAJIB dipasang'), findsOneWidget);
      expect(
        find.text('Pengiriman lembar kerja ditahan sampai versi ini dipasang.'),
        findsOneWidget,
      );
      expect(aktif(tester, _nanti), isTrue);

      await tester.tap(_nanti);
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(find.text('dashboard'), findsOneWidget);
    });

    testWidgets('rilis biasa TIDAK menyebut WAJIB', (tester) async {
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('WAJIB'), findsNothing);
      expect(find.byKey(const Key('dialog_update_wajib')), findsNothing);
    });
  });

  group('kapan dialognya TIDAK muncul', () {
    testWidgets('sudah versi terbaru', (tester) async {
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(
            terpasang: '1.0.60',
            terbaru: rilis(versi: '1.0.60'),
          ),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
    });

    testWidgets('pengecekan versi gagal (tanpa sinyal)', (tester) async {
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(gagal: true),
          penyiap: _PenyiapPalsu(siap: true),
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
    });

    testWidgets('desktop (jalur APK tidak berlaku)', (tester) async {
      // Laptop Windows punya pembarunya sendiri. Menawarkan APK di sana itu
      // tombol yang tidak bisa apa-apa.
      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true),
          jalurApk: false,
        ),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
    });

    testWidgets('dashboard bukan layar yang sedang dilihat', (tester) async {
      // Yang paling mahal dari seluruh berkas ini. Teknisi yang membuka
      // aplikasi lalu langsung masuk lembar kerja tidak boleh disela begitu
      // jawaban server datang.
      final tahan = Completer<void>();
      final nav = GlobalKey<NavigatorState>();

      await pasang(
        tester,
        container: wadah(
          layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          penyiap: _PenyiapPalsu(siap: true, tahan: tahan),
        ),
        pengunduh: _PengunduhPalsu(),
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
      expect(_dialog, findsNothing);
    });

    testWidgets('dashboard ditutup di tengah pemeriksaan versi: tidak ada '
        'galat asinkron', (tester) async {
      // Logout, atau rute yang diganti, sementara jawaban server belum datang.
      // Sesudah widget-nya dilepas, `ref` tidak boleh disentuh lagi —
      // flutter_riverpod menolaknya dengan "Cannot use 'ref' after the widget
      // was disposed", dan tidak ada yang menangkapnya.
      final tahan = Completer<void>();
      final c = wadah(
        layanan: _LayananTertahan(tahan, terbaru: rilis()),
        penyiap: _PenyiapPalsu(siap: true),
      );

      await pasang(tester, container: c, pengunduh: _PengunduhPalsu());
      await tester.pump();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: Text('layar masuk'))),
        ),
      );
      await tester.pumpAndSettle();

      tahan.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_dialog, findsNothing);
    });
  });

  group('sekali per proses', () {
    testWidgets('dipasang ulang sesudah "Nanti": dialog TIDAK muncul kedua '
        'kalinya', (tester) async {
      // Teknisi menekan "Nanti" lalu balik ke dashboard. Kalau penjaganya ikut
      // umur widget, dia disambut dialog yang sama — berulang, tanpa cara
      // keluar selain menerima pemasangannya.
      final c = wadah(
        layanan: MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
        penyiap: _PenyiapPalsu(siap: true),
      );

      await pasang(
        tester,
        container: c,
        pengunduh: _PengunduhPalsu(),
        key: const Key('pertama'),
      );
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);

      await tester.tap(_nanti);
      await tester.pumpAndSettle();

      // Key yang beda memaksa State baru — persis seperti dashboard yang
      // dibongkar-pasang waktu pindah tab atau balik dari layar lain.
      await pasang(
        tester,
        container: c,
        pengunduh: _PengunduhPalsu(),
        key: const Key('kedua'),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
    });

    testWidgets('gagal cek versi tidak menghabiskan giliran', (tester) async {
      // Giliran diambil PALING AKHIR justru buat ini. Pembukaan aplikasi yang
      // kebetulan tanpa sinyal tidak boleh menghabiskan satu-satunya giliran
      // buat pemutakhiran yang bahkan tidak ketahuan ada.
      final c = wadah(
        layanan: MockVersiService(gagal: true),
        penyiap: _PenyiapPalsu(siap: true),
      );

      await pasang(
        tester,
        container: c,
        pengunduh: _PengunduhPalsu(),
        key: const Key('tanpa-sinyal'),
      );
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);

      // Sinyal balik: pemeriksaan berikutnya menemukan rilisnya.
      final c2 = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          ),
          penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu(siap: true)),
          jalurApkProvider.overrideWithValue(true),
          giliranPemasangOtomatisProvider.overrideWithValue(
            c.read(giliranPemasangOtomatisProvider),
          ),
        ],
      );
      addTearDown(c2.dispose);

      await pasang(
        tester,
        container: c2,
        pengunduh: _PengunduhPalsu(),
        key: const Key('sinyal-balik'),
      );
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
    });
  });

  /// Android 12+: sesudah aplikasi ini tercatat sebagai pemasangnya sendiri,
  /// rilis berikutnya dipasang TANPA ketukan — tapi memasang mematikan proses
  /// aplikasi, jadi waktunya harus benar.
  ///
  /// Tiap test di sini menutup dialog pembaruan lebih dulu: selama dialog
  /// terbuka, dashboard bukan rute teratas, dan itu kasus tersendiri di bawah.
  group('pemutakhiran tanpa ketukan', () {
    ProviderContainer wadahDiam(_SesiPalsu sesi, {bool siap = true}) {
      final c = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', terbaru: rilis()),
          ),
          penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu(siap: siap)),
          pemasangSesiProvider.overrideWithValue(sesi),
        ],
      );
      addTearDown(c.dispose);

      return c;
    }

    Future<void> tutupDialog(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.tap(_nanti);
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    }

    Future<void> tinggalkanAplikasi(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('ditinggal dari dashboard + APK siap + Android mengizinkan: '
        'dipasang diam-diam', (tester) async {
      final sesi = _SesiPalsu(bisa: true);

      await pasang(
        tester,
        container: wadahDiam(sesi),
        pengunduh: _PengunduhPalsu(),
      );
      await tutupDialog(tester);
      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, ['/palsu/sidik-kalibrasi-1.0.60.apk']);
      expect(sesi.diam, [true]);
    });

    testWidgets('dialog pembaruan masih terbuka: TIDAK dipasang diam-diam', (
      tester,
    ) async {
      // Dialognya bisa sedang mengunduh atau membuka pemasang. Pemasangan
      // diam yang berjalan bersamaan dengan itu berebut berkas yang sama.
      final sesi = _SesiPalsu(bisa: true);

      await pasang(
        tester,
        container: wadahDiam(sesi),
        pengunduh: _PengunduhPalsu(),
      );
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);

      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, isEmpty);
    });

    testWidgets('Android belum mengizinkan (pemasangan pertama / Android 11-): '
        'tidak dipasang diam-diam', (tester) async {
      final sesi = _SesiPalsu(bisa: false);

      await pasang(
        tester,
        container: wadahDiam(sesi),
        pengunduh: _PengunduhPalsu(),
      );
      await tutupDialog(tester);
      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, isEmpty);
    });

    testWidgets('ada lembar kerja terbuka di atas dashboard: TIDAK dipasang — '
        'prosesnya mati dan isian hilang', (tester) async {
      final sesi = _SesiPalsu(bisa: true);
      final nav = GlobalKey<NavigatorState>();

      await pasang(
        tester,
        container: wadahDiam(sesi),
        pengunduh: _PengunduhPalsu(),
        navigator: nav,
      );
      await tutupDialog(tester);

      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('lembar kerja')),
        ),
      );
      await tester.pumpAndSettle();

      // Mis. teknisi pindah ke aplikasi kamera buat memotret lembar.
      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, isEmpty);
    });

    testWidgets('APK belum terunduh: tidak dipasang', (tester) async {
      final sesi = _SesiPalsu(bisa: true);

      await pasang(
        tester,
        container: wadahDiam(sesi, siap: false),
        pengunduh: _PengunduhPalsu(),
      );
      await tutupDialog(tester);
      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, isEmpty);
    });

    testWidgets('ditinggal berkali-kali: dicoba sekali saja', (tester) async {
      final sesi = _SesiPalsu(bisa: true);

      await pasang(
        tester,
        container: wadahDiam(sesi),
        pengunduh: _PengunduhPalsu(),
      );
      await tutupDialog(tester);
      await tinggalkanAplikasi(tester);
      await tinggalkanAplikasi(tester);
      await tinggalkanAplikasi(tester);

      expect(sesi.dipasang, hasLength(1));
    });
  });
}

class _SesiPalsu implements PemasangSesi {
  _SesiPalsu({required this.bisa});

  final bool bisa;
  final dipasang = <String>[];
  final diam = <bool>[];

  @override
  Future<bool> bisaTanpaKetukan() async => bisa;

  @override
  Future<String?> pasang(String jalur, {required bool diam}) async {
    dipasang.add(jalur);
    this.diam.add(diam);

    return 'dimulai';
  }
}

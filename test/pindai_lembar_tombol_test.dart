import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/kalibrasi_teknisi_provider.dart';
import 'package:sidik_calibration/providers/kesiapan_pindai_lembar_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/dashboard/dashboard_screen.dart';
import 'package:sidik_calibration/screens/teknisi/kalibrasi_teknisi_screen.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/widgets/tombol_pindai_lembar.dart';

import 'support/daftar_pindai_uji.dart';

/// Tombol "Pindai lembar kerja" di tiga beranda (teknisi, admin, super admin).
///
/// Aturan yang dijaga: tombol HANYA tampil bila saklar pindai menyala DAN
/// daftar jenis lembar server memuat minimal satu jenis yang `boleh` (aturan
/// kontrak `perintah-frontend-templat-asli.md` §2); memuat/galat/kosong/tidak
/// ada yang boleh = tidak ada tombol dan tidak ada pesan galat; daftar
/// diambil SEKALI per sesi.
// Token mock: 1 = admin, 2 = teknisi, 3 = viewer, 5 = super admin.
const _admin = 'mock-token-1';
const _teknisi = 'mock-token-2';
const _viewer = 'mock-token-3';
const _superAdmin = 'mock-token-5';

/// Layanan yang dipantau: hitungan panggilan daftar + bisa dibuat lambat/galat.
class _LayananDaftar extends MockWorksheetScanService {
  _LayananDaftar(List<WorksheetTemplate> daftar, {this.tahan, this.galat})
    : super(daftar: daftar);

  /// Selama belum selesai, [daftarTemplate] menggantung (keadaan memuat).
  final Completer<void>? tahan;
  final bool? galat;

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async {
    final hasil = await super.daftarTemplate(token);
    await tahan?.future;
    if (galat ?? false) throw Exception('tanpa koneksi');

    return hasil;
  }
}

List<Override> _dasar(
  String token,
  MockWorksheetScanService layanan, {
  bool aktif = true,
  TokenStorage? penyimpan,
}) => [
  tokenStorageProvider.overrideWithValue(
    penyimpan ?? InMemoryTokenStorage(token),
  ),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  worksheetScanServiceProvider.overrideWithValue(layanan),
  pindaiLembarAktifProvider.overrideWithValue(aktif),
  historyServiceProvider.overrideWithValue(MockHistoryService()),
  kalibrasiTeknisiServiceProvider.overrideWithValue(
    MockKalibrasiTeknisiService(sesi: const []),
  ),
  dashboardServiceProvider.overrideWithValue(
    MockDashboardService(jeda: Duration.zero),
  ),
];

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  // Kunci baru tiap pemanggilan: tes yang memasang dua kali tidak boleh
  // mewarisi kontainer (dan cache) pemasangan sebelumnya.
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Future<void> _pasang(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

final _tombol = find.byKey(TombolPindaiLembar.kunciTombol);
const _teksTombol = 'Pindai lembar kerja';
const _teksKeterangan = 'Foto lembarnya, aplikasi menyarankan jenisnya';

void main() {
  group('aturan "boleh dipindai" (kontrak §2), kunci hilang = false', () {
    bool boleh(Object? asli) => AsliDiDaftar.dari(asli).boleh;

    test('mode_uji atau siap_pindai saja sudah cukup', () {
      expect(boleh(asliKontrak(uji: true, siap: false)), isTrue);
      expect(boleh(asliKontrak(uji: false, siap: true)), isTrue);
      expect(boleh(asliKontrak(uji: true, siap: true)), isTrue);
    });

    test('keadaan produksi sekarang (saklar mati): ada tapi tidak boleh', () {
      expect(boleh(asliKontrak(uji: false, siap: false)), isFalse);
    });

    test('perlu_konfirmasi_lab menolak apa pun bendera lainnya', () {
      expect(
        boleh(asliKontrak(siap: true, uji: true, konfirmasi: true)),
        isFalse,
      );
    });

    test(
      'revisi null (tak tercatat) tidak boleh, walau bendera lain nyala',
      () {
        expect(boleh(asliKontrak(revisi: null)), isFalse);
        expect(boleh(asliKontrak(revisi: '')), isFalse);
      },
    );

    test('ada: false tidak boleh, walau bendera lain nyala', () {
      expect(boleh(asliKontrak(ada: false, uji: true, siap: true)), isFalse);
    });

    test('kunci hilang atau bentuk aneh = false, tidak melempar', () {
      expect(boleh(null), isFalse);
      expect(boleh('asli'), isFalse);
      expect(boleh(<String, dynamic>{}), isFalse);
      expect(boleh({'ada': true}), isFalse); // tanpa revisi & bendera
      expect(boleh({'ada': true, 'revisi': '4'}), isFalse); // tanpa bendera
      // Bendera yang bukan bool sungguhan tidak menyalakan apa pun.
      expect(boleh({'ada': 1, 'revisi': '4', 'mode_uji': 'true'}), isFalse);
      // perlu_konfirmasi_lab yang ada tapi aneh = menutup pintu.
      expect(
        boleh({
          'ada': true,
          'revisi': '4',
          'mode_uji': true,
          'perlu_konfirmasi_lab': 'ya',
        }),
        isFalse,
      );
    });

    test('perlu_konfirmasi_lab HILANG = menutup pintu (fail-closed)', () {
      expect(
        boleh({
          'ada': true,
          'revisi': '4',
          'mode_uji': true,
          'siap_pindai': true,
        }),
        isFalse,
      );
    });

    test('revisi berbentuk peta/daftar = tidak tercatat, bukan teks', () {
      for (final revisi in <Object>[
        {'a': 1},
        [4],
        true,
      ]) {
        final a = AsliDiDaftar.dari({
          'ada': true,
          'revisi': revisi,
          'mode_uji': true,
          'perlu_konfirmasi_lab': false,
        });
        expect(a.revisi, isNull, reason: '$revisi');
        expect(a.boleh, isFalse, reason: '$revisi');
      }
    });

    test('revisi angka (bukan string) dibaca sebagai teks', () {
      final a = AsliDiDaftar.dari({
        'ada': true,
        'revisi': 4,
        'mode_uji': true,
        'perlu_konfirmasi_lab': false,
      });
      expect(a.revisi, '4');
      expect(a.boleh, isTrue);
    });
  });

  group('parse daftar', () {
    test(
      'entri TANPA kunci asli (server/APK lama): tidak ada, tidak melempar',
      () {
        final t = entriDaftar('ph_meter', tanpaKunciAsli: true);
        expect(t.asli.ada, isFalse);
        expect(t.asli.boleh, isFalse);
        expect(t.templateId, 'ph_meter');
      },
    );

    test(
      'keenam kunci asli terbaca; siap_pindai tingkat atas BUKAN yang asli',
      () {
        final t = entriDaftar(
          'ph_meter',
          asli: asliKontrak(uji: true, siap: false),
        );
        expect(t.siapPindai, isTrue); // lembar CETAK
        expect(t.asli.siapPindai, isFalse); // formulir ASLI
        expect(t.asli.modeUji, isTrue);
        expect(t.asli.kodeDokumen, 'SIDIK-FM-CAL-0509');
        expect(t.asli.revisi, '4');
        expect(t.asli.perluKonfirmasiLab, isFalse);
      },
    );
  });

  group('KesiapanPindaiLembar', () {
    test('Temperatur Indikator dikeluarkan (dipilih lewat gerbangnya)', () {
      final k = KesiapanPindaiLembar.dari([
        entriDaftar('tits', nama: 'Temperature Indicator tanpa Sensor'),
        entriDaftar('tids', nama: 'Temperatur Indikator dengan Sensor'),
        // id tak dikenal tapi judulnya TI: tetap keluar.
        entriDaftar('lainnya', nama: 'Temperature Indicator dengan Sensor'),
        entriDaftar('ph_meter'),
      ]);

      expect([for (final t in k.daftar) t.templateId], ['ph_meter']);
      expect([for (final d in k.dikenal) d.templateId], ['ph_meter']);
    });

    test('hanya Temperatur Indikator yang boleh = tidak ada yang boleh', () {
      final k = KesiapanPindaiLembar.dari([
        entriDaftar('tits', nama: 'Temperature Indicator tanpa Sensor'),
        entriDaftar('ph_meter', asli: asliKontrak(uji: false)),
      ]);

      expect(k.adaYangBoleh, isFalse);
    });

    test('bolehDipindai per id; id asing = false', () {
      final k = KesiapanPindaiLembar.dari([
        entriDaftar('ph_meter'),
        entriDaftar(
          'turbidimeter',
          nama: 'Turbidimeter',
          asli: asliKontrak(konfirmasi: true),
        ),
      ]);

      expect(k.bolehDipindai('ph_meter'), isTrue);
      expect(k.bolehDipindai('turbidimeter'), isFalse);
      expect(k.bolehDipindai('tidak_ada'), isFalse);
      // Jenis yang belum siap tetap dikenal (kodenya bisa terbaca).
      expect(k.dikenal.map((d) => d.templateId), contains('turbidimeter'));
    });
  });

  group('beranda teknisi', () {
    Future<void> buka(
      WidgetTester tester,
      MockWorksheetScanService layanan, {
      bool aktif = true,
    }) => _pasang(
      tester,
      _app(
        const KalibrasiTeknisiScreen(),
        _dasar(_teknisi, layanan, aktif: aktif),
      ),
    );

    testWidgets('ada jenis yang boleh + saklar nyala: tombol tampil DI BAWAH '
        'Kalibrasi baru, lengkap dengan keterangannya', (tester) async {
      await buka(
        tester,
        MockWorksheetScanService(daftar: [entriDaftar('ph_meter')]),
      );

      expect(_tombol, findsOneWidget);
      expect(find.text(_teksTombol), findsOneWidget);
      expect(find.text(_teksKeterangan), findsOneWidget);

      final mulai = find.byKey(const ValueKey('tombol-mulai-kalibrasi'));
      expect(mulai, findsOneWidget);
      expect(
        tester.getTopLeft(_tombol).dy,
        greaterThan(tester.getBottomLeft(mulai).dy),
      );
      // Tombol utama tidak tergeser/terganti.
      expect(find.text('Kalibrasi baru'), findsOneWidget);
    });

    testWidgets('saklar pindai MATI: tidak ada tombol, dan server tidak '
        'ditanya', (tester) async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      await buka(tester, layanan, aktif: false);

      expect(_tombol, findsNothing);
      expect(layanan.jumlahDaftarDiminta, 0);
      expect(
        find.byKey(const ValueKey('tombol-mulai-kalibrasi')),
        findsOneWidget,
      );
    });

    testWidgets('keadaan produksi sekarang (ada tapi tidak ada yang boleh): '
        'tidak ada tombol', (tester) async {
      await buka(
        tester,
        MockWorksheetScanService(
          daftar: [
            entriDaftar('ph_meter', asli: asliKontrak(uji: false, siap: false)),
            entriDaftar(
              'turbidimeter',
              nama: 'Turbidimeter',
              asli: asliKontrak(uji: false),
            ),
          ],
        ),
      );

      expect(_tombol, findsNothing);
      expect(find.text(_teksKeterangan), findsNothing);
    });

    testWidgets('semua perlu_konfirmasi_lab: tidak ada tombol', (tester) async {
      await buka(
        tester,
        MockWorksheetScanService(
          daftar: [
            entriDaftar(
              'turbidimeter',
              asli: asliKontrak(konfirmasi: true, uji: true),
            ),
            entriDaftar(
              'do_meter',
              asli: asliKontrak(konfirmasi: true, siap: true),
            ),
          ],
        ),
      );

      expect(_tombol, findsNothing);
    });

    testWidgets('revisi tak tercatat (null): tidak ada tombol', (tester) async {
      await buka(
        tester,
        MockWorksheetScanService(
          daftar: [entriDaftar('ph_meter', asli: asliKontrak(revisi: null))],
        ),
      );

      expect(_tombol, findsNothing);
    });

    testWidgets('kunci asli hilang di semua entri (server lama): tidak ada '
        'tombol', (tester) async {
      await buka(
        tester,
        MockWorksheetScanService(
          daftar: [entriDaftar('ph_meter', tanpaKunciAsli: true)],
        ),
      );

      expect(_tombol, findsNothing);
    });

    testWidgets('daftar kosong: tidak ada tombol', (tester) async {
      await buka(tester, MockWorksheetScanService(daftar: const []));

      expect(_tombol, findsNothing);
    });

    testWidgets('sedang memuat: tidak ada tombol; sesudah datang, tampil', (
      tester,
    ) async {
      final tahan = Completer<void>();
      await tester.binding.setSurfaceSize(const Size(900, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          const KalibrasiTeknisiScreen(),
          _dasar(
            _teknisi,
            _LayananDaftar([entriDaftar('ph_meter')], tahan: tahan),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(_tombol, findsNothing);

      tahan.complete();
      await tester.pumpAndSettle();

      expect(_tombol, findsOneWidget);
    });

    testWidgets('galat/tanpa koneksi: tidak ada tombol dan TIDAK ada pesan '
        'galat', (tester) async {
      await buka(
        tester,
        _LayananDaftar([entriDaftar('ph_meter')], galat: true),
      );

      expect(_tombol, findsNothing);
      expect(find.text(_teksKeterangan), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('koneksi'), findsNothing);
      // Jalur manual tidak terganggu.
      expect(
        find.byKey(const ValueKey('tombol-mulai-kalibrasi')),
        findsOneWidget,
      );
    });

    testWidgets('tarik-segarkan meminta daftar lagi (satu-satunya jalan '
        'melewati cache)', (tester) async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      await buka(tester, layanan);
      expect(layanan.jumlahDaftarDiminta, 1);

      // Sama dengan tarikan jari (ListView pendek tidak bisa ditarik di tes).
      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(layanan.jumlahDaftarDiminta, 2);
      expect(_tombol, findsOneWidget);
    });
  });

  group('beranda admin (Master Data)', () {
    testWidgets('tombol tampil di bawah Mulai kalibrasi, di atas Tambah alat', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DashboardScreen(),
          _dasar(
            _admin,
            MockWorksheetScanService(daftar: [entriDaftar('ph_meter')]),
          ),
        ),
      );

      expect(_tombol, findsOneWidget);

      final mulai = find.text('Mulai kalibrasi');
      final tambah = find.text('Tambah alat');
      expect(mulai, findsOneWidget);
      expect(tambah, findsOneWidget);
      expect(
        tester.getTopLeft(_tombol).dy,
        greaterThan(tester.getBottomLeft(mulai).dy),
      );
      expect(
        tester.getTopLeft(tambah).dy,
        greaterThan(tester.getBottomLeft(_tombol).dy),
      );
    });

    testWidgets('tarik-segarkan meminta daftar lagi', (tester) async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      await _pasang(
        tester,
        _app(const DashboardScreen(), _dasar(_admin, layanan)),
      );
      expect(layanan.jumlahDaftarDiminta, 1);

      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(layanan.jumlahDaftarDiminta, 2);
      expect(_tombol, findsOneWidget);
    });

    testWidgets('tidak ada yang boleh: tidak ada tombol, aksi cepat utuh', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DashboardScreen(),
          _dasar(
            _admin,
            MockWorksheetScanService(
              daftar: [entriDaftar('ph_meter', asli: asliKontrak(uji: false))],
            ),
          ),
        ),
      );

      expect(_tombol, findsNothing);
      expect(find.text('Mulai kalibrasi'), findsOneWidget);
      expect(find.text('Tambah alat'), findsOneWidget);
    });

    testWidgets(
      'viewer TIDAK melihat tombol (dan tidak ada aksi sama sekali)',
      (tester) async {
        final layanan = MockWorksheetScanService(
          daftar: [entriDaftar('ph_meter')],
        );
        await _pasang(
          tester,
          _app(const DashboardScreen(), _dasar(_viewer, layanan)),
        );

        expect(_tombol, findsNothing);
        expect(find.text('Mulai kalibrasi'), findsNothing);
        // Tidak dirender, jadi daftar tidak diminta untuk viewer.
        expect(layanan.jumlahDaftarDiminta, 0);
      },
    );
  });

  group('beranda super admin', () {
    testWidgets(
      'tombol tampil di bawah Mulai kalibrasi, di atas Tugaskan teknisi',
      (tester) async {
        await _pasang(
          tester,
          _app(
            const DashboardScreen(),
            _dasar(
              _superAdmin,
              MockWorksheetScanService(daftar: [entriDaftar('ph_meter')]),
            ),
          ),
        );

        expect(_tombol, findsOneWidget);

        final mulai = find.text('Mulai kalibrasi');
        final tugaskan = find.text('Tugaskan teknisi');
        expect(mulai, findsOneWidget);
        expect(tugaskan, findsOneWidget);
        expect(
          tester.getTopLeft(_tombol).dy,
          greaterThan(tester.getBottomLeft(mulai).dy),
        );
        expect(
          tester.getTopLeft(tugaskan).dy,
          greaterThan(tester.getBottomLeft(_tombol).dy),
        );
      },
    );

    testWidgets('saklar pindai mati: tidak ada tombol, Mulai kalibrasi utuh', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DashboardScreen(),
          _dasar(
            _superAdmin,
            MockWorksheetScanService(daftar: [entriDaftar('ph_meter')]),
            aktif: false,
          ),
        ),
      );

      expect(_tombol, findsNothing);
      expect(find.text('Mulai kalibrasi'), findsOneWidget);
    });

    testWidgets('tidak ada yang boleh: tidak ada tombol', (tester) async {
      await _pasang(
        tester,
        _app(
          const DashboardScreen(),
          _dasar(
            _superAdmin,
            MockWorksheetScanService(
              daftar: [entriDaftar('ph_meter', asli: asliKontrak(uji: false))],
            ),
          ),
        ),
      );

      expect(_tombol, findsNothing);
    });

    testWidgets('tarik-segarkan meminta daftar lagi', (tester) async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      await _pasang(
        tester,
        _app(const DashboardScreen(), _dasar(_superAdmin, layanan)),
      );
      expect(layanan.jumlahDaftarDiminta, 1);

      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(layanan.jumlahDaftarDiminta, 2);
      expect(_tombol, findsOneWidget);
    });
  });

  group('daftar di-cache selama sesi', () {
    /// Satu kontainer = satu sesi aplikasi; pengguna sudah masuk.
    Future<ProviderContainer> sesi(
      WidgetTester tester,
      MockWorksheetScanService layanan, {
      InMemoryTokenStorage? penyimpan,
    }) async {
      final kontainer = ProviderContainer(
        overrides: _dasar(_teknisi, layanan, penyimpan: penyimpan),
      );
      addTearDown(kontainer.dispose);
      await tester.runAsync(() => kontainer.read(authProvider.future));

      return kontainer;
    }

    Widget pohon(ProviderContainer kontainer, Widget isi) =>
        UncontrolledProviderScope(
          container: kontainer,
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: isi),
          ),
        );

    testWidgets('banyak pembangunan ulang dan beranda dibuka-tutup lagi = SATU '
        'panggilan daftar', (tester) async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      final kontainer = await sesi(tester, layanan);

      await tester.pumpWidget(pohon(kontainer, const TombolPindaiLembar()));
      await tester.pumpAndSettle();
      expect(_tombol, findsOneWidget);
      expect(layanan.jumlahDaftarDiminta, 1);

      // Pembangunan ulang berkali-kali (widget induk yang berganti).
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          pohon(kontainer, TombolPindaiLembar(jarakAtas: 8.0 + i)),
        );
        await tester.pump();
      }
      expect(layanan.jumlahDaftarDiminta, 1);

      // Beranda ditinggalkan (tidak ada yang mendengarkan), lalu dibuka lagi.
      await tester.pumpWidget(pohon(kontainer, const SizedBox()));
      await tester.pump();
      await tester.pumpWidget(pohon(kontainer, const TombolPindaiLembar()));
      await tester.pumpAndSettle();

      expect(_tombol, findsOneWidget);
      expect(layanan.jumlahDaftarDiminta, 1);
    });

    testWidgets('GAGAL tidak ikut di-cache: dibuka lagi, dicoba lagi', (
      tester,
    ) async {
      var gagal = true;
      final layanan = _LayananBisaGagal([entriDaftar('ph_meter')], () => gagal);
      final kontainer = await sesi(tester, layanan);

      await tester.pumpWidget(pohon(kontainer, const TombolPindaiLembar()));
      await tester.pumpAndSettle();
      expect(_tombol, findsNothing);
      expect(layanan.jumlahDaftarDiminta, 1);

      await tester.pumpWidget(pohon(kontainer, const SizedBox()));
      await tester.pump();
      gagal = false;
      await tester.pumpWidget(pohon(kontainer, const TombolPindaiLembar()));
      await tester.pumpAndSettle();

      expect(layanan.jumlahDaftarDiminta, 2);
      expect(_tombol, findsOneWidget);
    });

    test('ganti akun: daftar BENAR-BENAR diminta lagi (dihitung); keluar akun '
        '= kosong tanpa memanggil server', () async {
      final layanan = MockWorksheetScanService(
        daftar: [entriDaftar('ph_meter')],
      );
      final penyimpan = InMemoryTokenStorage(_teknisi);
      final kontainer = ProviderContainer(
        overrides: _dasar(_teknisi, layanan, penyimpan: penyimpan),
      );
      addTearDown(kontainer.dispose);
      await kontainer.read(authProvider.future);

      // Pendengar = beranda yang sedang terbuka.
      final langganan = kontainer.listen(
        kesiapanPindaiLembarProvider,
        (_, _) {},
      );
      addTearDown(langganan.close);

      Future<KesiapanPindaiLembar> baca() =>
          kontainer.read(kesiapanPindaiLembarProvider.future);

      // Akun A (teknisi).
      expect((await baca()).adaYangBoleh, isTrue);
      expect(layanan.jumlahDaftarDiminta, 1);

      // Keluar akun: token hilang, pengguna kosong => kosong, server tak ditanya.
      await penyimpan.clear();
      kontainer.invalidate(authProvider);
      await kontainer.read(authProvider.future);
      expect((await baca()).adaYangBoleh, isFalse);
      expect(layanan.jumlahDaftarDiminta, 1);

      // Akun B (admin, id lain) masuk di HP yang sama.
      await penyimpan.write(_admin);
      kontainer.invalidate(authProvider);
      await kontainer.read(authProvider.future);
      expect((await baca()).adaYangBoleh, isTrue);
      expect(layanan.jumlahDaftarDiminta, 2);
    });
  });
}

/// Gagal selama [gagal] benar; dipakai membuktikan galat tidak di-cache.
class _LayananBisaGagal extends MockWorksheetScanService {
  _LayananBisaGagal(List<WorksheetTemplate> daftar, this.gagal)
    : super(daftar: daftar);

  final bool Function() gagal;

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async {
    final hasil = await super.daftarTemplate(token);
    if (gagal()) throw Exception('tanpa koneksi');

    return hasil;
  }
}

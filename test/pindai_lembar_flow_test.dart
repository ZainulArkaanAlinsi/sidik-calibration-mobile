import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/kesiapan_pindai_lembar_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/pindai_lembar_flow.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/widgets/pilih_jenis_lembar_sheet.dart';
import 'package:sidik_calibration/widgets/tombol_pindai_lembar.dart';

import 'support/daftar_pindai_uji.dart';

/// Alur "Pindai lembar kerja" dari beranda (Opsi A) dengan sumber foto dan
/// pembaca halaman TIRUAN: yang diuji penyambungannya — foto -> petunjuk
/// jenis -> SATU konfirmasi -> lembar kerja KOSONG — dan aturan kerasnya:
/// tidak ada navigasi/isian tanpa konfirmasi, pembaca selalu ditutup, kode
/// yang ambigu tidak memilihkan.
const _teknisi = 'mock-token-2';

/// Pembaca halaman yang membaca teks berbeda per putaran, dan mencatat apa
/// yang dilihatnya.
class _PembacaPutaran implements PembacaHalaman {
  _PembacaPutaran(
    this.teksPerPutaran, {
    this.melempar = false,
    this.tutupMelempar = false,
  });

  /// Teks halaman pada pembacaan ke-0, ke-1, ... (habis = kosong).
  final List<String> teksPerPutaran;
  final bool melempar;

  /// `tutup()` sendiri melempar (sumber daya native rusak).
  final bool tutupMelempar;

  int jumlahBaca = 0;
  bool ditutup = false;

  /// Orientasi EXIF yang diminta alur untuk tiap pembacaan, dan ukuran citra
  /// yang diserahkan (putaran 90/270 menukar lebar-tinggi).
  final orientasi = <int?>[];
  final ukuran = <({int w, int h})>[];

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    orientasi.add(asli?.orientasi);
    ukuran.add((w: citra.width, h: citra.height));
    final i = jumlahBaca++;
    if (melempar) throw StateError('ML Kit rusak');

    final teks = i < teksPerPutaran.length ? teksPerPutaran[i] : '';
    if (teks.isEmpty) return const [];

    return [
      (teks: teks, kotak: const Rect.fromLTWH(0, 0, 200, 20), keyakinan: null),
    ];
  }

  @override
  Future<void> tutup() async {
    ditutup = true;
    if (tutupMelempar) throw StateError('tutup gagal');
  }
}

const _kakiPh = 'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509';

/// [daftarTemplate] yang bisa dibuat gagal (tanpa koneksi).
class _LayananDaftar extends MockWorksheetScanService {
  _LayananDaftar(List<WorksheetTemplate> daftar, {this.gagal = false})
    : super(daftar: daftar);

  final bool gagal;

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async {
    final hasil = await super.daftarTemplate(token);
    if (gagal) throw Exception('tanpa koneksi');

    return hasil;
  }
}

/// Semua yang dibutuhkan alur, tombol, dan LembarKerjaScreen saat dibuka.
class _Uji {
  _Uji({
    required this.daftar,
    this.pembaca,
    this.fotoRusak = false,
    this.batalKamera = false,
    this.galatKamera,
    bool gagalDaftar = false,
  }) : layanan = _LayananDaftar(daftar, gagal: gagalDaftar) {
    final dir = Directory.systemTemp.createTempSync('pindai-lembar');
    berkas = File('${dir.path}/lembar.png')
      ..writeAsBytesSync(
        fotoRusak ? [1, 2, 3] : img.encodePng(img.Image(width: 64, height: 48)),
      );
    sumber = MockSumberFoto(
      file: berkas,
      dibatalkan: batalKamera,
      galat: galatKamera,
    );
  }

  final List<WorksheetTemplate> daftar;
  final _PembacaPutaran? pembaca;
  final bool fotoRusak;
  final bool batalKamera;
  final Object? galatKamera;

  final MockWorksheetScanService layanan;
  late final File berkas;
  late final MockSumberFoto sumber;

  /// Berapa kali pabrik membuat pembaca halaman.
  int pembacaDibuat = 0;

  List<Override> get overrides => [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_teknisi)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    worksheetScanServiceProvider.overrideWithValue(layanan),
    pindaiLembarAktifProvider.overrideWithValue(true),
    sumberFotoProvider.overrideWithValue(sumber),
    pabrikPembacaPindaiProvider.overrideWithValue((
      sel: MockPembacaSel.new,
      qr: () => throw UnimplementedError('QR tidak dipakai mengenali jenis'),
      halaman: () {
        pembacaDibuat++;

        return pembaca!;
      },
    )),
    // Untuk LembarKerjaScreen yang dibuka sesudah konfirmasi.
    lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
    jamProvider.overrideWithValue(() => DateTime(2026, 11, 15, 10, 30)),
  ];
}

final _tombol = find.byKey(TombolPindaiLembar.kunciTombol);
final _jlPakai = find.byKey(PilihJenisLembarSheet.kunciPakai);

/// Daftar bawaan: pH (0509) siap; Turbidimeter (0531) perlu konfirmasi lab;
/// Oven dan Furnace sama-sama memakai 0504 (kode bersama); Temperatur
/// Indikator (dikeluarkan dari daftar).
List<WorksheetTemplate> _daftar() => [
  entriDaftar('ph_meter'),
  entriDaftar(
    'turbidimeter',
    nama: 'Turbidimeter',
    kode: 'SIDIK-FM-CAL-0531',
    asli: asliKontrak(kode: 'SIDIK-FM-CAL-0531', konfirmasi: true),
  ),
  entriDaftar('oven', nama: 'Oven', kode: 'SIDIK-FM-CAL-0504'),
  entriDaftar('furnace', nama: 'Furnace', kode: 'SIDIK-FM-CAL-0504'),
  entriDaftar(
    'tits',
    nama: 'Temperature Indicator tanpa Sensor',
    kode: 'SIDIK-FM-CAL-0541',
  ),
];

Future<void> _pasang(WidgetTester tester, _Uji uji, {Widget? isi}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: uji.overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: isi ?? const TombolPindaiLembar()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Decode & putar jalan di Isolate (IO sungguhan): beri waktu di luar jam
/// palsu test sampai [selesai].
Future<void> _tunggu(
  WidgetTester tester,
  bool Function() selesai, {
  int maks = 60,
}) async {
  for (var i = 0; i < maks; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (selesai()) return;
  }
}

bool _adaSheet() => find.byType(PilihJenisLembarSheet).evaluate().isNotEmpty;
bool _adaSnack() => find.byType(SnackBar).evaluate().isNotEmpty;

/// Ketuk tombol beranda dan tunggu lembar pilihan (atau pesan) muncul.
Future<void> _pindai(WidgetTester tester) async {
  await tester.tap(_tombol);
  await tester.pump();
  await _tunggu(tester, () => _adaSheet() || _adaSnack());
  // Lembar bawah selesai meluncur; pesan (snackbar) JANGAN ditunggu habis.
  if (_adaSheet()) await tester.pumpAndSettle();
}

bool _barisTerpilih(WidgetTester tester, String id) => tester
    .widget<ListTile>(find.byKey(PilihJenisLembarSheet.kunciBaris(id)))
    .selected;

void main() {
  group('kode formulir terbaca', () {
    testWidgets('0509: dipilih-awal, TIDAK ada navigasi sebelum "Pakai jenis '
        'lembar ini" ditekan, lalu lembar terbuka KOSONG dalam tema beku', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran([_kakiPh]);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      // Byte foto kamera, dibaca sebelum alur menghapus berkasnya.
      final bitaKamera = uji.berkas.readAsBytesSync();
      await _pasang(tester, uji);
      expect(_tombol, findsOneWidget);

      await _pindai(tester);

      // Lembar pilihan: pH dipilih-awal, belum ada layar lain.
      expect(find.byType(PilihJenisLembarSheet), findsOneWidget);
      expect(
        find.text('Kode formulir terbaca: SIDIK-FM-CAL-0509'),
        findsOneWidget,
      );
      expect(_barisTerpilih(tester, 'ph_meter'), isTrue);
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(
        tester.widget<FilledButton>(_jlPakai).onPressed,
        isNotNull,
        reason: 'usulan tepat satu boleh langsung dikonfirmasi',
      );

      // Pembaca: satu kali baca (berhenti begitu kode terbaca), ditutup, dan
      // dialog progres sudah hilang. Tidak ada pindai sel apa pun.
      expect(pembaca.jumlahBaca, 1);
      expect(pembaca.ditutup, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.sumber.maxWidthTerakhir, 4200);
      expect(uji.sumber.kualitasTerakhir, 100);
      expect(uji.layanan.terkirim, isEmpty);
      // Berkas kamera dihapus begitu bitanya terbaca.
      expect(uji.berkas.existsSync(), isFalse);

      // Konfirmasi.
      await tester.tap(_jlPakai);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final lembar = tester.widget<LembarKerjaScreen>(
        find.byType(LembarKerjaScreen),
      );
      expect(lembar.profil, 'ph_meter');
      expect(lembar.judulTambahan, 'pH Meter');
      expect(lembar.sesiId, isNull);
      // Foto yang sama ikut ke lembar kerja (Opsi B): byte JPEG kamera apa
      // adanya, bukan citra hasil decode, supaya teknisi memotret SEKALI.
      expect(lembar.fotoAwal, isNotNull);
      expect(lembar.fotoAwal, orderedEquals(bitaKamera));
      // Dibungkus BekuLembarKerja (kontrak L1a): tema beku, bukan tema app.
      expect(
        find.ancestor(
          of: find.byType(LembarKerjaScreen),
          matching: find.byType(BekuLembarKerja),
        ),
        findsOneWidget,
      );
      // Nol sel terisi: tidak ada isian kotor, tidak ada pindai yang jalan
      // sendiri (pembaca hanya dibuat SEKALI, untuk mengenali jenis), kamera
      // dibuka SEKALI (oleh alur ini), tidak ada kiriman pindai.
      expect(uji.pembacaDibuat, 1);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(LembarKerjaScreen)),
        ).read(lembarKotorProvider),
        0,
      );
      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.layanan.terkirim, isEmpty);
    });

    testWidgets('batal di lembar pilihan = selesai tanpa layar apa pun, '
        'tombol bisa dipakai lagi', (tester) async {
      final pembaca = _PembacaPutaran([_kakiPh]);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);
      expect(find.byType(PilihJenisLembarSheet), findsOneWidget);

      Navigator.of(tester.element(find.byType(PilihJenisLembarSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PilihJenisLembarSheet), findsNothing);
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(pembaca.ditutup, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: _tombol,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('kode AMBIGU (0504 dipakai Oven dan Furnace): tanpa pilihan '
        'awal, "Pakai" mati sampai teknisi memilih', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(
        find.text(
          'Kode ini dipakai beberapa jenis lembar. Pilih yang sesuai dengan alat Anda.',
        ),
        findsOneWidget,
      );
      expect(_barisTerpilih(tester, 'oven'), isFalse);
      expect(_barisTerpilih(tester, 'furnace'), isFalse);
      expect(tester.widget<FilledButton>(_jlPakai).onPressed, isNull);
      expect(find.byType(LembarKerjaScreen), findsNothing);

      // Teknisi memilih sendiri, baru bisa lanjut.
      await tester.tap(find.byKey(PilihJenisLembarSheet.kunciBaris('oven')));
      await tester.pump();
      expect(tester.widget<FilledButton>(_jlPakai).onPressed, isNotNull);

      await tester.tap(_jlPakai);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen)).profil,
        'oven',
      );
    });

    testWidgets('kode terbaca di putaran 90 derajat: dicoba lagi sampai '
        'ketemu, citra benar-benar diputar, lalu berhenti', (tester) async {
      final pembaca = _PembacaPutaran(['', _kakiPh]);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, 2);
      expect(pembaca.ukuran, [(w: 64, h: 48), (w: 48, h: 64)]);
      // Orientasi EXIF yang diberikan ke ML Kit: 1 (tegak), 6 (putar 90).
      expect(pembaca.orientasi, [1, 6]);
      expect(_barisTerpilih(tester, 'ph_meter'), isTrue);
      expect(pembaca.ditutup, isTrue);
    });

    testWidgets('kode terbaca tapi tidak dikenal server: berhenti di putaran '
        'itu, pesan jelas, tidak memilihkan apa pun', (tester) async {
      final pembaca = _PembacaPutaran(['SIDIK-FM-CAL-0599']);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, 1);
      expect(find.textContaining('SIDIK-FM-CAL-0599'), findsWidgets);
      expect(tester.widget<FilledButton>(_jlPakai).onPressed, isNull);
    });

    testWidgets('jenis yang BELUM boleh dipindai (perlu konfirmasi lab) '
        'dipilih: pesan, tanpa membuka lembar', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0531']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      // Dikenali (kodenya terbaca) dan dipilih-awal...
      expect(_barisTerpilih(tester, 'turbidimeter'), isTrue);

      await tester.tap(_jlPakai);
      await tester.pumpAndSettle();

      // ...tetapi server menolak memindainya: pesan, bukan lembar.
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(
        find.text('Formulir ini belum bisa dipindai. Isi manual dulu.'),
        findsOneWidget,
      );
    });
  });

  group('kode tidak terbaca', () {
    testWidgets('empat putaran habis tanpa kode: daftar manual tersedia, '
        '"Pakai" mati, Temperatur Indikator tidak ada di daftar', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran(const []);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, 4);
      expect(pembaca.orientasi, [1, 6, 3, 8]);
      expect(pembaca.ukuran, [
        (w: 64, h: 48),
        (w: 48, h: 64),
        (w: 64, h: 48),
        (w: 48, h: 64),
      ]);
      expect(pembaca.ditutup, isTrue);

      expect(
        find.text('Kode formulir tidak terbaca. Pilih jenis lembar sendiri.'),
        findsOneWidget,
      );
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(tester.widget<FilledButton>(_jlPakai).onPressed, isNull);

      // Tombol pilih manual SELALU ada; daftar manual memuat jenis yang
      // dikenal server, kecuali Temperatur Indikator (lewat gerbangnya).
      await tester.ensureVisible(
        find.byKey(PilihJenisLembarSheet.kunciPilihManual),
      );
      await tester.tap(find.byKey(PilihJenisLembarSheet.kunciPilihManual));
      await tester.pumpAndSettle();

      expect(
        find.byKey(PilihJenisLembarSheet.kunciBaris('ph_meter')),
        findsOneWidget,
      );
      expect(
        find.byKey(PilihJenisLembarSheet.kunciBaris('oven')),
        findsOneWidget,
      );
      expect(
        find.byKey(PilihJenisLembarSheet.kunciBaris('tits')),
        findsNothing,
      );
    });
  });

  group('berhenti dengan aman', () {
    testWidgets('kamera dibatalkan: pembaca tidak dibuat, tidak ada lembar '
        'pilihan', (tester) async {
      final pembaca = _PembacaPutaran([_kakiPh]);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca, batalKamera: true);
      await _pasang(tester, uji);

      await tester.tap(_tombol);
      await tester.pump();
      await _tunggu(tester, () => false, maks: 5);

      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.pembacaDibuat, 0);
      expect(find.byType(PilihJenisLembarSheet), findsNothing);
      expect(find.byType(LembarKerjaScreen), findsNothing);
    });

    testWidgets('galat kamera (izin ditolak): pesan jelas, tanpa pembaca', (
      tester,
    ) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        galatKamera: Exception('camera_access_denied'),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(uji.pembacaDibuat, 0);
      expect(find.byType(PilihJenisLembarSheet), findsNothing);
      // Galat mentah tidak sampai ke layar.
      expect(find.textContaining('camera_access_denied'), findsNothing);
    });

    testWidgets('foto tak terbaca (rusak): pesan, tanpa pembaca', (
      tester,
    ) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        fotoRusak: true,
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(
        find.text('Foto tidak bisa dibaca. Coba jepret ulang.'),
        findsOneWidget,
      );
      expect(uji.pembacaDibuat, 0);
      expect(find.byType(PilihJenisLembarSheet), findsNothing);
    });

    testWidgets('pembaca melempar: pembaca TETAP ditutup, dialog progres '
        'hilang, pesan umum, tanpa lembar pilihan', (tester) async {
      final pembaca = _PembacaPutaran(const [], melempar: true);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.ditutup, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PilihJenisLembarSheet), findsNothing);
      expect(
        find.text('Foto gagal diproses. Isi manual atau coba foto ulang.'),
        findsOneWidget,
      );
      expect(find.textContaining('ML Kit rusak'), findsNothing);
    });

    testWidgets('menutup pembaca melempar: dialog progres tetap hilang dan '
        'alur lanjut ke lembar pilihan', (tester) async {
      final pembaca = _PembacaPutaran([_kakiPh], tutupMelempar: true);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.ditutup, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PilihJenisLembarSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ketukan berulang tidak melahirkan dua alur', (tester) async {
      final uji = _Uji(daftar: _daftar(), pembaca: _PembacaPutaran([_kakiPh]));
      await _pasang(tester, uji);

      await tester.tap(_tombol);
      await tester.pump();
      // Selama alur berjalan tombolnya mati.
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: _tombol,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(_tombol, warnIfMissed: false);
      await _tunggu(tester, _adaSheet);

      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.pembacaDibuat, 1);
    });
  });

  group('daftar tidak tersedia saat ditekan (alur dipanggil langsung)', () {
    /// Pemanggil polos + pemantau provider (menjaganya hidup, seperti beranda).
    Widget pemanggil() => Consumer(
      builder: (context, ref, _) {
        ref.watch(kesiapanPindaiLembarProvider);

        return ElevatedButton(
          onPressed: () => pindaiLembarKerja(context: context, ref: ref),
          child: const Text('pindai'),
        );
      },
    );

    testWidgets('gagal memuat daftar: pesan butuh koneksi, kamera TIDAK '
        'dibuka', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        gagalDaftar: true,
      );
      await _pasang(tester, uji, isi: pemanggil());

      await tester.tap(find.text('pindai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Daftar jenis lembar butuh koneksi. Coba lagi atau mulai manual.',
        ),
        findsOneWidget,
      );
      expect(uji.sumber.jumlahAmbil, 0);
      expect(uji.pembacaDibuat, 0);
    });

    testWidgets('tidak ada jenis yang boleh: pesan belum siap, kamera TIDAK '
        'dibuka', (tester) async {
      final uji = _Uji(
        daftar: [entriDaftar('ph_meter', asli: asliKontrak(uji: false))],
        pembaca: _PembacaPutaran([_kakiPh]),
      );
      await _pasang(tester, uji, isi: pemanggil());

      await tester.tap(find.text('pindai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Formulir ini belum bisa dipindai. Isi manual dulu.'),
        findsOneWidget,
      );
      expect(uji.sumber.jumlahAmbil, 0);
    });
  });
}

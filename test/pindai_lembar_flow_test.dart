import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/catatan_identifikasi_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/kesiapan_pindai_lembar_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/tanda_cek_sel.dart'
    show PanelGerbangCek;
import 'package:sidik_calibration/screens/pindai/banner_jenis_dari_foto.dart';
import 'package:sidik_calibration/screens/pindai/blok_identitas_foto.dart';
import 'package:sidik_calibration/screens/pindai/pindai_lembar_flow.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/catatan_identifikasi_lembar.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/widgets/pilih_alat_ringkas_sheet.dart';
import 'package:sidik_calibration/widgets/pilih_jenis_ringkas_sheet.dart';
import 'package:sidik_calibration/widgets/tombol_pindai_lembar.dart';

import 'support/daftar_pindai_uji.dart';
import 'support/halaman_identitas_uji.dart';

/// Alur "Pindai lembar kerja" dari beranda — SATU pintu foto: foto -> jenis
/// dikenali OTOMATIS (kode unik + skor tinggi) -> lembar yang tepat terbuka ->
/// foto yang sama dibaca sendiri -> teknisi memeriksa. Sumber foto, pembaca
/// halaman, dan mesin baca TIRUAN: yang diuji penyambungannya dan aturan
/// kerasnya (kandidat ganda = satu ketukan, tidak yakin = jujur, gerbang
/// kesiapan dihormati, foto tidak keluar HP, tidak ada dua pintu foto).
const _teknisi = 'mock-token-2';
const _kakiPh = 'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509';

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
  int jumlahTutup = 0;
  bool get ditutup => jumlahTutup > 0;

  /// Orientasi EXIF yang diminta alur untuk tiap pembacaan, dan ukuran citra
  /// yang diserahkan (putaran 90/270 menukar lebar-tinggi).
  final orientasi = <int?>[];
  final ukuran = <({int w, int h})>[];
  final jpeg = <Uint8List?>[];

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    orientasi.add(asli?.orientasi);
    ukuran.add((w: citra.width, h: citra.height));
    jpeg.add(asli?.jpeg);
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
    jumlahTutup++;
    if (tutupMelempar) throw StateError('tutup gagal');
  }
}

/// Pembaca halaman yang menyerahkan ELEMEN teks berikut kotaknya (seperti ML
/// Kit sehalaman) pada pembacaan pertama, lalu kosong. Bahan identitas kertas.
class _PembacaElemen implements PembacaHalaman {
  _PembacaElemen(this.halaman);

  final List<TeksTerbaca> halaman;
  int jumlahBaca = 0;
  int jumlahTutup = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async =>
      jumlahBaca++ == 0 ? halaman : const [];

  @override
  Future<void> tutup() async => jumlahTutup++;
}

/// [daftarTemplate] yang bisa dibuat gagal (tanpa koneksi).
class _LayananDaftar extends MockWorksheetScanService {
  _LayananDaftar(
    List<WorksheetTemplate> daftar, {
    this.gagal = false,
    super.formulirAsli,
  }) : super(daftar: daftar);

  final bool gagal;

  @override
  Future<List<WorksheetTemplate>> daftarTemplate(String token) async {
    final hasil = await super.daftarTemplate(token);
    if (gagal) throw Exception('tanpa koneksi');

    return hasil;
  }
}

/// Daftar alat per jenis yang bisa diatur (mock bawaan mengabaikan `profil`
/// dan memulangkan semua alat).
class _Alat extends MockEquipmentLookupService {
  _Alat(this.daftar, {this.profilDiminta, super.gagal});

  final List<EquipmentLookup> daftar;
  final List<String?>? profilDiminta;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async {
    profilDiminta?.add(profil);
    if (gagal) throw Exception('server nggak nyaut');

    return daftar;
  }
}

EquipmentLookup _alat(
  int id,
  String nama, {
  String status = 'aktif',
  String pelanggan = '',
}) => EquipmentLookup(
  id: id,
  namaAlat: nama,
  serialNumber: 'SN-$id',
  kategori: 'instrumen-analitik',
  status: status,
  pelangganNama: pelanggan,
);

/// Alat pH yang ikut daftar mock (id 14: bisa dipakai lembar pH).
final _alatPh = daftarAlatMock.firstWhere((a) => a.id == 14);

/// Mesin baca yang BERHASIL membaca dua sel pH: satu kuning (4,01) dan satu
/// merah kosong (wajib diketik). Mencatat JPEG yang diterima.
class _MesinPalsu extends JalankanPindaiAsli {
  _MesinPalsu()
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final diterima = <Uint8List?>[];

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    diterima.add(jpegAsli);
    const kuning = 'sesudah_adjustment|1|1|pembacaan';
    const merah = 'sesudah_adjustment|2|1|pembacaan';

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci == kuning)
            (
              sel: s,
              bacaan: (teks: '4,01', keyakinan: 0.97, didalamKotak: true),
            )
          else if (s.kunci == merah)
            (sel: s, bacaan: (teks: null, keyakinan: null, didalamKotak: true)),
      ],
      gagalDibaca: const {merah},
    );
  }
}

WorksheetTemplate _formulirAsli() {
  final data =
      (jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>);

  return WorksheetTemplate.fromJson({
    'data': {...(data['data'] as Map<String, dynamic>)},
  });
}

/// Semua yang dibutuhkan alur, tombol, dan LembarKerjaScreen saat dibuka.
class _Uji {
  _Uji({
    required this.daftar,
    this.pembaca,
    this.fotoRusak = false,
    this.batalKamera = false,
    this.galatKamera,
    this.alat,
    this.alatGagal = false,
    this.formulirAsli = true,
    this.mesin,
    bool gagalDaftar = false,
  }) : layanan = _LayananDaftar(
         daftar,
         gagal: gagalDaftar,
         formulirAsli: formulirAsli ? _formulirAsli() : null,
       ) {
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
  final PembacaHalaman? pembaca;
  final bool fotoRusak;
  final bool batalKamera;
  final Object? galatKamera;
  final bool formulirAsli;

  /// Alat yang dijawab server untuk jenis mana pun. Bawaan: satu alat pH.
  final List<EquipmentLookup>? alat;
  final bool alatGagal;
  final _MesinPalsu? mesin;

  final MockWorksheetScanService layanan;
  late final File berkas;
  late final MockSumberFoto sumber;
  final catatan = CatatanIdentifikasiMemori();
  final profilAlatDiminta = <String?>[];

  /// Berapa kali pabrik membuat pembaca halaman.
  int pembacaDibuat = 0;

  List<Override> get overrides => [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_teknisi)),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    worksheetScanServiceProvider.overrideWithValue(layanan),
    pindaiLembarAktifProvider.overrideWithValue(true),
    sumberFotoProvider.overrideWithValue(sumber),
    catatanIdentifikasiLembarProvider.overrideWithValue(catatan),
    if (mesin != null) mesinPindaiAsliProvider.overrideWithValue(mesin),
    pabrikPembacaPindaiProvider.overrideWithValue((
      sel: MockPembacaSel.new,
      qr: () => throw UnimplementedError('QR tidak dipakai mengenali jenis'),
      halaman: () {
        pembacaDibuat++;

        return pembaca!;
      },
    )),
    // Untuk LembarKerjaScreen yang dibuka sesudah jenis ditentukan.
    lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      _Alat(
        alat ?? [_alatPh],
        profilDiminta: profilAlatDiminta,
        gagal: alatGagal,
      ),
    ),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
    jamProvider.overrideWithValue(() => DateTime(2026, 11, 15, 10, 30)),
  ];
}

final _tombol = find.byKey(TombolPindaiLembar.kunciTombol);
final _fotoLembar = find.byKey(const ValueKey('tombol-foto-lembar'));
final _banner = find.byKey(BannerJenisDariFoto.kunciBanner);
final _gantiJenis = find.byKey(BannerJenisDariFoto.kunciGanti);

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
  tester.view.physicalSize = const Size(900, 3200);
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
  int maks = 80,
}) async {
  for (var i = 0; i < maks; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (selesai()) return;
  }
}

bool _adaSheetJenis() =>
    find.byType(PilihJenisRingkasSheet).evaluate().isNotEmpty;
bool _adaSheetAlat() =>
    find.byType(PilihAlatRingkasSheet).evaluate().isNotEmpty;
bool _adaLembar() => find.byType(LembarKerjaScreen).evaluate().isNotEmpty;
bool _adaSnack() => find.byType(SnackBar).evaluate().isNotEmpty;

/// Ketuk tombol beranda dan tunggu sampai ada yang tampil: lembar pilihan
/// jenis, lembar pilihan alat, lembar kerja, atau pesan.
Future<void> _pindai(WidgetTester tester) async {
  await tester.tap(_tombol);
  await tester.pump();
  await _tunggu(
    tester,
    () => _adaSheetJenis() || _adaSheetAlat() || _adaLembar() || _adaSnack(),
  );
  // Lembar bawah / route selesai meluncur; pesan (snackbar) JANGAN ditunggu
  // habis.
  if (_adaSheetJenis() || _adaSheetAlat() || _adaLembar()) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

LembarKerjaScreen _lembar(WidgetTester tester) =>
    tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen));

Finder _baris(String id) => find.byKey(PilihJenisRingkasSheet.kunciBaris(id));

void main() {
  group('kode UNIK terbaca: lembar terbuka sendiri, tanpa layar pilihan', () {
    testWidgets('0509: tidak ada lembar pilihan, lembar pH terbuka dalam tema '
        'beku membawa foto yang SAMA; TANPA banner jenis; foto dibaca sendiri '
        'tanpa kamera kedua', (tester) async {
      final pembaca = _PembacaPutaran([_kakiPh]);
      final mesin = _MesinPalsu();
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca, mesin: mesin);
      // Byte foto kamera, dibaca sebelum alur menghapus berkasnya.
      final bitaKamera = uji.berkas.readAsBytesSync();
      await _pasang(tester, uji);
      expect(_tombol, findsOneWidget);

      await _pindai(tester);

      // Tidak ada layar pilihan jenis maupun alat: langsung lembar kerja.
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
      expect(find.byType(PilihAlatRingkasSheet), findsNothing);
      final lembar = _lembar(tester);
      expect(lembar.profil, 'ph_meter');
      expect(lembar.judulTambahan, 'pH Meter');
      expect(lembar.sesiId, isNull);
      final dari = lembar.dariFoto!;
      expect(dari.otomatis, isTrue);
      expect(dari.jenis, 'pH Meter');
      // Alur LINEAR: satu-satunya alat jenis ini TIDAK dipilih sendiri; kode
      // formulir yang terbaca dibawa untuk memilih peta tanpa alat.
      expect(dari.kodeDokumen, 'SIDIK-FM-CAL-0509');
      // Foto yang sama: byte JPEG kamera apa adanya, bukan citra hasil decode.
      expect(dari.jpeg, orderedEquals(bitaKamera));
      // Dibungkus BekuLembarKerja (kontrak L1a): tema beku, bukan tema app.
      expect(
        find.ancestor(
          of: find.byType(LembarKerjaScreen),
          matching: find.byType(BekuLembarKerja),
        ),
        findsOneWidget,
      );
      // Keputusan pemilik 27 Nov 2026: banner "Ganti jenis" tidak dipasang di
      // layar mana pun; teknisi yang melihat jenis keliru memotret ulang.
      expect(
        find.text('Dikenali otomatis: pH Meter (dari foto). Salah?'),
        findsNothing,
      );
      expect(_banner, findsNothing);
      expect(_gantiJenis, findsNothing);

      // Pembaca halaman ditutup; kamera dibuka SEKALI (oleh beranda).
      expect(pembaca.ditutup, isTrue);
      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.sumber.maxWidthTerakhir, 4200);
      expect(uji.sumber.kualitasTerakhir, 100);
      // Berkas kamera dihapus begitu bitanya terbaca.
      expect(uji.berkas.existsSync(), isFalse);

      // Foto yang SAMA dibaca lembar sendiri (mesin menerima byte beranda),
      // tanpa kamera kedua dan tanpa mengunggah apa pun.
      await _tunggu(tester, () => mesin.diterima.isNotEmpty);
      expect(mesin.diterima, hasLength(1));
      expect(mesin.diterima.single, orderedEquals(bitaKamera));
      expect(uji.sumber.jumlahAmbil, 1, reason: 'tidak memotret dua kali');
      expect(uji.layanan.terkirim, isEmpty);
    });

    testWidgets('jenis unik tapi BELUM boleh dipindai (perlu_konfirmasi_lab): '
        'pesan jujur, tanpa lembar, tanpa tombol foto ulang / jenis lain', (
      tester,
    ) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0531']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      // Dikenali (kodenya terbaca bersih dan unik) tetapi server belum
      // mengizinkan memindainya: tidak dibuka sendiri.
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.byType(PilihJenisRingkasSheet), findsOneWidget);
      expect(find.text('Belum bisa dibaca otomatis'), findsOneWidget);
      expect(
        find.textContaining('Lembar Turbidimeter dikenali'),
        findsOneWidget,
      );
      expect(find.byKey(PilihJenisRingkasSheet.kunciFotoUlang), findsNothing);
      expect(find.byKey(PilihJenisRingkasSheet.kunciJenisLain), findsNothing);
      expect(uji.layanan.terkirim, isEmpty);
    });

    testWidgets('mode uji mati (tidak ada jenis yang boleh): kamera TIDAK '
        'dibuka', (tester) async {
      final uji = _Uji(
        daftar: [entriDaftar('ph_meter', asli: asliKontrak(uji: false))],
        pembaca: _PembacaPutaran([_kakiPh]),
      );
      await _pasang(tester, uji);

      // Tombol beranda tersembunyi sendiri bila tidak ada yang boleh.
      expect(_tombol, findsNothing);
    });

    testWidgets('Temperatur Indikator (tits/tids) tidak dibuka dari foto: '
        'kodenya "tidak dikenal" di daftar, jadi pesan jujur', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0541']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.textContaining('SIDIK-FM-CAL-0541'), findsWidgets);
      expect(find.byKey(PilihJenisRingkasSheet.kunciPesan), findsOneWidget);
    });

    testWidgets('kode terbaca di putaran 90 derajat: dicoba lagi sampai '
        'ketemu, citra benar-benar diputar, lalu terbuka sendiri', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran(['', _kakiPh]);
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: pembaca,
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, greaterThanOrEqualTo(2));
      expect(pembaca.ukuran.take(2), [(w: 64, h: 48), (w: 48, h: 64)]);
      // Orientasi EXIF yang diberikan ke ML Kit: 1 (tegak), 6 (putar 90).
      expect(pembaca.orientasi.take(2), [1, 6]);
      expect(_lembar(tester).profil, 'ph_meter');
      expect(pembaca.ditutup, isTrue);
    });
  });

  group('kandidat ganda: SATU ketukan, tidak pernah dipilihkan', () {
    testWidgets('kode bersama (0504: Oven, Furnace): lembar ringkas "Pilih '
        'salah satu", tidak ada yang terbuka sendiri, tidak ada tombol '
        '"Pakai"; satu ketukan membuka lembar yang diketuk', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(find.text('Pilih salah satu'), findsOneWidget);
      expect(
        find.text(
          'Kode ini dipakai beberapa jenis lembar. Pilih yang sesuai dengan alat Anda.',
        ),
        findsOneWidget,
      );
      expect(_baris('oven'), findsOneWidget);
      expect(_baris('furnace'), findsOneWidget);
      // Tidak dipilihkan, dan tidak ada langkah "Pakai jenis lembar ini".
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.text('Pakai jenis lembar ini'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(_baris('oven'));
      await tester.pump();
      await _tunggu(tester, _adaLembar);
      await tester.pump(const Duration(milliseconds: 600));

      final lembar = _lembar(tester);
      expect(lembar.profil, 'oven');
      expect(lembar.dariFoto!.otomatis, isFalse);
      expect(
        find.text('Jenis lembar: Oven (dipilih dari foto). Salah?'),
        findsNothing,
        reason: 'banner "Ganti jenis" tidak dipasang lagi (27 Nov 2026)',
      );
      expect(_banner, findsNothing);
    });

    testWidgets('"Foto ulang" dari lembar ringkas: kamera dibuka lagi, foto '
        'kedua yang unik langsung terbuka sendiri', (tester) async {
      final pembaca = _PembacaPutaran([
        'Revise : 4 SIDIK-FM-CAL-0504',
        '',
        '',
        '',
        _kakiPh,
      ]);
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: pembaca,
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);
      expect(find.byType(PilihJenisRingkasSheet), findsOneWidget);
      expect(uji.sumber.jumlahAmbil, 1);

      // Kamera menghapus berkas sesudah dibaca; sediakan lagi untuk foto kedua.
      uji.berkas.writeAsBytesSync(
        img.encodePng(img.Image(width: 64, height: 48)),
      );
      await tester.tap(find.byKey(PilihJenisRingkasSheet.kunciFotoUlang));
      await tester.pump();
      await _tunggu(tester, _adaLembar);
      await tester.pump(const Duration(milliseconds: 600));

      expect(uji.sumber.jumlahAmbil, 2);
      expect(_lembar(tester).profil, 'ph_meter');
      expect(_lembar(tester).dariFoto!.otomatis, isTrue);
      // Dua kali identifikasi tercatat, plus kejadian foto ulang.
      expect(
        uji.catatan.baris.map((b) => b['kejadian']),
        containsAllInOrder(['identifikasi', 'foto_ulang', 'identifikasi']),
      );
    });

    testWidgets('"Jenis lain..." membuka SEMUA jenis (tanpa Temperatur '
        'Indikator); satu ketukan memilih', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      await tester.ensureVisible(
        find.byKey(PilihJenisRingkasSheet.kunciJenisLain),
      );
      await tester.tap(find.byKey(PilihJenisRingkasSheet.kunciJenisLain));
      await tester.pumpAndSettle();

      expect(_baris('ph_meter'), findsOneWidget);
      expect(_baris('turbidimeter'), findsOneWidget);
      expect(_baris('tits'), findsNothing);

      await tester.ensureVisible(_baris('ph_meter'));
      await tester.tap(_baris('ph_meter'));
      await tester.pump();
      await _tunggu(tester, _adaLembar);

      expect(_lembar(tester).profil, 'ph_meter');
      // Dipilih dari "Jenis lain", bukan dari kandidat foto: dicatat -1.
      final pilihan = uji.catatan.baris.firstWhere(
        (b) => b['kejadian'] == 'pilihan',
      );
      expect(pilihan['dipilih'], 'ph_meter');
      expect(pilihan['urutan_kandidat'], -1);
    });

    testWidgets('jenis yang dipilih ternyata belum boleh dipindai: pesan, '
        'tanpa lembar', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      await tester.ensureVisible(
        find.byKey(PilihJenisRingkasSheet.kunciJenisLain),
      );
      await tester.tap(find.byKey(PilihJenisRingkasSheet.kunciJenisLain));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_baris('turbidimeter'));
      await tester.tap(_baris('turbidimeter'));
      await tester.pumpAndSettle();

      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(
        find.text('Formulir ini belum bisa dipindai. Isi manual dulu.'),
        findsOneWidget,
      );
    });

    testWidgets('menutup lembar ringkas tanpa memilih = selesai tanpa layar '
        'apa pun, pembaca ditutup, tombol bisa dipakai lagi', (tester) async {
      final pembaca = _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);
      expect(find.byType(PilihJenisRingkasSheet), findsOneWidget);

      Navigator.of(tester.element(find.byType(PilihJenisRingkasSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
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
  });

  group('tidak dikenali: pesan jujur, tanpa tebakan', () {
    testWidgets('empat putaran habis tanpa kode: pesan jujur + Foto ulang + '
        'Jenis lain; tidak ada lembar dan tidak ada yang dipilihkan', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran(const []);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, 4);
      expect(pembaca.orientasi, [1, 6, 3, 8]);
      expect(pembaca.ditutup, isTrue);

      expect(find.text('Jenis lembar belum bisa dikenali'), findsOneWidget);
      expect(find.textContaining('tidak menebak'), findsOneWidget);
      expect(find.textContaining('Mulai kalibrasi'), findsWidgets);
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.byKey(PilihJenisRingkasSheet.kunciFotoUlang), findsOneWidget);
      expect(find.byKey(PilihJenisRingkasSheet.kunciJenisLain), findsOneWidget);
      // Tidak ada baris kandidat sama sekali.
      expect(_baris('ph_meter'), findsNothing);

      final id = uji.catatan.baris.single;
      expect(id['keputusan'], 'tak_dikenali');
      expect(id['alasan_tak_dikenali'], 'tidakTerbaca');
    });

    testWidgets('kode terbaca tapi tidak dikenal server: berhenti di putaran '
        'itu, pesan menyebut kodenya, tidak memilihkan apa pun', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran(['SIDIK-FM-CAL-0599']);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.jumlahBaca, 1);
      expect(find.textContaining('SIDIK-FM-CAL-0599'), findsWidgets);
      expect(find.byType(LembarKerjaScreen), findsNothing);
    });
  });

  group(
    'alur LINEAR: tidak ada alat yang dipilihkan sebelum kertas dibaca',
    () {
      final alatDipilih = find.text('pH Meter Mettler Toledo · B628755900');

      testWidgets('satu alat terdaftar untuk jenis ini: TIDAK dipilih sendiri, '
          'tanpa daftar alat; kertas dibaca tanpa alat dengan kode formulir', (
        tester,
      ) async {
        final mesin = _MesinPalsu();
        final uji = _Uji(
          daftar: _daftar(),
          pembaca: _PembacaPutaran([_kakiPh]),
          alat: [
            _alatPh,
            _alat(31, 'pH Meter Lama', status: 'nonaktif'),
          ],
          mesin: mesin,
        );
        await _pasang(tester, uji);
        await _pindai(tester);

        expect(find.byType(PilihAlatRingkasSheet), findsNothing);
        expect(alatDipilih, findsNothing, reason: 'alat tidak dipilihkan');
        await _tunggu(tester, () => mesin.diterima.isNotEmpty);
        // Peta formulir diminta TANPA alat, DENGAN kode formulir dari kertas.
        expect(uji.layanan.kodeAsliDiminta.map((e) => e.equipmentId), [null]);
        expect(uji.layanan.kodeDokumenDiminta, ['SIDIK-FM-CAL-0509']);
      });

      testWidgets(
        'beberapa alat: tidak ada daftar pendek, tidak ada yang dipilih',
        (tester) async {
          final uji = _Uji(
            daftar: _daftar(),
            pembaca: _PembacaPutaran([_kakiPh]),
            alat: [
              _alatPh,
              _alat(21, 'pH Meter Hanna', pelanggan: 'PT CONTOH'),
            ],
            mesin: _MesinPalsu(),
          );
          await _pasang(tester, uji);
          await _pindai(tester);

          expect(find.byType(PilihAlatRingkasSheet), findsNothing);
          expect(find.byType(LembarKerjaScreen), findsOneWidget);
          expect(alatDipilih, findsNothing);
          expect(find.text('pH Meter Hanna · SN-21'), findsNothing);
        },
      );

      testWidgets('daftar alat gagal dimuat: lembar tetap terbuka, tanpa galat '
          'mentah', (tester) async {
        final uji = _Uji(
          daftar: _daftar(),
          pembaca: _PembacaPutaran([_kakiPh]),
          alatGagal: true,
          mesin: _MesinPalsu(),
        );
        await _pasang(tester, uji);
        await _pindai(tester);

        expect(find.byType(LembarKerjaScreen), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.byType(PilihAlatRingkasSheet), findsNothing);
      });

      testWidgets(
        'kode bersama (0504): jenis yang diketuk dari kandidat memakai '
        'KODE TERCETAK sebagai kode_dokumen',
        (tester) async {
          final uji = _Uji(
            daftar: _daftar(),
            pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
            mesin: _MesinPalsu(),
          );
          await _pasang(tester, uji);
          await _pindai(tester);

          await tester.tap(_baris('oven'));
          await tester.pump();
          await _tunggu(tester, _adaLembar);

          expect(_lembar(tester).profil, 'oven');
          expect(_lembar(tester).dariFoto!.kodeDokumen, 'SIDIK-FM-CAL-0504');
        },
      );

      testWidgets('identitas TERTULIS di kertas dibaca dari halaman yang SAMA: '
          'masuk lembar sebagai saran kuning (tanpa gerbang wajib-cek), alat '
          'cocok menunggu ketukan, kertas menang atas master', (tester) async {
        final pembaca = _PembacaElemen(
          halamanPhUji(
            nama: 'pH Meter',
            seri: 'B628755900',
            merk: 'Mettler',
            pemilik: 'PT Tirta Contoh Mandiri',
            kalibrasi: '13 Nov 2026',
          ),
        );
        final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
        await _pasang(tester, uji);
        await _pindai(tester);

        // Halaman dibaca SEKALI untuk jenis dan identitas (pembacaan berikutnya
        // milik pipa sel). Tidak ada alat yang dipilih.
        expect(find.byKey(BlokIdentitasFoto.kunciCocok), findsOneWidget);
        expect(
          find.text('Alat terdaftar: pH Meter Mettler Toledo'),
          findsOneWidget,
        );
        expect(alatDipilih, findsNothing);

        // Identitas kertas ada di kotak lembar sebagai saran. Sejak 27 Nov
        // 2026 tidak ada panel gerbang yang menahan Kirim karenanya.
        String isi(String label) {
          final kotak = find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == label,
          );
          return kotak.evaluate().isEmpty ? '' : label;
        }

        expect(isi('B628755900'), 'B628755900');
        expect(isi('Mettler'), 'Mettler');
        expect(isi('PT Tirta Contoh Mandiri'), 'PT Tirta Contoh Mandiri');
        expect(
          find.byKey(const ValueKey('panel-cek-tahan')),
          findsNothing,
          reason: 'saran identitas tidak lagi ikut gerbang wajib-cek',
        );
        expect(find.byType(PanelGerbangCek), findsNothing);
        expect(
          find.byKey(BlokIdentitasFoto.kunciTanggalKalibrasi),
          findsOneWidget,
          reason: 'tanggal kertas beda dari hari ini: saran, bukan otomatis',
        );

        // Satu ketukan teknisi memasang alat; kertas tetap menang.
        await tester.ensureVisible(
          find.byKey(BlokIdentitasFoto.kunciPakaiAlat),
        );
        await tester.tap(find.byKey(BlokIdentitasFoto.kunciPakaiAlat));
        await tester.pumpAndSettle();

        expect(alatDipilih, findsWidgets);
        expect(isi('Mettler'), 'Mettler', reason: 'kertas menang atas master');
      });

      testWidgets(
        'identitas tidak terbaca: lembar tetap terbuka, tidak ada alat '
        'dipilih atau dibuat, pesan jujur',
        (tester) async {
          final uji = _Uji(
            daftar: _daftar(),
            pembaca: _PembacaElemen(halamanPhUji()),
          );
          await _pasang(tester, uji);
          await _pindai(tester);

          expect(
            find.byKey(BlokIdentitasFoto.kunciTidakTerbaca),
            findsOneWidget,
          );
          expect(alatDipilih, findsNothing);
          expect(find.byKey(BlokIdentitasFoto.kunciPanelBaru), findsNothing);
        },
      );
    },
  );

  group('SATU pintu foto: tidak ada dialog dan tombol foto ganda', () {
    testWidgets('lembar dari foto beranda: tanpa dialog "Mau diisi '
        'bagaimana?", tanpa "Foto worksheet", dan tidak ada tombol foto kedua '
        'pula SESUDAH hasil — satu pintu per layar (beranda)', (tester) async {
      final mesin = _MesinPalsu();
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        mesin: mesin,
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      // Segera sesudah lembar terbuka: tidak ada dialog pilihan cara isi dan
      // tidak ada tombol foto kedua selagi foto dibaca.
      expect(find.text('Mau diisi bagaimana?'), findsNothing);
      expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
      expect(find.byKey(const ValueKey('cara-manual')), findsNothing);
      expect(find.text('Foto worksheet'), findsNothing);
      expect(_fotoLembar, findsNothing);

      // Hasil baca masuk ke layar periksa; sesudah teknisi menutupnya lembar
      // dari foto beranda TIDAK menawarkan tombol "Foto ulang" (teknisi yang
      // ingin memotret ulang kembali ke beranda).
      await _tunggu(tester, () => mesin.diterima.isNotEmpty);
      await _tunggu(
        tester,
        () => find.byType(FotoReviewScreen).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(FotoReviewScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(FotoReviewScreen), findsNothing);
      expect(_fotoLembar, findsNothing);
      expect(find.text('Foto ulang'), findsNothing);
      expect(find.text('Foto worksheet'), findsNothing);
    });
  });

  group('e2e: kode unik -> lembar terbuka -> terbaca -> teknisi memeriksa', () {
    testWidgets('sel yang terbaca masuk lembar sebagai SARAN kuning yang tidak '
        'menahan; sel yang gagal dibaca tetap kosong sampai diketik teknisi', (
      tester,
    ) async {
      final mesin = _MesinPalsu();
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        mesin: mesin,
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      // Lembar terbuka sendiri, lalu foto yang sama dibaca dan layar periksa
      // (yang sudah ada) terbuka. Belum ada satu sel pun di lembar.
      final review = find.byType(FotoReviewScreen);
      await _tunggu(tester, () => review.evaluate().isNotEmpty);
      expect(review, findsOneWidget);
      expect(find.textContaining('bacaan kamera'), findsNothing);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(LembarKerjaScreen, skipOffstage: false)),
        ).read(lembarKotorProvider),
        0,
        reason: 'hasil baca bukan isian sebelum teknisi memasukkannya',
      );

      // Sel merah (gagal dibaca) kosong, wajib diketik; teknisi mengetik dan
      // mencentang SATU PER SATU (tidak ada "terima semua").
      final kotak = find.descendant(
        of: review,
        matching: find.byType(TextField),
      );
      expect(kotak, findsNWidgets(2));
      final isi = [
        for (final e in kotak.evaluate())
          (e.widget as TextField).controller!.text,
      ];
      expect(isi, contains('4,01'), reason: 'saran kuning terisi');
      final iMerah = isi.indexWhere((t) => t.isEmpty);
      expect(iMerah, isNot(-1), reason: 'sel gagal dibaca tetap kosong');
      await tester.enterText(kotak.at(iMerah), '7,01');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      // Keputusan pemilik 27 Nov 2026: yang menahan Masukkan hanya merah
      // kosong. Merah sudah diketik, kuning belum dicentang: Masukkan hidup.
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: review, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
        reason: 'kuning yang belum dicek tidak menahan Masukkan',
      );
      final cek = find.descendant(
        of: review,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith('cek-'),
        ),
      );
      for (var i = 0; i < cek.evaluate().length; i++) {
        await tester.tap(cek.at(i));
      }
      await tester.pump();
      await tester.tap(
        find.descendant(of: review, matching: find.byType(FilledButton)),
      );
      await tester.pumpAndSettle();

      // Kembali ke lembar: isinya masuk (sel kamera tetap kuning di tabel),
      // tetapi TIDAK ada panel gerbang "wajib dicek", tidak ada banner jenis,
      // dan tidak ada tombol "Foto ulang" untuk lembar dari foto beranda.
      expect(find.byType(FotoReviewScreen), findsNothing);
      expect(find.byType(PanelGerbangCek), findsNothing);
      expect(find.textContaining('bacaan kamera'), findsNothing);
      // Dua sel masuk (saran kuning + yang diketik teknisi). Tabelnya ada di
      // halaman 2 lembar, jadi buktinya pemberitahuan dan penanda isian kotor,
      // bukan teks selnya.
      expect(
        find.textContaining(RegExp(r'2 (isian|sel) terisi dari foto')),
        findsOneWidget,
      );
      expect(_banner, findsNothing);
      expect(_fotoLembar, findsNothing);
      expect(find.text('Foto ulang'), findsNothing);
      expect(find.text('Foto worksheet'), findsNothing);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(LembarKerjaScreen)),
        ).read(lembarKotorProvider),
        greaterThan(0),
      );
      // Kamera hanya dibuka sekali (oleh beranda); tidak ada kiriman ke server.
      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.layanan.terkirim, isEmpty);
    });
  });

  group(
    'banner "Ganti jenis" tidak dipasang (keputusan pemilik 27 Nov 2026)',
    () {
      testWidgets('lembar dari foto: tanpa banner, tanpa tombol "Ganti jenis" '
          'atau "Foto ulang"; jenis tetap, foto yang SAMA, kamera tidak dibuka '
          'lagi, tidak ada kejadian ganti_jenis', (tester) async {
        final uji = _Uji(
          daftar: _daftar(),
          pembaca: _PembacaPutaran([_kakiPh]),
          mesin: _MesinPalsu(),
        );
        final bita = uji.berkas.readAsBytesSync();
        await _pasang(tester, uji);
        await _pindai(tester);
        expect(_lembar(tester).profil, 'ph_meter');

        // Selagi foto dibaca tombolnya mati; tunggu layar periksa lalu tutup.
        await _tunggu(
          tester,
          () => find.byType(FilledButton).evaluate().isNotEmpty,
        );
        Navigator.of(tester.element(find.byType(FilledButton))).pop();
        await tester.pumpAndSettle();

        // Tidak ada jalan "Ganti jenis" di lembar: bukan banner, bukan tombol,
        // bukan lembar bawah pilihan jenis.
        expect(_banner, findsNothing);
        expect(_gantiJenis, findsNothing);
        expect(find.text('Ganti jenis'), findsNothing);
        expect(find.text('Ganti jenis lembar'), findsNothing);
        expect(find.byType(PilihJenisRingkasSheet), findsNothing);
        expect(_fotoLembar, findsNothing);
        expect(find.text('Foto ulang'), findsNothing);

        // Lembar tetap yang tadi dibuka, membawa foto yang SAMA; kamera hanya
        // dibuka sekali (oleh beranda) dan tidak ada catatan ganti jenis.
        expect(_lembar(tester).profil, 'ph_meter');
        expect(_lembar(tester).dariFoto!.jpeg, orderedEquals(bita));
        expect(uji.sumber.jumlahAmbil, 1);
        expect(
          uji.catatan.baris.map((b) => b['kejadian']),
          isNot(contains('ganti_jenis')),
        );
      });
    },
  );

  group('privasi dan catatan lokal', () {
    testWidgets('catatan hanya skor, kode cetak, dan keputusan: tanpa citra, '
        'tanpa byte foto, tanpa pengenal alat atau pengguna', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      final b = uji.catatan.baris.single;
      expect(b['kejadian'], 'identifikasi');
      expect(b['keputusan'], 'pilih_satu');
      expect(b['alasan_mesin'], 'kodeBersama');
      expect(b['kode_cocok'], 'SIDIK-FM-CAL-0504');
      expect(b['skor_teratas'], isA<double>());
      expect(b['ambang_auto_buka'], 0.90);
      expect(
        (b['kandidat'] as List).map((k) => (k as Map)['template_id']).toSet(),
        {'oven', 'furnace'},
      );

      // Bisa diserialisasi, kecil, dan tidak memuat apa pun selain teks cetak.
      final json = jsonEncode(b);
      expect(json.length, lessThan(4000));
      for (final terlarang in [
        'jpeg',
        'bita',
        'citra',
        'equipment',
        'alat_id',
        'user',
        'token',
        _teknisi,
      ]) {
        expect(
          json.toLowerCase(),
          isNot(contains(terlarang)),
          reason: terlarang,
        );
      }
    });

    testWidgets('foto tidak dikirim ke mana pun: tidak ada kiriman pindai atau '
        'koreksi ke server selama alur', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran([_kakiPh]),
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);
      await _tunggu(
        tester,
        () => find.byType(FilledButton).evaluate().isNotEmpty,
      );

      expect(uji.layanan.terkirim, isEmpty);
      expect(uji.layanan.koreksiTerkirim, isEmpty);
    });

    test(
      'berkas catatan: JSON Lines, dipangkas, gagal tulis tidak melempar',
      () async {
        final dir = Directory.systemTemp.createTempSync('catatan-id');
        addTearDown(() => dir.deleteSync(recursive: true));
        final catatan = CatatanIdentifikasiBerkas(
          folder: () async => dir,
          batasByte: 600,
          sisaBaris: 3,
        );

        for (var i = 0; i < 12; i++) {
          await catatan.tulis('identifikasi', 'p$i', {'skor': 0.9, 'n': i});
        }

        final baris = File(
          '${dir.path}/${CatatanIdentifikasiBerkas.namaBerkas}',
        ).readAsLinesSync();
        expect(baris.length, lessThanOrEqualTo(8));
        final terakhir = jsonDecode(baris.last) as Map<String, dynamic>;
        expect(terakhir['n'], 11);
        expect(terakhir['kejadian'], 'identifikasi');
        expect(terakhir['waktu'], isA<String>());

        final rusak = CatatanIdentifikasiBerkas(
          folder: () async => throw const FileSystemException('disk penuh'),
        );
        await rusak.tulis('identifikasi', 'x', const {});
      },
    );
  });

  group('berhenti dengan aman', () {
    testWidgets('kamera dibatalkan: pembaca tidak dibuat, tidak ada lembar', (
      tester,
    ) async {
      final pembaca = _PembacaPutaran([_kakiPh]);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca, batalKamera: true);
      await _pasang(tester, uji);

      await tester.tap(_tombol);
      await tester.pump();
      await _tunggu(tester, () => false, maks: 5);

      expect(uji.sumber.jumlahAmbil, 1);
      expect(uji.pembacaDibuat, 0);
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
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
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
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
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
    });

    testWidgets('pembaca melempar: pembaca TETAP ditutup, dialog progres '
        'hilang, pesan umum, tanpa lembar', (tester) async {
      final pembaca = _PembacaPutaran(const [], melempar: true);
      final uji = _Uji(daftar: _daftar(), pembaca: pembaca);
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.ditutup, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(
        find.text('Foto gagal diproses. Isi manual atau coba foto ulang.'),
        findsOneWidget,
      );
      expect(find.textContaining('ML Kit rusak'), findsNothing);
    });

    testWidgets('menutup pembaca melempar: dialog progres tetap hilang dan '
        'alur lanjut', (tester) async {
      final pembaca = _PembacaPutaran([_kakiPh], tutupMelempar: true);
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: pembaca,
        mesin: _MesinPalsu(),
      );
      await _pasang(tester, uji);
      await _pindai(tester);

      expect(pembaca.ditutup, isTrue);
      expect(find.byType(LembarKerjaScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ketukan berulang tidak melahirkan dua alur', (tester) async {
      final uji = _Uji(
        daftar: _daftar(),
        pembaca: _PembacaPutaran(['Revise : 4 SIDIK-FM-CAL-0504']),
      );
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
      await _tunggu(tester, _adaSheetJenis);

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

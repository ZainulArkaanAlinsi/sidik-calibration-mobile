import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/catatan_identifikasi_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/banner_jenis_dari_foto.dart';
import 'package:sidik_calibration/screens/pindai/dari_foto_lembar.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/catatan_identifikasi_lembar.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart'
    show GagalPindai;
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

/// "Pindai lembar kerja" dari beranda: foto yang SAMA dibaca di lembar kerja,
/// jadi teknisi memotret SEKALI dan tidak memilih apa pun.
///
/// Yang dikunci di sini:
///  - `dariFoto` null (bawaan, jalur manual "Mulai kalibrasi"): TIDAK ada
///    dialog "Mau diisi bagaimana?" dan tidak ada banner; satu tombol foto
///    kecil membuka kamera;
///  - `dariFoto` (alur LINEAR, tanpa alat yang dipilihkan): foto dibaca
///    OTOMATIS begitu lembar siap (tanpa kamera, dialog, tombol kedua, atau
///    menunggu alat); kode formulir ikut ke server sebagai `kode_dokumen`;
///    gagal baca = pesan saja (tanpa dialog dua tombol) dan TANPA tombol
///    "Foto ulang" di lembar (keputusan pemilik 27 Nov 2026: teknisi yang
///    ingin memotret ulang kembali ke beranda); tidak ada banner jenis;
///  - alur beranda membawa byte JPEG yang sama persis ke lembar kerja, dan
///    kamera cuma dibuka satu kali dari beranda sampai sel dibaca.
const _teknisi = 'mock-token-2';
const _kakiPh = 'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509';

/// Pembaca halaman yang mencatat JPEG yang diserahkan ke ML Kit dan membaca
/// teks berbeda per pembacaan (habis = kosong).
class _PembacaPerekam implements PembacaHalaman {
  _PembacaPerekam([this.teksPerBaca = const []]);

  final List<String> teksPerBaca;
  final jpeg = <Uint8List?>[];
  int jumlahBaca = 0;
  int jumlahTutup = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    jpeg.add(asli?.jpeg);
    final i = jumlahBaca++;
    final teks = i < teksPerBaca.length ? teksPerBaca[i] : '';
    if (teks.isEmpty) return const [];

    return [
      (teks: teks, kotak: const Rect.fromLTWH(0, 0, 200, 20), keyakinan: null),
    ];
  }

  @override
  Future<void> tutup() async => jumlahTutup++;
}

/// Kamera yang menulis berkas BARU tiap kali (alur menghapus berkas begitu
/// bitanya terbaca) dan menghitung berapa kali dibuka.
class _KameraSegar extends MockSumberFoto {
  _KameraSegar(this.dir, this.bita);

  final Directory dir;
  final List<int> bita;

  @override
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    jumlahAmbil++;
    maxWidthTerakhir = maxWidth;
    kualitasTerakhir = imageQuality;

    return File('${dir.path}/kamera-$jumlahAmbil.png')..writeAsBytesSync(bita);
  }
}

/// Mesin baca yang selalu gagal karena mutu (buram) dan mencatat JPEG yang
/// diterimanya — alur berhenti di dialog "Foto ulang".
class _MesinGagalMutu extends JalankanPindaiAsli {
  _MesinGagalMutu()
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final diterima = <Uint8List?>[];

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    diterima.add(jpegAsli);
    throw const PindaiAsliGagal(
      GagalPindaiAsli.mutu,
      mutu: GagalPindai.mutuBuram,
    );
  }
}

/// Mesin baca yang BERHASIL: satu sel gagal dibaca (merah, kosong, wajib
/// diketik teknisi) sehingga layar review terbuka. Mencatat JPEG yang diterima.
class _MesinSukses extends JalankanPindaiAsli {
  /// [teks] null = sel gagal dibaca (tetap kosong). Isi = bacaan yang masuk
  /// lembar langsung (tanpa layar review, keputusan pemilik 28 Nov 2026).
  _MesinSukses({this.teks})
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final String? teks;
  final diterima = <Uint8List?>[];

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    diterima.add(jpegAsli);
    const kunci = 'sesudah_adjustment|1|1|pembacaan';

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci == kunci)
            (
              sel: s,
              bacaan: (
                teks: teks,
                keyakinan: teks == null ? null : 0.95,
                didalamKotak: true,
              ),
            ),
      ],
      gagalDibaca: teks == null ? const {kunci} : const {},
    );
  }
}

/// Layanan peta formulir yang jawabannya bisa DITAHAN dan dikendalikan: untuk
/// mencapai jalur "formulir belum siap" di `_fotoLembar` yang tombolnya masih
/// kelihatan (nilai lama provider dipegang selama dimuat ulang).
class _LayananAsliTerkendali extends MockWorksheetScanService {
  _LayananAsliTerkendali(WorksheetTemplate t) : super(formulirAsli: t);

  /// Non-null = [templateAsli] menunggu completer ini.
  Completer<WorksheetTemplate?>? tahan;

  @override
  Future<WorksheetTemplate?> templateAsli(
    String token,
    String kode, {
    int? equipmentId,
    String? kodeDokumen,
  }) {
    final t = tahan;
    if (t != null) return t.future;

    return super.templateAsli(
      token,
      kode,
      equipmentId: equipmentId,
      kodeDokumen: kodeDokumen,
    );
  }
}

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

/// Foto yang sudah dipotret di beranda vs. foto yang akan dihasilkan kamera.
/// Ukurannya beda supaya byte-nya beda: pembaca bisa membedakan asalnya.
final Uint8List _fotoBeranda = _png(64, 48);
final Uint8List _fotoKamera = _png(80, 60);

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

/// Satu alat pH (id 14, alat yang sama dengan dropdown lembar): alur beranda
/// memilihnya sendiri.
class _AlatSatu extends MockEquipmentLookupService {
  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
    String? profil,
  }) async => [daftarAlatMock.firstWhere((a) => a.id == 14)];
}

/// Bekal lembar dari foto beranda untuk tes yang membuka `LembarKerjaScreen`
/// langsung. Alur LINEAR: tidak pernah membawa alat.
DariFotoLembar _dariFoto({String? kodeDokumen}) => DariFotoLembar(
  jpeg: _fotoBeranda,
  jenis: 'pH Meter',
  otomatis: true,
  kodeDokumen: kodeDokumen,
  gantiJenis: (_) async => null,
);

/// Pesan gagal baca di lembar dari foto (snackbar), pengganti dialog dua tombol.
final _pesanGagal = find.byKey(const ValueKey('pesan-foto-gagal'));
bool _adaPesanGagal() => _pesanGagal.evaluate().isNotEmpty;

final _dialogUlang = find.byKey(const ValueKey('dialog-foto-ulang'));
final _tombolUlang = find.byKey(const ValueKey('foto-ulang'));
final _tutupUlang = find.byKey(const ValueKey('foto-ulang-tutup'));
final _tombolFoto = find.byKey(const ValueKey('tombol-foto-lembar'));
final _caraFoto = find.byKey(const ValueKey('cara-foto'));

/// Decode & putar jalan di Isolate (IO sungguhan): beri waktu di luar jam
/// palsu sampai [selesai].
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

bool _adaDialogUlang() => _dialogUlang.evaluate().isNotEmpty;
bool _adaSnack() => find.byType(SnackBar).evaluate().isNotEmpty;

/// Pilih alat di lembar kerja (dropdown "Pilih alat"). Dicari lewat tipenya,
/// bukan tulisannya: pesan "Pilih alatnya dulu" juga memuat kata itu.
Future<void> _pilihAlat(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<EquipmentLookup>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('foto-awal');
  });

  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows: berkas masih dipegang; folder temp OS.
    }
  });

  // ------------------------------------------------------------------------
  group('LembarKerjaScreen.dariFoto', () {
    late _KameraSegar kamera;
    late _PembacaPerekam pembaca;
    late _MesinSukses mesin;
    var pembacaDibuat = 0;

    Future<void> pasang(
      WidgetTester tester, {
      DariFotoLembar? dariFoto,
      MockWorksheetScanService? layanan,
      bool mesinSukses = false,
    }) async {
      kamera = _KameraSegar(dir, _fotoKamera);
      pembaca = _PembacaPerekam();
      mesin = _MesinSukses();
      pembacaDibuat = 0;

      tester.view.physicalSize = const Size(1000, 14000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token-1'),
            ),
            authServiceProvider.overrideWithValue(MockAuthService()),
            lembarKerjaServiceProvider.overrideWithValue(
              MockLembarKerjaService(),
            ),
            standardServiceProvider.overrideWithValue(MockStandardService()),
            roomServiceProvider.overrideWithValue(MockRoomService()),
            equipmentLookupServiceProvider.overrideWithValue(
              MockEquipmentLookupService(),
            ),
            worksheetScanServiceProvider.overrideWithValue(
              layanan ??
                  MockWorksheetScanService(formulirAsli: _formulirAsli()),
            ),
            sumberFotoProvider.overrideWithValue(kamera),
            if (mesinSukses) mesinPindaiAsliProvider.overrideWithValue(mesin),
            pabrikPembacaPindaiProvider.overrideWithValue((
              sel: MockPembacaSel.new,
              qr: () => throw UnimplementedError('QR tidak dipakai'),
              halaman: () {
                pembacaDibuat++;

                return pembaca;
              },
            )),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LembarKerjaScreen(profil: 'ph_meter', dariFoto: dariFoto),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    testWidgets('dariFoto null (jalur manual "Mulai kalibrasi"): TIDAK ada '
        'dialog "Mau diisi bagaimana?", tidak ada banner; satu tombol foto '
        'kecil membuka kamera', (tester) async {
      await pasang(tester);
      expect(
        tester
            .widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen))
            .dariFoto,
        isNull,
      );

      // Tanpa dialog pilihan cara isi dan tanpa banner jenis dari foto.
      expect(find.text('Mau diisi bagaimana?'), findsNothing);
      expect(_caraFoto, findsNothing);
      expect(find.byKey(const ValueKey('cara-manual')), findsNothing);
      expect(find.byKey(BannerJenisDariFoto.kunciBanner), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      // SATU pintu foto di layar ini.
      expect(_tombolFoto, findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(find.text('Foto worksheet'), findsOneWidget);

      await _pilihAlat(tester);
      expect(kamera.jumlahAmbil, 0, reason: 'belum ada yang menekan tombol');

      await tester.tap(_tombolFoto);
      await tester.pump();
      await _tunggu(tester, () => _adaDialogUlang() || _adaSnack());

      expect(kamera.jumlahAmbil, 1, reason: 'tanpa foto awal = kamera dibuka');
      expect(kamera.maxWidthTerakhir, 4200);
      expect(kamera.kualitasTerakhir, 100);
      // Yang dibaca pembaca = foto kamera, byte demi byte.
      expect(pembaca.jpeg, isNotEmpty);
      for (final j in pembaca.jpeg) {
        expect(j, orderedEquals(_fotoKamera));
      }
    });

    testWidgets(
      'dariFoto (tanpa alat): foto beranda dibaca OTOMATIS tanpa dialog, '
      'tanpa tombol, tanpa menunggu alat; kamera tidak dibuka; tanpa layar '
      'periksa (hanya pesan)',
      (tester) async {
        await pasang(tester, dariFoto: _dariFoto(), mesinSukses: true);

        // Segera: lembar terbuka TANPA banner jenis (27 Nov 2026); tidak ada
        // dialog pilihan cara, tidak ada "Foto worksheet", tidak ada tombol
        // foto selagi dibaca.
        expect(find.byType(LembarKerjaScreen), findsOneWidget);
        expect(_caraFoto, findsNothing);
        expect(find.text('Foto worksheet'), findsNothing);
        expect(
          find.text('Dikenali otomatis: pH Meter (dari foto). Salah?'),
          findsNothing,
        );
        expect(find.byKey(BannerJenisDariFoto.kunciBanner), findsNothing);
        expect(_tombolFoto, findsNothing);

        // Mesin menerima byte beranda; kamera tidak dibuka.
        await _tunggu(tester, () => mesin.diterima.isNotEmpty);
        expect(mesin.diterima, hasLength(1));
        expect(mesin.diterima.single, orderedEquals(_fotoBeranda));
        expect(kamera.jumlahAmbil, 0);

        // Keputusan pemilik 28 Nov 2026: tanpa layar periksa. Sel yang gagal
        // dibaca tetap kosong; teknisi hanya melihat pesan.
        await _tunggu(tester, _adaSnack);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.byType(FotoReviewScreen), findsNothing);
      },
    );

    testWidgets('gagal baca: pesan saja (TANPA dialog dua tombol) dan TANPA '
        'tombol "Foto ulang" di lembar dari foto beranda', (tester) async {
      // Mesin sungguhan dengan pembaca tiruan kosong: kode tidak terbaca.
      await pasang(tester, dariFoto: _dariFoto());
      await _tunggu(tester, _adaPesanGagal);
      expect(_pesanGagal, findsOneWidget);
      expect(
        _dialogUlang,
        findsNothing,
        reason: 'tidak ada dialog Tutup/Foto ulang',
      );
      expect(_tombolUlang, findsNothing);
      expect(_tutupUlang, findsNothing);
      expect(kamera.jumlahAmbil, 0, reason: 'percobaan pertama = foto beranda');
      expect(pembaca.jpeg, isNotEmpty);
      for (final j in pembaca.jpeg) {
        expect(j, orderedEquals(_fotoBeranda));
      }

      // Keputusan pemilik 27 Nov 2026: tidak ada jalan ulang di lembar. Tidak
      // ada tombol foto, "Foto ulang", "Foto worksheet", atau "Isi dari foto".
      await tester.pumpAndSettle();
      expect(_tombolFoto, findsNothing);
      expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
      expect(find.text('Foto ulang'), findsNothing);
      expect(find.text('Foto worksheet'), findsNothing);
      expect(find.text('Isi dari foto'), findsNothing);
      expect(kamera.jumlahAmbil, 0, reason: 'kamera tidak dibuka diam-diam');
      expect(_dialogUlang, findsNothing);
    });

    testWidgets('alur linear: TANPA alat foto tetap dibaca otomatis; kode '
        'formulir ikut ke server sebagai kode_dokumen; tidak ada petunjuk '
        '"pilih alat" dan tidak ada "Isi dari foto"', (tester) async {
      final layanan = MockWorksheetScanService(formulirAsli: _formulirAsli());
      await pasang(
        tester,
        dariFoto: _dariFoto(kodeDokumen: 'SIDIK-FM-CAL-0509'),
        layanan: layanan,
      );
      await _tunggu(tester, _adaPesanGagal);

      // Dibaca sendiri, dari foto beranda, tanpa alat.
      expect(pembacaDibuat, 1);
      expect(kamera.jumlahAmbil, 0);
      for (final j in pembaca.jpeg) {
        expect(j, orderedEquals(_fotoBeranda));
      }
      // Peta formulir diminta TANPA alat tetapi DENGAN kode formulir.
      expect(
        layanan.kodeAsliDiminta.map((e) => e.equipmentId),
        everyElement(isNull),
      );
      expect(layanan.kodeDokumenDiminta, contains('SIDIK-FM-CAL-0509'));
      expect(
        find.text(
          'Pilih alatnya dulu, lalu ketuk tombol kamera "Foto worksheet" di atas lembar.',
        ),
        findsNothing,
      );
      expect(
        find.text('Pilih alat di bawah, lalu ketuk "Isi dari foto".'),
        findsNothing,
        reason: 'petunjuk lama "pilih alat dulu" sudah dibuang',
      );
      expect(find.text('Isi dari foto'), findsNothing);
      expect(pembaca.jumlahTutup, 1, reason: 'pembaca ditutup');
    });

    testWidgets('foto beranda SEKALI pakai walau lembar dibangun ulang '
        '(didUpdateWidget tidak boleh membacanya lagi)', (tester) async {
      await pasang(tester, dariFoto: _dariFoto());
      await _tunggu(tester, _adaPesanGagal);
      expect(kamera.jumlahAmbil, 0);
      await tester.pumpAndSettle();
      final dibaca = pembaca.jpeg.length;

      // Widget induk masih memegang byte-nya (ini yang membuat pembacaan ulang
      // dari `widget.dariFoto` mungkin terjadi bila ada yang mencobanya).
      expect(
        tester
            .widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen))
            .dariFoto,
        isNotNull,
      );

      // Paksa induk membangun ulang `_Form` (didUpdateWidget): ganti jumlah
      // pengulangan lewat menu, lalu konfirmasi.
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuItem<int>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      await _tunggu(tester, () => false, maks: 10);

      expect(pembaca.jpeg.length, dibaca, reason: 'tidak dibaca ulang sendiri');
      expect(kamera.jumlahAmbil, 0);
      // Lembar dari foto beranda tidak punya tombol foto (27 Nov 2026), jadi
      // pembangunan ulang juga tidak memunculkan jalan baca ulang apa pun.
      expect(_tombolFoto, findsNothing, reason: 'rebuild tidak memunculkannya');
      expect(find.text('Foto ulang'), findsNothing);
      expect(pembacaDibuat, 1, reason: 'pembaca tidak dibuat lagi');
    });

    testWidgets('formulir BELUM siap waktu lembar dibuka: pesan jujur; sesudah '
        'siap, foto beranda tidak dibaca diam-diam dan tidak ada tombol foto '
        '(kamera tetap tidak dibuka)', (tester) async {
      final layanan = _LayananAsliTerkendali(_formulirAsli());
      layanan.tahan = Completer<WorksheetTemplate?>();
      await pasang(tester, dariFoto: _dariFoto(), layanan: layanan);
      // Peta formulir ditahan: lembar terbuka tetapi belum bisa memindai.
      layanan.tahan!.complete(null);
      bool belumSiap() => find
          .text('Formulir ini belum bisa dipindai. Isi manual dulu.')
          .evaluate()
          .isNotEmpty;
      await _tunggu(tester, belumSiap);

      expect(belumSiap(), isTrue);
      expect(kamera.jumlahAmbil, 0);
      expect(pembacaDibuat, 0);
      expect(find.byType(AlertDialog), findsNothing);

      // Formulir siap lagi: foto beranda MASIH menunggu dan dipakai.
      layanan.tahan = null;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LembarKerjaScreen)),
      );
      // Alur linear: peta diminta tanpa alat dan tanpa kode formulir (bekal
      // `_dariFoto()` tidak membawa kode).
      container.invalidate(
        formulirAsliProvider((
          kode: 'ph_meter',
          equipmentId: null,
          kodeDokumen: null,
        )),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      // Tidak ada tombol "Foto ulang" di lembar dari foto beranda (27 Nov
      // 2026), dan tidak ada pembacaan otomatis kedua yang diam-diam.
      expect(_tombolFoto, findsNothing);
      expect(find.text('Foto ulang'), findsNothing);
      expect(find.text('Isi dari foto'), findsNothing);
      expect(kamera.jumlahAmbil, 0, reason: 'kamera tidak dibuka diam-diam');
      expect(pembacaDibuat, 0, reason: 'belum pernah dibaca: peta tidak siap');
      expect(pembaca.jpeg, isEmpty);
    });

    testWidgets('lembar ditutup selagi foto dibaca: tidak melempar dan tidak '
        'membuka kamera', (tester) async {
      await pasang(tester, dariFoto: _dariFoto());

      // Layar diganti: lembar kerja ditutup di tengah/sesudah pembacaan.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _tunggu(tester, () => false, maks: 10);

      expect(kamera.jumlahAmbil, 0);
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------------------
  group('pindaiFormulirAsli(bitaAwal)', () {
    late WorksheetTemplate template;

    setUpAll(() => template = _formulirAsli());

    Future<({_KameraSegar kamera, Future<int> hasil, LembarKerjaState isian})>
    mulai(
      WidgetTester tester, {
      required JalankanPindaiAsli mesin,
      Uint8List? bitaAwal,
      List<int>? bitaKamera,
      bool Function()? selesai,
      bool tanpaDialog = false,
    }) async {
      final kamera = _KameraSegar(dir, bitaKamera ?? _fotoKamera);
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
        clientRequestId: 'uuid-test',
      );
      late Future<int> hasil;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sumberFotoProvider.overrideWithValue(kamera)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('id'),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () {
                    hasil = pindaiFormulirAsli(
                      context: context,
                      ref: ref,
                      isian: isian,
                      template: template,
                      mesin: mesin,
                      bitaAwal: bitaAwal,
                      tanpaDialogFotoUlang: tanpaDialog,
                    );
                  },
                  child: const Text('foto'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('foto'));
      await _tunggu(tester, selesai ?? () => _adaDialogUlang() || _adaSnack());

      return (kamera: kamera, hasil: hasil, isian: isian);
    }

    testWidgets('bitaAwal null: kamera dibuka untuk percobaan pertama', (
      tester,
    ) async {
      final mesin = _MesinGagalMutu();
      final r = await mulai(tester, mesin: mesin);

      expect(r.kamera.jumlahAmbil, 1);
      expect(mesin.diterima, hasLength(1));
      expect(mesin.diterima.single, orderedEquals(_fotoKamera));
    });

    testWidgets('bitaAwal ada: mesin menerima byte itu, kamera tidak dibuka; '
        'Foto ulang = kamera, dan hanya sekali', (tester) async {
      final mesin = _MesinGagalMutu();
      final r = await mulai(tester, mesin: mesin, bitaAwal: _fotoBeranda);

      expect(r.kamera.jumlahAmbil, 0);
      expect(mesin.diterima, hasLength(1));
      expect(mesin.diterima.single, orderedEquals(_fotoBeranda));
      expect(_dialogUlang, findsOneWidget);

      // Foto ulang: kamera dibuka, mesin menerima foto KAMERA.
      await tester.tap(_tombolUlang);
      await tester.pump();
      await _tunggu(tester, () => mesin.diterima.length >= 2);
      await _tunggu(tester, _adaDialogUlang);

      expect(r.kamera.jumlahAmbil, 1);
      expect(mesin.diterima, hasLength(2));
      expect(mesin.diterima.last, orderedEquals(_fotoKamera));

      // Foto ulang sekali lagi: kamera lagi, bukan foto beranda lagi.
      await tester.tap(_tombolUlang);
      await tester.pump();
      await _tunggu(tester, () => mesin.diterima.length >= 3);
      await _tunggu(tester, _adaDialogUlang);

      expect(r.kamera.jumlahAmbil, 2);
      expect(mesin.diterima.last, orderedEquals(_fotoKamera));

      await tester.tap(_tutupUlang);
      await tester.pumpAndSettle();
      expect(await r.hasil, 0);
    });

    testWidgets('tanpaDialogFotoUlang: foto buram = pesan saja, TANPA dialog '
        'dan tanpa membuka kamera; hasilnya 0 (jalur manual tetap berdialog)', (
      tester,
    ) async {
      final mesin = _MesinGagalMutu();
      final r = await mulai(
        tester,
        mesin: mesin,
        bitaAwal: _fotoBeranda,
        tanpaDialog: true,
        selesai: _adaPesanGagal,
      );

      expect(_pesanGagal, findsOneWidget);
      expect(_dialogUlang, findsNothing);
      expect(_tombolUlang, findsNothing);
      expect(r.kamera.jumlahAmbil, 0);
      expect(mesin.diterima, hasLength(1));
      expect(await r.hasil, 0);
    });

    testWidgets('bitaAwal + mesin berhasil: dibaca dari byte beranda tanpa '
        'kamera, bacaan masuk lembar LANGSUNG tanpa layar review', (
      tester,
    ) async {
      final mesin = _MesinSukses(teks: '7,01');
      final r = await mulai(
        tester,
        mesin: mesin,
        bitaAwal: _fotoBeranda,
        selesai: _adaSnack,
      );

      // Keputusan pemilik 28 Nov 2026: tanpa layar review.
      expect(r.kamera.jumlahAmbil, 0);
      expect(mesin.diterima, hasLength(1));
      expect(mesin.diterima.single, orderedEquals(_fotoBeranda));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(FotoReviewScreen), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);

      expect(await r.hasil, 1, reason: 'satu sel masuk lembar');
      expect(r.isian.adaIsianDariFoto, isTrue);
      expect(r.kamera.jumlahAmbil, 0, reason: 'tidak pernah memotret ulang');
    });

    testWidgets('bitaAwal + sel gagal dibaca: tetap kosong, tidak ditebak, '
        'hanya pesan', (tester) async {
      final mesin = _MesinSukses();
      final r = await mulai(
        tester,
        mesin: mesin,
        bitaAwal: _fotoBeranda,
        selesai: _adaSnack,
      );

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(await r.hasil, 0);
      expect(r.isian.adaIsianDariFoto, isFalse);
    });

    testWidgets('bitaAwal bukan citra: pesan foto tidak terbaca + Foto ulang, '
        'kamera hanya dibuka bila Foto ulang ditekan', (tester) async {
      final mesin = _MesinGagalMutu();
      final r = await mulai(
        tester,
        mesin: mesin,
        bitaAwal: Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]),
      );

      expect(find.textContaining('Foto tidak bisa dibaca'), findsOneWidget);
      expect(_tombolUlang, findsOneWidget);
      expect(r.kamera.jumlahAmbil, 0);
      expect(mesin.diterima, isEmpty, reason: 'mesin tak disentuh');
    });
  });

  // ------------------------------------------------------------------------
  group('beranda -> lembar kerja: teknisi memotret SEKALI', () {
    late _KameraSegar kamera;
    late _PembacaPerekam pembaca;
    var pembacaDibuat = 0;

    Future<void> pasang(WidgetTester tester) async {
      // Kamera menghasilkan foto beranda; pembaca mengenali 0509 sekali.
      kamera = _KameraSegar(dir, _fotoBeranda);
      pembaca = _PembacaPerekam([_kakiPh]);
      pembacaDibuat = 0;

      tester.view.physicalSize = const Size(1000, 14000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final daftar = [entriDaftar('ph_meter')];
      final List<Override> overrides = [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_teknisi)),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        worksheetScanServiceProvider.overrideWithValue(
          MockWorksheetScanService(
            daftar: daftar,
            formulirAsli: _formulirAsli(),
          ),
        ),
        pindaiLembarAktifProvider.overrideWithValue(true),
        sumberFotoProvider.overrideWithValue(kamera),
        catatanIdentifikasiLembarProvider.overrideWithValue(
          const CatatanIdentifikasiKosong(),
        ),
        pabrikPembacaPindaiProvider.overrideWithValue((
          sel: MockPembacaSel.new,
          qr: () => throw UnimplementedError('QR tidak dipakai'),
          halaman: () {
            pembacaDibuat++;

            return pembaca;
          },
        )),
        lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
        standardServiceProvider.overrideWithValue(MockStandardService()),
        roomServiceProvider.overrideWithValue(MockRoomService()),
        // Satu alat pH: dipilih sendiri, tanpa daftar alat.
        equipmentLookupServiceProvider.overrideWithValue(_AlatSatu()),
        historyServiceProvider.overrideWithValue(MockHistoryService()),
        categoryServiceProvider.overrideWithValue(MockCategoryService()),
        calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
        jamProvider.overrideWithValue(() => DateTime(2026, 11, 15, 10, 30)),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TombolPindaiLembar()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }

    testWidgets('byte JPEG beranda yang SAMA dibaca di lembar kerja: kamera '
        'hanya sekali, tanpa layar pilihan, tanpa dialog, tanpa tombol foto '
        'kedua, tanpa "Foto ulang" sesudah gagal baca', (tester) async {
      await pasang(tester);

      // Beranda: foto + pengenalan; kode 0509 unik -> lembar terbuka SENDIRI.
      await tester.tap(find.byKey(TombolPindaiLembar.kunciTombol));
      await tester.pump();
      await _tunggu(
        tester,
        () => find.byType(LembarKerjaScreen).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Tidak ada layar pilihan jenis/alat dan tidak ada dialog cara isi.
      expect(find.byType(PilihJenisRingkasSheet), findsNothing);
      expect(find.byType(PilihAlatRingkasSheet), findsNothing);
      expect(find.text('Mau diisi bagaimana?'), findsNothing);
      expect(_caraFoto, findsNothing);
      expect(find.text('Foto worksheet'), findsNothing);

      final lembar = tester.widget<LembarKerjaScreen>(
        find.byType(LembarKerjaScreen),
      );
      expect(lembar.profil, 'ph_meter');
      expect(lembar.dariFoto, isNotNull);
      expect(lembar.dariFoto!.jpeg, orderedEquals(_fotoBeranda));
      // Linear: satu-satunya alat jenis ini TIDAK dipilih sendiri.
      expect(find.text('pH Meter Mettler Toledo · B628755900'), findsNothing);

      // Foto SAMA dibaca di lembar: kamera tetap satu kali, pembaca kedua
      // (pindai sel) menerima byte yang persis sama.
      await _tunggu(tester, _adaPesanGagal);
      expect(kamera.jumlahAmbil, 1, reason: 'tidak memotret dua kali');
      expect(pembacaDibuat, 2, reason: 'mengenali jenis + membaca isi');
      expect(pembaca.jpeg.length, greaterThan(1));
      for (final j in pembaca.jpeg) {
        expect(j, orderedEquals(_fotoBeranda));
      }

      // Kode formulir tidak terbaca di pembaca tiruan -> pesan saja. Tidak ada
      // tombol "Foto ulang" di lembar (27 Nov 2026): kamera tidak dibuka lagi.
      expect(_dialogUlang, findsNothing);
      await tester.pumpAndSettle();
      expect(_tombolFoto, findsNothing);
      expect(find.text('Foto ulang'), findsNothing);
      expect(kamera.jumlahAmbil, 1, reason: 'kamera hanya dari beranda');
    });
  });
}

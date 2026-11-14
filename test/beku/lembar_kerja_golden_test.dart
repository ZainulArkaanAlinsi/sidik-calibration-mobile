@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/keypad_angka.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

import '../support/halaman_lembar.dart';

// KUNCI TAMPILAN LEMBAR KERJA (desain ulang Lab, langkah L0).
//
// Lembar kerja berstatus BEKU (`docs/desain-ulang/BEKU.md`): tata letak,
// warna, ukuran, huruf, keypad, dan jaraknya tidak boleh berubah walau token
// tema diganti ke Biru Awan. Berkasnya tidak disentuh, tapi dia membaca warna
// lewat `Theme.of(context)` — jadi yang menjaga bukan hash berkas
// (`berkas_beku_test.dart`), melainkan GAMBAR yang dirender berkas-berkas itu.
//
// ## Aturan main
//
// - Golden di `test/beku/goldens/` TIDAK BOLEH diperbarui oleh PR desain mana
//   pun. Merah di sini berarti ada yang bocor ke tampilan beku (biasanya token
//   tema): perbaiki kebocorannya, jangan `--update-goldens`.
// - PNG dibuat HANYA di macOS (platform acuan `test/flutter_test_config.dart`)
//   lewat `.github/workflows/golden-beku.yml`. PNG dari Windows/Linux tidak
//   boleh di-commit — rasterisasi fontnya beda 2,5%–4,3%.
//
// ## Ukuran gambar
//
// Lebar PERSIS 390 dan 1024 dp. Tinggi mencakup SELURUH isi halaman (kepala +
// rentang gulir), bukan 844/768: tabel di bagian bawah lembar yang panjang ikut
// terkunci. Tingginya DIUKUR (rentang gulir exact pada jendela 30000 dp), lalu
// dibulatkan ke atas ke kelipatan 50 dengan sisa >= 60 dp, dan angkanya dipatok
// di [_tinggiGambar].
//
// Kenapa dipatok, bukan diukur ulang tiap tes jalan: `periksa-pr.yml` menjalankan
// SELURUH `flutter test` juga di Ubuntu (ambang 15%). Tinggi hasil ukur bisa
// beda satu-dua piksel antar-OS karena metrik teks, dan ukuran gambar yang
// beda = golden gagal berapa pun ambangnya. Dengan tinggi patokan, ukuran PNG
// sama di semua OS, dan isi yang tumbuh melewatinya gagal lewat pemeriksaan di
// bawah (bukan lewat perbedaan ukuran yang membingungkan).
//
// PNG selalu 1 px per dp (lihat [_dpr]), jadi ukuran file ditentukan lebar x
// tinggi saja.
//
// ## Data
//
// Hanya mock yang sudah dipakai tes lain (`MockLembarKerjaService`,
// `MockCategoryService`, …). Tanpa jaringan. Jam dipatok lewat `jamProvider`
// supaya tanggal kalibrasi yang kecetak tidak berubah tiap hari.
//
// ## Yang TIDAK dikunci di sini (sengaja)
//
// Isian yang diketik teknisi, hasil pratinjau dari server, dan keadaan galat
// tidak dipotret: semuanya bergantung waktu/debounce dan bikin golden goyah.
// Yang dikunci adalah rupa lembar kosong bawaan mock, termasuk tema terang
// dan gelap.

/// Lebar logis (dp) yang dipotret: HP dan tablet.
const List<double> _lebarDp = [390, 1024];

/// Rasio piksel jendela uji. Sengaja 1.0: `matchesGoldenFile` memotret pada
/// 1 px per dp APA PUN rasionya (`captureImage` memanggil `layer.toImage` tanpa
/// `pixelRatio`) — golden lama 1080x2280 @3,0 pun berukuran 360x760. Jadi
/// rasio tidak memengaruhi ukuran PNG, dan 1.0 tidak berpura-pura memberi
/// ketajaman yang tidak ada.
const double _dpr = 1.0;

/// Tinggi gambar (dp) per adegan-lebar. Hasil ukur (Windows, 14 Nov 2026,
/// origin/main de5ddf4), lalu `ceil((terukur + 60) / 50) * 50`:
///
/// | adegan | 390 dp | 1024 dp |
/// |---|---|---|
/// | ph-tabel | 2056 -> 2150 | 1972 -> 2050 |
/// | autoclave-matriks | 1982 -> 2050 | 1836 -> 1900 |
/// | enclosure-grid | 3634 -> 3700 | 3406 -> 3500 |
/// | input-kalibrasi | 1276 -> 1350 | 1276 -> 1350 |
/// | keypad | keypad 316 -> 450 | keypad 316 -> 450 |
///
/// JANGAN diperbesar supaya tes hijau: layar beku yang isinya tumbuh adalah
/// perubahan tampilan, dan golden-nya tidak boleh diperbarui.
const Map<String, double> _tinggiGambar = {
  'ph-tabel-390': 2150,
  'ph-tabel-1024': 2050,
  'autoclave-matriks-390': 2050,
  'autoclave-matriks-1024': 1900,
  'enclosure-grid-390': 3700,
  'enclosure-grid-1024': 3500,
  'input-kalibrasi-390': 1350,
  'input-kalibrasi-1024': 1350,
  'keypad-390': 450,
  'keypad-1024': 450,
};

/// Tinggi awal (dp) buat mengukur isi: cukup besar supaya seluruh lembar
/// terbangun sekaligus (ListView hanya membangun yang kelihatan), sehingga
/// rentang gulirnya EXACT, bukan perkiraan. Preseden: 30000 di
/// `semua_lembar_tergambar_tanpa_error_test.dart`.
const double _tinggiUkur = 30000;

/// Tanggal yang kecetak di lembar kerja. Angkanya tidak penting — yang penting
/// TETAP. Sama dengan `_tanggalGolden` di `screenshot_test.dart`.
final DateTime _tanggalGolden = DateTime(2026, 8, 9, 10, 30);

/// Dibaca sekali di `setUpAll`. Kalau ikon Material tidak ketemu, golden-nya
/// berisi kotak kosong dan kuncinya jadi tumpul — itu GAGAL, bukan dilewati
/// (beda dengan `screenshot_test.dart` yang memaafkannya).
Future<void> _muatFont() async {
  Future<void> muat(String keluarga, String awalan, List<String> bobot) async {
    final pemuat = FontLoader(keluarga);
    for (final b in bobot) {
      final bytes = File('assets/fonts/$awalan-$b.ttf').readAsBytesSync();
      pemuat.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await pemuat.load();
  }

  const bobot = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  await muat('Inter', 'Inter', bobot);
  await muat('IBMPlexMono', 'IBMPlexMono', bobot);

  final root = Platform.environment['FLUTTER_ROOT'];
  expect(
    root,
    isNotNull,
    reason: 'FLUTTER_ROOT kosong: font ikon Material tidak bisa dimuat.',
  );
  final berkas = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  expect(
    berkas.existsSync(),
    isTrue,
    reason: 'MaterialIcons-Regular.otf tidak ada di ${berkas.path}.',
  );
  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(berkas.readAsBytesSync().buffer.asByteData()));
  await ikon.load();
}

/// Semua mock yang dibutuhkan lembar kerja dan `CalibrationInputScreen`.
/// Himpunan gabungan dari `screenshot_test.dart` (`_bungkus`),
/// `lembar_kerja_test.dart` (`_app`), dan `calibration_input_test.dart`.
List<Override> _mock() => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
  authServiceProvider.overrideWithValue(MockAuthService()),
  lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
  standardServiceProvider.overrideWithValue(MockStandardService()),
  roomServiceProvider.overrideWithValue(MockRoomService()),
  equipmentLookupServiceProvider.overrideWithValue(
    MockEquipmentLookupService(),
  ),
  historyServiceProvider.overrideWithValue(MockHistoryService()),
  worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
  categoryServiceProvider.overrideWithValue(MockCategoryService()),
  calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
  jamProvider.overrideWithValue(() => _tanggalGolden),
  // Nilai bawaan produksi (`AppConfig.pindaiLembarAktif` = true). Ditulis
  // eksplisit supaya golden tidak bergeser kalau ada yang menyalakan
  // `--dart-define=PINDAI_LEMBAR=false` saat menjalankan tes.
  pindaiLembarAktifProvider.overrideWithValue(true),
];

/// Tema dipasang di SATU tempat ini.
///
/// Sejak L1a (`lib/core/theme/beku_lembar_kerja.dart`) tiap layar beku dipasang
/// dari LUAR dengan `BekuLembarKerja`, persis seperti pemanggil route di app
/// (`MaterialPageRoute(builder: (_) => BekuLembarKerja(child: ...))`). Adegan di
/// bawah meniru itu: `Theme.of(context)` yang ditulis di `State` layar memakai
/// `context` di atas pembungkus akar layar itu sendiri (mis. gaya "5x" di app bar
/// lembar kerja), jadi hanya pembungkus dari luar yang membekukannya. `KeypadAngka`
/// BUKAN akar layar (lihat adegan keypad); dia dibungkus di sini sebagaimana
/// `foto_review_screen.dart` membungkusnya. Dengan begitu `AppTheme` boleh
/// berganti (L1b) tanpa golden-nya diperbarui.
ThemeData _tema(Brightness mode) =>
    mode == Brightness.light ? AppTheme.light : AppTheme.dark;

Widget _aplikasi(
  Widget layar,
  Brightness mode, {
  ValueListenable<Rect?>? topeng,
}) {
  return ProviderScope(
    overrides: _mock(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _tema(mode),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Topeng abu-abu polos di atas SELURUH layar (di atas Navigator), dipakai
      // hanya oleh adegan yang memuat teks bergantung jam sungguhan.
      builder: topeng == null
          ? null
          : (context, anak) => Stack(
              textDirection: TextDirection.ltr,
              children: [
                anak!,
                ValueListenableBuilder<Rect?>(
                  valueListenable: topeng,
                  builder: (_, rect, _) => rect == null
                      ? const SizedBox.shrink()
                      : Positioned.fromRect(
                          rect: rect,
                          child: const ColoredBox(color: Color(0xFF808080)),
                        ),
                ),
              ],
            ),
      home: layar,
    ),
  );
}

/// Atur jendela uji: lebar/tinggi LOGIS (dp) dan rasio piksel.
void _aturLayar(
  WidgetTester tester, {
  required double lebar,
  required double tinggi,
}) {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = Size(lebar * _dpr, tinggi * _dpr);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pump + tunggu timer 600 ms `MockAuthService.me()`; `pumpAndSettle` saja
/// tidak memajukan timer macam itu.
Future<void> _muat(WidgetTester tester, Widget aplikasi) async {
  await tester.pumpWidget(aplikasi);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Penggulir vertikal terluar (badan layar).
Finder get _gulirUtama => find
    .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
    .first;

/// Tinggi (dp) seluruh isi layar: bagian yang tidak menggulir (AppBar, dll.)
/// ditambah rentang gulir badan yang sebenarnya. Dipanggil saat jendela masih
/// [_tinggiUkur], jadi semua anak sudah terbangun dan `scrollExtent`-nya exact.
double _ukurTinggiIsi(WidgetTester tester, double tinggiJendela) {
  final viewport = tester.renderObject<RenderViewport>(
    find.descendant(of: _gulirUtama, matching: find.byType(Viewport)).first,
  );
  var rentang = 0.0;
  for (
    RenderSliver? s = viewport.firstChild;
    s != null;
    s = viewport.childAfter(s)
  ) {
    rentang += s.geometry!.scrollExtent;
  }

  return tinggiJendela - viewport.size.height + rentang;
}

/// Pastikan isi layar muat di [tinggi] (dp), lalu pasang jendela setinggi itu.
/// Dipanggil saat jendela masih [_tinggiUkur].
Future<void> _pasangTinggiGambar(
  WidgetTester tester, {
  required String kunci,
  required double lebar,
  required double tinggi,
}) async {
  final isi = _ukurTinggiIsi(tester, _tinggiUkur);
  expect(
    isi,
    lessThanOrEqualTo(tinggi),
    reason:
        '$kunci: isi layar $isi dp melebihi tinggi gambar $tinggi dp. Layar '
        'beku TUMBUH — itu perubahan tampilan. Jangan perbesar _tinggiGambar '
        'dan jangan perbarui golden; cari penyebabnya (baca '
        'docs/desain-ulang/BEKU.md).',
  );

  _aturLayar(tester, lebar: lebar, tinggi: tinggi);
  await tester.pumpAndSettle();

  final posisi = tester.state<ScrollableState>(_gulirUtama).position;
  expect(
    posisi.maxScrollExtent,
    lessThan(0.01),
    reason:
        '$kunci: masih ada ${posisi.maxScrollExtent} dp di luar layar pada '
        'tinggi $tinggi dp — gambarnya tidak memuat seluruh isi halaman.',
  );
}

/// Satu adegan: layar yang dipotret dan cara menyiapkannya.
class _Adegan {
  const _Adegan(this.nama, this.siapkan, this.sasaran, {this.gulir = true});

  /// Awalan nama berkas golden.
  final String nama;

  /// Pasang layar di [tester] dan bawa ke keadaan yang dipotret.
  final Future<void> Function(WidgetTester tester, Brightness mode) siapkan;

  /// Widget yang dipotret.
  final Finder Function() sasaran;

  /// Layar bergulir (tinggi = isi) atau potongan tetap (tinggi diatur adegan).
  final bool gulir;
}

/// Gagal bila ada teks bertanggal HARI INI (jam sungguhan) di layar.
///
/// Golden yang memuat `DateTime.now()` merah tiap ganti hari tanpa ada yang
/// rusak (kejadian 10 Agt 2026, lihat `jam_provider.dart`). Lembar kerja
/// memakai `jamProvider` (dipatok [_tanggalGolden]); penjaga ini menangkap
/// bagian lain yang lupa memakainya SEBELUM golden-nya dibuat.
void _pastikanTanggalDipatok(WidgetTester tester) {
  final tanggal = RegExp(r'\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2}');
  List<int> angka(String s) =>
      RegExp(r'\d+').allMatches(s).map((m) => int.parse(m[0]!)).toList()
        ..sort();

  final kini = DateTime.now();
  final hariIni = angka('${kini.day}/${kini.month}/${kini.year}');
  final teks = <String>[
    for (final w in tester.widgetList<Text>(find.byType(Text)))
      w.data ?? w.textSpan?.toPlainText() ?? '',
    for (final e in tester.widgetList<EditableText>(find.byType(EditableText)))
      e.controller.text,
  ];
  for (final t in teks) {
    for (final m in tanggal.allMatches(t)) {
      expect(
        angka(m[0]!),
        isNot(hariIni),
        reason:
            'Layar menampilkan tanggal hari ini ("${m[0]}") dari jam sungguhan '
            '— golden-nya merah tiap ganti hari. Pakai jamProvider.',
      );
    }
  }
}

Future<void> _lembarKerjaHalamanAkhir(
  WidgetTester tester,
  Brightness mode,
  String profil,
) async {
  await _muat(
    tester,
    _aplikasi(BekuLembarKerja(child: LembarKerjaScreen(profil: profil)), mode),
  );
  // Halaman PENGUKURAN: tabel/matriks/grid ada di sana. Di 390 dan 1024 (< 1100)
  // lembar berhalaman; di atas 1100 dia dua kolom dan tombolnya tidak ada.
  await keHalamanAkhir(tester);
  _pastikanTanggalDipatok(tester);
}

/// `CalibrationInputScreen` dibuka lewat Navigator (ada tombol kembali, seperti
/// di app) dan diisi lewat langkah yang sama dengan `_isiFormLengkap` di
/// `calibration_input_test.dart` — tanpa mengirim.
///
/// TEMUAN: layar ini mengisi "Tanggal kalibrasi" dengan `DateTime.now()`
/// langsung (`calibration_input_screen.dart:228`), TIDAK lewat `jamProvider`,
/// dan `lib/` tidak boleh berubah di L0. Tanpa penanganan, golden ini merah
/// besok. Jadi kotak teks tanggalnya (cuma itu) ditutup topeng abu-abu polos;
/// yang lain tetap dikunci. Perbaikan sebenarnya: layar memakai `jamProvider`
/// (butuh persetujuan pemilik karena berkas beku) — setelah itu topeng ini
/// dibuang dan golden dibuat ulang.
Future<void> _inputKalibrasi(WidgetTester tester, Brightness mode) async {
  final topeng = ValueNotifier<Rect?>(null);
  addTearDown(topeng.dispose);
  await _muat(
    tester,
    _aplikasi(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const BekuLembarKerja(child: CalibrationInputScreen()),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
      mode,
      topeng: topeng,
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Panjang').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih alat'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Jangka Sorong Mitutoyo').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih standar acuan'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gauge Block Set Grade 0').last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).at(2), '50.0');
  await tester.enterText(find.byType(TextField).at(3), 'mm');
  await tester.enterText(find.byType(TextField).at(4), '50.02');
  await tester.enterText(find.byType(TextField).at(5), '50.01');
  // Kursor berkedip tidak boleh ikut terpotret.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  final tanggal = find.byWidgetPredicate(
    (w) =>
        w is Text && RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(w.data ?? ''),
  );
  expect(
    tanggal,
    findsOneWidget,
    reason: 'Teks tanggal kalibrasi tidak ketemu.',
  );
  topeng.value = tester.getRect(tanggal).inflate(2);
  await tester.pump();
}

/// Keypad angka terbuka.
///
/// Keypad TIDAK terjangkau dari lembar kerja: satu-satunya pemakainya
/// `foto_review_screen.dart` (layar 04, status DESAIN — akan berubah). Karena
/// itu yang dikunci adalah widget `KeypadAngka` + `KepalaSelAktif` itu sendiri
/// (berkas beku `widgets/keypad_angka.dart`), dirangkai seperti di layar review:
/// menempel di dasar layar, tombol setinggi 44, label dari l10n.
Future<void> _keypad(WidgetTester tester, Brightness mode) async {
  await _muat(
    tester,
    _aplikasi(
      Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);

          // Dibungkus tema beku (L1a): Scaffold ini perancah tes, tapi warna latar
          // dan huruf keypad harus tetap saat `AppTheme` berganti.
          return BekuLembarKerja(
            child: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  SafeArea(
                    top: false,
                    child: KeypadAngka(
                      kepala: KepalaSelAktif(
                        judul: 'Set Point 7,00 · Ulangan 2',
                        sisa: l10n.fotoReviewSisaSel(3),
                        teks: '-7,01',
                      ),
                      onTombol: (_) {},
                      onKonfirmasi: () {},
                      onTutup: () {},
                      labelKonfirmasi: l10n.fotoReviewKonfirmasiLanjut,
                      labelTutup: l10n.fotoReviewTutupKeypad,
                      labelHapus: l10n.fotoReviewKeypadHapus,
                      labelMinus: l10n.fotoReviewKeypadMinus,
                      bisaKonfirmasi: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      mode,
    ),
  );
}

final List<_Adegan> _adegan = [
  // pH — profil bawaan `ph_meter`, halaman pengukuran (tabel hasil).
  _Adegan(
    'ph-tabel',
    (tester, mode) => _lembarKerjaHalamanAkhir(tester, mode, 'ph_meter'),
    () => find.byType(LembarKerjaScreen),
  ),
  // Autoclave — matriks (disk x titik waktu) + tabel tekanan.
  _Adegan(
    'autoclave-matriks',
    (tester, mode) => _lembarKerjaHalamanAkhir(tester, mode, 'autoclave'),
    () => find.byType(LembarKerjaScreen),
  ),
  // Enclosure (Oven) — grid sensor: set point x termokopel x pengulangan.
  // Oven dipilih karena dia profil pertama dari lima Enclosure yang SATU
  // kertas dan SATU bentuk (`contoh_lembar_kerja_enclosure.dart`).
  _Adegan(
    'enclosure-grid',
    (tester, mode) => _lembarKerjaHalamanAkhir(tester, mode, 'oven'),
    () => find.byType(LembarKerjaScreen),
  ),
  _Adegan('keypad', _keypad, () => find.byType(Scaffold), gulir: false),
  _Adegan(
    'input-kalibrasi',
    _inputKalibrasi,
    // MaterialApp, bukan layarnya: topeng tanggal ada DI ATAS Navigator.
    () => find.byType(MaterialApp),
  ),
];

void main() {
  setUpAll(_muatFont);

  for (final adegan in _adegan) {
    for (final mode in Brightness.values) {
      for (final lebar in _lebarDp) {
        final tema = mode == Brightness.light ? 'terang' : 'gelap';
        final berkas = '${adegan.nama}-$tema-${lebar.toInt()}.png';

        testWidgets('${adegan.nama} — $tema — ${lebar.toInt()} dp', (
          tester,
        ) async {
          final kunci = '${adegan.nama}-${lebar.toInt()}';
          final tinggi = _tinggiGambar[kunci]!;
          _aturLayar(tester, lebar: lebar, tinggi: _tinggiUkur);
          await adegan.siapkan(tester, mode);

          if (adegan.gulir) {
            await _pasangTinggiGambar(
              tester,
              kunci: kunci,
              lebar: lebar,
              tinggi: tinggi,
            );
          } else {
            _aturLayar(tester, lebar: lebar, tinggi: tinggi);
            await tester.pumpAndSettle();
          }

          expect(
            tester.takeException(),
            isNull,
            reason: 'Layar melempar galat saat dirender (overflow dsb.).',
          );

          await expectLater(
            adegan.sasaran(),
            matchesGoldenFile('goldens/$berkas'),
          );
        });
      }
    }
  }
}

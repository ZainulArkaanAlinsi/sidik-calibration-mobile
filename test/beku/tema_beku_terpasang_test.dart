import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/temperatur_indikator_gerbang_screen.dart';
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

/// PENJAGA PEMASANGAN TEMA BEKU (desain ulang Lab, L1a).
///
/// `docs/desain-ulang/BEKU.md`: lembar kerja tidak boleh berubah tampilannya
/// saat token tema app diganti. Tema beku (`TemaBeku`) hanya menolong kalau
/// SETIAP layar beku, dan setiap dialog/lembar bawah yang dibuka dari
/// `State`-nya, benar-benar membacanya. Golden `lembar_kerja_golden_test.dart`
/// hanya memotret layar yang diam; ia tidak membuka dialog dan tidak merender
/// semua layar beku (gerbang Temperatur Indikator dan Skema dinamis tidak ada
/// di sana). Berkas ini yang menutup celah itu, lewat penanda `PenandaBeku`
/// (`ThemeExtension` yang hanya dimiliki `TemaBeku`).
///
/// ## Kenapa pembungkusnya dipasang dari LUAR
///
/// `Theme.of(context)` dan `showDialog(context: context)` yang ditulis di
/// `State` layar memakai `context` layar itu sendiri. Pembungkus di dalam
/// `build` layar berada di bawahnya, jadi tidak menjangkau subjudul app bar,
/// gaya "5x", dan dialog dari `State`. Karena itu tiap pemanggil membungkus
/// layarnya (`MaterialPageRoute(builder: (_) => BekuLembarKerja(child:
/// LembarKerjaScreen(...)))`). Pembungkus di akar layar sengaja TIDAK dipasang:
/// tes lama yang memasang layar langsung di bawah `ThemeData` bawaan jadi
/// menjalankan tema produksi dan gagal (overflow 18 sampai 69 px pada 320 x 568
/// huruf 1,3; hitungan teks terpotong turun), padahal tampilan produksi tidak
/// berubah. Kelompok terakhir memindai `lib/` dan gagal bila ada pemanggil yang
/// lupa.
void main() {
  /// Tema app yang SENGAJA berbeda dari tema beku di semua yang terlihat. Saat
  /// L1b mengganti token, tema app akan menjauh dari tema beku; tes di sini
  /// memakai tema asing supaya pemeriksaannya bermakna sekarang juga.
  ThemeData temaAsing() => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFE91E63),
    scaffoldBackgroundColor: const Color(0xFFFFE0B2),
  );

  bool bekuDi(Element e) => Theme.of(e).extension<PenandaBeku>() != null;

  /// Element `Scaffold` pertama di bawah layar [T] (konteks DI BAWAH pembungkus
  /// akar layar itu).
  Element scaffoldDi<T extends Widget>(WidgetTester tester) => tester.element(
    find
        .descendant(of: find.byType(T), matching: find.byType(Scaffold))
        .first,
  );

  void layarPanjang(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<Override> mock({CategoryService? kategori}) => [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
    categoryServiceProvider.overrideWithValue(kategori ?? MockCategoryService()),
    calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
    jamProvider.overrideWithValue(() => DateTime(2026, 8, 9, 10, 30)),
    pindaiLembarAktifProvider.overrideWithValue(true),
  ];

  Widget aplikasi(
    Widget home, {
    ThemeData? tema,
    ThemeData? temaGelap,
    ThemeMode mode = ThemeMode.light,
    CategoryService? kategori,
  }) => ProviderScope(
    overrides: mock(kategori: kategori),
    child: MaterialApp(
      theme: tema ?? AppTheme.light,
      darkTheme: temaGelap ?? AppTheme.dark,
      themeMode: mode,
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> muat(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    // `MockAuthService.me()` dan tarikan lembar memakai timer.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  group('penanda hanya ada di tema beku', () {
    test('TemaBeku membawa PenandaBeku, tema app tidak', () {
      for (final t in [TemaBeku.terang, TemaBeku.gelap]) {
        expect(t.extension<PenandaBeku>(), isNotNull);
        expect(t.extension<SidikMaterial>(), isNotNull);
      }
      for (final t in [AppTheme.light, AppTheme.dark]) {
        expect(t.extension<PenandaBeku>(), isNull);
      }
    });

    testWidgets('BekuLembarKerja mengikuti mode tema di atasnya', (
      tester,
    ) async {
      late ThemeData terang;
      late ThemeData gelap;
      for (final (mode, simpan) in <(ThemeMode, void Function(ThemeData))>[
        (ThemeMode.light, (t) => terang = t),
        (ThemeMode.dark, (t) => gelap = t),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: BekuLembarKerja(
              child: Builder(
                builder: (c) {
                  simpan(Theme.of(c));
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(terang.brightness, Brightness.light);
      expect(gelap.brightness, Brightness.dark);
      expect(
        gelap.extension<SidikMaterial>()!.biru,
        TemaBeku.gelap.extension<SidikMaterial>()!.biru,
      );
      expect(
        terang.extension<SidikMaterial>()!.biru,
        TemaBeku.terang.extension<SidikMaterial>()!.biru,
      );
      expect(terang.extension<PenandaBeku>(), isNotNull);
      expect(gelap.extension<PenandaBeku>(), isNotNull);
    });

    testWidgets(
      'kursor dan blok pilihan TextField ikut tema beku, bukan primary tema app',
      (tester) async {
        late DefaultSelectionStyle gaya;
        await tester.pumpWidget(
          MaterialApp(
            theme: temaAsing(),
            home: BekuLembarKerja(
              child: Builder(
                builder: (c) {
                  gaya = DefaultSelectionStyle.of(c);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        final primer = TemaBeku.terang.colorScheme.primary;
        expect(temaAsing().colorScheme.primary, isNot(primer));
        expect(gaya.cursorColor, primer);
        expect(gaya.selectionColor, primer.withAlpha(102));
      },
    );
  });

  group('lewat pemanggil route SUNGGUHAN (layar pilih alat), tema app asing', () {
    const suhu = Category(
      kode: 'suhu-dan-kelembapan',
      nama: 'Suhu & Kelembapan',
      satuan: '°C',
    );

    Future<void> bukaPicker(
      WidgetTester tester,
      List<CalibrationCapability> kemampuan,
    ) async {
      layarPanjang(tester);
      await muat(
        tester,
        aplikasi(
          const InstrumentPickerScreen(kategori: suhu),
          tema: temaAsing(),
          kategori: _KategoriSuhu(kemampuan),
        ),
      );
      // Prasyarat: tema app memang beda dari tema beku (jadi tes tak hampa).
      final temaApp = Theme.of(tester.element(find.byType(InstrumentPickerScreen)));
      expect(temaApp.extension<PenandaBeku>(), isNull);
      expect(
        temaApp.colorScheme.primary,
        isNot(TemaBeku.terang.colorScheme.primary),
      );
    }

    void pastikanBeku<T extends Widget>(WidgetTester tester) {
      final layar = tester.element(find.byType(T));
      expect(bekuDi(layar), isTrue, reason: '$T membaca tema app, bukan tema beku');
      expect(
        Theme.of(layar).colorScheme.primary,
        TemaBeku.terang.colorScheme.primary,
      );
      expect(bekuDi(scaffoldDi<T>(tester)), isTrue);
    }

    testWidgets(
      'gerbang Temperatur Indikator, lalu lembar dari gerbang (instrument_picker + gerbang)',
      (tester) async {
        await bukaPicker(tester, const [
          CalibrationCapability(
            namaAlat: 'Temperature Indicator tanpa Sensor',
            profil: 'tits',
          ),
        ]);

        await tester.tap(find.text('Temperatur Indikator'));
        await tester.pumpAndSettle();
        pastikanBeku<TemperaturIndikatorGerbangScreen>(tester);

        await tester.tap(find.text('Tanpa Sensor'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        pastikanBeku<LembarKerjaScreen>(tester);
      },
    );

    testWidgets('lembar kerja dari kartu alat berprofil (instrument_picker)', (
      tester,
    ) async {
      await bukaPicker(tester, const [
        CalibrationCapability(namaAlat: 'Oven', profil: 'oven'),
      ]);

      await tester.tap(find.text('Oven'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      pastikanBeku<LembarKerjaScreen>(tester);
    });

    testWidgets('form input umum dari kartu alat tanpa profil (instrument_picker)', (
      tester,
    ) async {
      await bukaPicker(tester, const [
        CalibrationCapability(namaAlat: 'Alat Fiktif Uji'),
      ]);

      await tester.tap(find.text('Alat Fiktif Uji'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      pastikanBeku<CalibrationInputScreen>(tester);
    });

    testWidgets(
      'gaya yang ditulis di State lembar kerja (subjudul app bar) dan dialog '
      'dari State ikut beku',
      (tester) async {
        await bukaPicker(tester, const [
          CalibrationCapability(namaAlat: 'Oven', profil: 'oven'),
        ]);
        await tester.tap(find.text('Oven'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final beku = TemaBeku.terang;
        final m = beku.extension<SidikMaterial>()!;

        // `Theme.of(context).textTheme.labelSmall` di `State.build` (judulTambahan).
        final subjudul = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.text('Oven'),
              )
              .first,
        );
        expect(subjudul.style?.color, m.tinta2, reason: 'subjudul app bar');
        expect(subjudul.style?.fontSize, beku.textTheme.labelSmall!.fontSize);

        // Dialog yang dibuka dari `State` (`_ubahPengulangan`, `showDialog`).
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3 kali pengulangan').last);
        await tester.pumpAndSettle();

        final dialog = tester.element(find.byType(AlertDialog));
        expect(bekuDi(dialog), isTrue, reason: 'dialog dari State lembar kerja');
        expect(
          Theme.of(dialog).colorScheme.primary,
          beku.colorScheme.primary,
        );
        expect(
          SidikMaterial.of(dialog).kertas,
          m.kertas,
        );
      },
    );
  });

  group('SEMUA pemanggil layar beku membungkusnya (pindai sumber lib/)', () {
    /// Layar/widget beku yang dibuka dari berkas lain. Tiap pembuatannya (di
    /// luar deklarasi konstruktor) harus `BekuLembarKerja(child: <Nama>(`.
    const dibungkus = [
      'LembarKerjaScreen',
      'CalibrationInputScreen',
      'SkemaDinamisScreen',
      'TemperaturIndikatorGerbangScreen',
      // Area beku di luar empat layar (BEKU.md): onboarding, pratinjau PDF
      // sertifikat, tabel PERHITUNGAN, keypad.
      'OnboardingScreen',
      'SertifikatPdfView',
      'TabelPerhitunganWidget',
      'KeypadAngka',
    ];

    /// Buang komentar `//` dan `///`. Cukup untuk pemindaian ini: kode yang
    /// dipindai tidak menaruh `//` di dalam string yang berisi nama-nama di atas.
    String tanpaKomentar(String s) =>
        s.replaceAll(RegExp(r'//[^\n]*'), '');

    test('tiap pembuatan dibungkus BekuLembarKerja', () {
      final pembungkus = RegExp(r'BekuLembarKerja\(\s*child:\s*(?:const\s+)?$');
      final tidakDibungkus = <String>[];
      var dipindai = 0;

      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final jalur = e.path.replaceAll('\\', '/');
        final sumber = tanpaKomentar(e.readAsStringSync());

        for (final nama in dibungkus) {
          // `Nama(` yang BUKAN deklarasi konstruktor (`const Nama({`) dan bukan
          // bagian nama lain (`_NamaState(`).
          final pola = RegExp('(?<![A-Za-z0-9_])$nama\\((?!\\{)');
          for (final m in pola.allMatches(sumber)) {
            dipindai++;
            final depan = sumber.substring(0, m.start);
            if (!pembungkus.hasMatch(depan)) {
              final baris = '\n'.allMatches(depan).length + 1;
              tidakDibungkus.add('$jalur:$baris  $nama(');
            }
          }
        }
      }

      // Penjaga pemindai: 13 pembuatan empat layar beku (10 pemanggil di luar
      // + 3 di dalam berkas beku) ditambah 4 area lain (onboarding, pratinjau
      // PDF, tabel PERHITUNGAN, keypad) = 17 saat L1a. Angka lebih kecil berarti
      // polanya rusak, bukan pemanggilnya hilang.
      expect(
        dipindai,
        greaterThanOrEqualTo(17),
        reason: 'pemindai tak menemukan pemanggil',
      );
      expect(
        tidakDibungkus,
        isEmpty,
        reason:
            '\nPemanggil layar beku yang TIDAK dibungkus BekuLembarKerja '
            '(tampilannya ikut berubah saat token tema app diganti; baca '
            'docs/desain-ulang/BEKU.md dan lib/core/theme/beku_lembar_kerja.dart):\n'
            '${tidakDibungkus.join('\n')}',
      );
    });
  });
}

/// Layanan kategori baca-saja: satu kategori suhu dengan kemampuan [kemampuan].
class _KategoriSuhu implements CategoryService {
  _KategoriSuhu(this.kemampuan);

  final List<CalibrationCapability> kemampuan;

  @override
  Future<List<Category>> daftar(String token) async => const [
    Category(
      kode: 'suhu-dan-kelembapan',
      nama: 'Suhu & Kelembapan',
      satuan: '°C',
    ),
  ];

  @override
  Future<CategoryDetail> detail(String token, String kode) async =>
      CategoryDetail(kode: kode, nama: 'Suhu & Kelembapan', kemampuan: kemampuan);

  @override
  Future<CalibrationCapability> tambahKemampuan(
    String token,
    String kode,
    String namaAlat,
  ) async => throw UnimplementedError('jalur tambah tidak diuji di sini');
}

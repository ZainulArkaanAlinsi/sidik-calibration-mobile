import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/core/theme/palet_beku.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/kalibrasi_teknisi_provider.dart';
import 'package:sidik_calibration/screens/calibration/category_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/history/certificate_screen.dart';
import 'package:sidik_calibration/screens/teknisi/kalibrasi_teknisi_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// PENJAGA "02 PILIH ALAT" DAN PRATINJAU SERTIFIKAT (desain ulang Lab, L1b).
///
/// Keputusan pemilik 15 Nov 2026: tampilan dua layar "02 Pilih alat"
/// (`CategoryPickerScreen`, `InstrumentPickerScreen`) dan tiga bagian pratinjau
/// sertifikat di `history/certificate_screen.dart` (identitas sesi, tabel
/// laporan, standar dipakai; cermin PDF) TIDAK BOLEH berubah saat token tema
/// diganti ke Biru Awan. Layar-layar itu belum berhash (bukan beku resmi), jadi
/// penjaganya `BekuLembarKerja` di setiap pemanggil route (dipindai
/// `tema_beku_terpasang_test.dart`) dan berkas ini, yang membuktikan HASILNYA:
///
/// 1. di bawah tema app yang sengaja asing, kedua layar membaca `TemaBeku`;
/// 2. warna kuncinya (latar, bilah app, kartu, primer, tinta kedua) sama dengan
///    `PaletBeku`, di tema terang dan gelap, walau tema app sudah Biru Awan;
/// 3. gambar yang dirender SAMA PIKSEL dengan layar yang sama di bawah
///    `TemaBeku` langsung (tanpa pembungkus), jadi tampilannya = tampilan
///    sebelum token berganti, bukan sekadar "warna kunci cocok";
/// 4. pratinjau sertifikat beku, ringkasan di atasnya tidak (pembungkus
///    dipasang pada bagian yang dimaksud saja).
void main() {
  /// Tema app yang SENGAJA berbeda dari tema beku di semua yang terlihat.
  ThemeData temaAsing() => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFE91E63),
    scaffoldBackgroundColor: const Color(0xFFFFE0B2),
  );

  bool bekuDi(Element e) => Theme.of(e).extension<PenandaBeku>() != null;

  void layarPanjang(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  List<Override> mock() => [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-2'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    historyServiceProvider.overrideWithValue(MockHistoryService()),
    approvalServiceProvider.overrideWithValue(MockApprovalService()),
    pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
    categoryServiceProvider.overrideWithValue(MockCategoryService()),
    kalibrasiTeknisiServiceProvider.overrideWithValue(
      MockKalibrasiTeknisiService(sesi: const []),
    ),
  ];

  Widget aplikasi(
    Widget home, {
    ThemeData? tema,
    ThemeData? temaGelap,
    ThemeMode mode = ThemeMode.light,
  }) => ProviderScope(
    overrides: mock(),
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
    // `MockAuthService.me()` dan tarikan daftar memakai timer.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  /// Layar [T] sungguh dibuka lewat pemanggil route aslinya
  /// (`KalibrasiTeknisiScreen` -> "Mulai kalibrasi" -> kartu kategori).
  Future<ThemeData> bukaLewatPemanggil(
    WidgetTester tester, {
    ThemeData? tema,
    ThemeMode mode = ThemeMode.light,
  }) async {
    layarPanjang(tester);
    await muat(
      tester,
      aplikasi(
        const KalibrasiTeknisiScreen(),
        tema: tema,
        temaGelap: tema,
        mode: mode,
      ),
    );
    // Tema app, dibaca SEBELUM pindah layar (layar di bawah rute baru offstage).
    final temaApp = Theme.of(
      tester.element(find.byType(KalibrasiTeknisiScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('tombol-mulai-kalibrasi')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPickerScreen), findsOneWidget);

    return temaApp;
  }

  Element scaffoldDi<T extends Widget>(WidgetTester tester) => tester.element(
    find.descendant(of: find.byType(T), matching: find.byType(Scaffold)).first,
  );

  Future<void> keInstrumen(WidgetTester tester) async {
    await tester.tap(find.text('Panjang'));
    await tester.pumpAndSettle();
    expect(find.byType(InstrumentPickerScreen), findsOneWidget);
  }

  group('lewat pemanggil route SUNGGUHAN, tema app asing', () {
    testWidgets(
      'CategoryPickerScreen dan InstrumentPickerScreen membaca tema beku',
      (tester) async {
        final temaApp = await bukaLewatPemanggil(tester, tema: temaAsing());

        // Prasyarat: tema app memang beda dari tema beku (tes tidak hampa).
        expect(temaApp.extension<PenandaBeku>(), isNull);
        expect(
          temaApp.colorScheme.primary,
          isNot(TemaBeku.terang.colorScheme.primary),
        );

        final kategori = tester.element(find.byType(CategoryPickerScreen));
        expect(
          bekuDi(kategori),
          isTrue,
          reason: 'pilih kategori membaca tema app',
        );
        expect(
          Theme.of(kategori).colorScheme.primary,
          TemaBeku.terang.colorScheme.primary,
        );
        expect(bekuDi(scaffoldDi<CategoryPickerScreen>(tester)), isTrue);

        await keInstrumen(tester);
        final alat = tester.element(find.byType(InstrumentPickerScreen));
        expect(bekuDi(alat), isTrue, reason: 'pilih alat membaca tema app');
        expect(
          Theme.of(alat).colorScheme.primary,
          TemaBeku.terang.colorScheme.primary,
        );
        expect(bekuDi(scaffoldDi<InstrumentPickerScreen>(tester)), isTrue);
      },
    );
  });

  group('warna kunci kedua layar = PaletBeku, di bawah tema app Biru Awan', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      final mode = gelap ? ThemeMode.dark : ThemeMode.light;
      final latar = gelap ? PaletBeku.latarGelap : PaletBeku.latarTerang;
      final kertas = gelap ? PaletBeku.kertasGelap : PaletBeku.kertasTerang;
      final primer = gelap ? PaletBeku.kobalt300 : PaletBeku.kobalt700;
      final tinta2 = gelap ? PaletBeku.tinta2Gelap : PaletBeku.tinta2Terang;
      final tepi = gelap
          ? PaletBeku.garisHalusGelap
          : PaletBeku.garisHalusTerang;

      void periksaWarna(WidgetTester tester, Type layar) {
        final el = tester.element(find.byType(layar));
        final tema = Theme.of(el);
        expect(tema.scaffoldBackgroundColor, latar, reason: '$layar latar');
        expect(tema.colorScheme.primary, primer, reason: '$layar primer');
        expect(tema.colorScheme.surface, kertas, reason: '$layar permukaan');
        expect(
          tema.colorScheme.onSurfaceVariant,
          tinta2,
          reason: '$layar tinta kedua',
        );

        Color? warnaMaterial(Finder di) => tester
            .widget<Material>(
              find.descendant(of: di, matching: find.byType(Material)).first,
            )
            .color;

        // Yang BENAR-BENAR dilukis: latar halaman, bilah app, dan kartu.
        expect(
          warnaMaterial(
            find
                .descendant(
                  of: find.byType(layar),
                  matching: find.byType(Scaffold),
                )
                .first,
          ),
          latar,
          reason: '$layar: latar yang dilukis',
        );
        expect(
          warnaMaterial(
            find
                .descendant(
                  of: find.byType(layar),
                  matching: find.byType(AppBar),
                )
                .first,
          ),
          kertas,
          reason: '$layar: bilah app yang dilukis',
        );
        final kartu = find.descendant(
          of: find.byType(layar),
          matching: find.byType(Card),
        );
        if (kartu.evaluate().isNotEmpty) {
          expect(
            warnaMaterial(kartu.first),
            kertas,
            reason: '$layar: kartu yang dilukis',
          );
          final bentuk =
              tester
                      .widget<Material>(
                        find
                            .descendant(
                              of: kartu.first,
                              matching: find.byType(Material),
                            )
                            .first,
                      )
                      .shape
                  as RoundedRectangleBorder;
          expect(bentuk.side.color, tepi, reason: '$layar: tepi kartu');
          expect(
            bentuk.borderRadius,
            BorderRadius.circular(BentukBeku.panel),
            reason: '$layar: sudut kartu',
          );
        }
      }

      testWidgets('tema $nama', (tester) async {
        await bukaLewatPemanggil(tester, mode: mode);
        periksaWarna(tester, CategoryPickerScreen);

        await keInstrumen(tester);
        periksaWarna(tester, InstrumentPickerScreen);
      });
    }
  });

  group('gambar SAMA PIKSEL dengan tema beku langsung (tanpa pembungkus)', () {
    const kategoriPanjang = Category(
      id: 1,
      kode: 'panjang',
      nama: 'Panjang',
      satuan: 'mm',
    );

    /// Render [app] di dalam `RepaintBoundary` dan kembalikan pikselnya.
    Future<Uint8List> gambar(WidgetTester tester, Widget app) async {
      final kunci = GlobalKey();
      layarPanjang(tester);
      await muat(tester, RepaintBoundary(key: kunci, child: app));
      final batas = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(kunci),
      );
      final piksel = await tester.runAsync(() async {
        final citra = await batas.toImage();
        final data = await citra.toByteData(format: ui.ImageByteFormat.rawRgba);

        return data!.buffer.asUint8List();
      });

      return piksel!;
    }

    for (final (nama, gelap) in [('terang', false), ('gelap', true)]) {
      final mode = gelap ? ThemeMode.dark : ThemeMode.light;
      final temaBeku = gelap ? TemaBeku.gelap : TemaBeku.terang;

      for (final (layar, bangun) in <(String, Widget Function())>[
        ('pilih kategori', () => const CategoryPickerScreen()),
        ('pilih alat', () => InstrumentPickerScreen(kategori: kategoriPanjang)),
      ]) {
        testWidgets('$layar, tema $nama', (tester) async {
          final dibungkus = await gambar(
            tester,
            aplikasi(BekuLembarKerja(child: bangun()), mode: mode),
          );
          final acuan = await gambar(
            tester,
            aplikasi(bangun(), tema: temaBeku, temaGelap: temaBeku, mode: mode),
          );
          // Layar yang sama TANPA pembungkus, di bawah tema app Biru Awan.
          final tanpaPembungkus = await gambar(
            tester,
            aplikasi(bangun(), mode: mode),
          );

          expect(dibungkus.length, acuan.length);
          expect(
            _samaPiksel(dibungkus, acuan),
            isTrue,
            reason:
                '$layar ($nama) dengan pembungkus TIDAK sama piksel dengan tema '
                'beku langsung: tampilannya ikut tema app.',
          );
          // Penjaga: tanpa pembungkus gambarnya memang beda (tema app sudah Biru
          // Awan, bukan tema beku), jadi kesamaan di atas bukan kebetulan.
          expect(
            _samaPiksel(tanpaPembungkus, acuan),
            isFalse,
            reason:
                'tema app masih sama dengan tema beku ($layar, $nama): tes ini '
                'tidak membuktikan apa-apa',
          );
        });
      }
    }
  });

  group('pratinjau sertifikat: bagian cermin PDF beku, sisanya tidak', () {
    testWidgets(
      'identitas, tabel laporan, dan standar dipakai membaca tema beku',
      (tester) async {
        layarPanjang(tester);
        await muat(
          tester,
          aplikasi(
            const CertificateScreen(calibrationId: 1),
            tema: temaAsing(),
            temaGelap: temaAsing(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        Element di(String teks) => tester.element(find.text(teks).first);

        final bagian = <String, String>{
          'identitas sesi': 'IDENTITAS SESI',
          'laporan kalibrasi': 'LAPORAN KALIBRASI',
          'standar dipakai': 'STANDAR YANG DIPAKAI',
        };
        for (final MapEntry(key: apa, value: judul) in bagian.entries) {
          expect(find.text(judul), findsOneWidget, reason: '$apa tidak tampil');
          final el = di(judul);
          expect(
            bekuDi(el),
            isTrue,
            reason: '$apa membaca tema app, bukan beku',
          );
          expect(
            Theme.of(el).colorScheme.primary,
            TemaBeku.terang.colorScheme.primary,
            reason: apa,
          );
        }

        // Kartu di bagian beku dilukis dengan nilai beku, bukan tema asing.
        final kartuIdentitas = find.ancestor(
          of: find.text('IDENTITAS SESI'),
          matching: find.byType(Column),
        );
        expect(kartuIdentitas, findsWidgets);
        final kartu = find
            .descendant(
              of: find
                  .ancestor(
                    of: find.text('IDENTITAS SESI'),
                    matching: find.byType(Column),
                  )
                  .first,
              matching: find.byType(Card),
            )
            .first;
        expect(
          tester
              .widget<Material>(
                find
                    .descendant(of: kartu, matching: find.byType(Material))
                    .first,
              )
              .color,
          PaletBeku.kertasTerang,
        );

        // Yang BUKAN pratinjau tidak ikut beku: nomor sertifikat di kepala.
        final nomor = tester.element(find.text('CAL/2026/07/0001').first);
        expect(
          bekuDi(nomor),
          isFalse,
          reason: 'pembungkus terlalu lebar: kepala sertifikat ikut beku',
        );
      },
    );
  });
}

bool _samaPiksel(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

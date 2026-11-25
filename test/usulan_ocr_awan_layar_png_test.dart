import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';

import 'support/layar_review_awan_contoh.dart';

/// PNG untuk persetujuan tampilan usulan OCR awan DI LAYAR CEK (gerbang 3).
///
/// Menulis berkas HANYA bila env `SIDIK_PNG_DIR` disetel; tanpa itu tes ini
/// cuma memastikan layarnya terbangun, tanpa menyentuh disk:
///
///   SIDIK_PNG_DIR=C:/Users/USER/sidik-dokumentasi/2026-11-25/ocr/png \
///     flutter test test/usulan_ocr_awan_layar_png_test.dart
///
/// BUKAN golden pembanding (tidak ada PNG acuan di repo). Yang menilai manusia.
/// Data palsu (`support/layar_review_awan_contoh.dart`), potongan abu-abu
/// bergaris, bukan foto pelanggan dan bukan bukti akurasi awan.
void main() {
  final folder = Platform.environment['SIDIK_PNG_DIR'];

  setUpAll(() async {
    Future<void> muat(String keluarga, String awalan) async {
      final pemuat = FontLoader(keluarga);
      for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final bytes = File('assets/fonts/$awalan-$b.ttf').readAsBytesSync();
        pemuat.addFont(Future.value(bytes.buffer.asByteData()));
      }
      await pemuat.load();
    }

    await muat('Inter', 'Inter');
    await muat('IBMPlexMono', 'IBMPlexMono');

    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final ikon = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (ikon.existsSync()) {
        final pemuat = FontLoader('MaterialIcons')
          ..addFont(Future.value(ikon.readAsBytesSync().buffer.asByteData()));
        await pemuat.load();
      }
    }
  });

  final kunciRepaint = GlobalKey();

  Future<void> bukaLayar(
    WidgetTester tester, {
    required MockOcrAwanSelService service,
    required double tinggi,
  }) async {
    final baris = barisReviewContoh();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(390, tinggi);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(
        key: kunciRepaint,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          theme: AppTheme.light,
          home: FotoReviewScreen(
            baris: baris,
            mintaUsulanAwan: pemintaContoh(penjalurContoh(service), baris),
            kunciServerPerBaris: kunciServerContoh(baris),
          ),
        ),
      ),
    );

    // Potongan contoh didekode lebih dulu supaya tampil di PNG.
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(Scaffold).first);
      for (final b in baris) {
        await precacheImage(MemoryImage(b.potongan!), ctx);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> potret(WidgetTester tester, String nama) async {
    expect(tester.takeException(), isNull);

    if (folder == null) return;

    final batas =
        tester.renderObject(find.byKey(kunciRepaint)) as RenderRepaintBoundary;

    await tester.runAsync(() async {
      final gambar = await batas.toImage(pixelRatio: 2.0);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      Directory(folder).createSync(recursive: true);
      File('$folder/$nama.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> ketuk(WidgetTester tester, Key kunci) async {
    await tester.ensureVisible(find.byKey(kunci));
    await tester.tap(find.byKey(kunci));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'PNG 5: usulan awan di layar cek (satu sel dipakai, satu kuning menunggu, '
    'dua sel tetap kosong)',
    (tester) async {
      final service = MockOcrAwanSelService(hasil: hasilAwanContoh());
      await bukaLayar(tester, service: service, tinggi: 1750);

      await ketuk(tester, const ValueKey('minta-usulan-awan'));
      // Teknisi memutuskan SATU sel (A). B menunggu, C dan D tetap kosong.
      await ketuk(tester, const ValueKey('usulan-pakai-$kunciA'));

      expect(find.byKey(const ValueKey('usulan-$kunciB')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tanpa-usulan-$kunciC')),
        findsOneWidget,
      );

      await potret(tester, 'usulan-5-layar-cek-terang');
    },
  );

  testWidgets(
    'PNG 6: fallback, awan belum aktif di server, teknisi lanjut manual',
    (tester) async {
      // Bawaan Mock = galat produksi sekarang: 503 ocr_cloud_belum_aktif.
      final service = MockOcrAwanSelService();
      await bukaLayar(tester, service: service, tinggi: 1230);

      await ketuk(tester, const ValueKey('minta-usulan-awan'));

      expect(find.byKey(const ValueKey('usulan-awan-gagal')), findsOneWidget);

      // Lanjut manual: teknisi mengetik angka dari kertas di sel pertama.
      await tester.enterText(find.byType(TextField).first, '4,01');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(service.permintaan, hasLength(1));

      await potret(tester, 'usulan-6-fallback-terang');
    },
  );
}

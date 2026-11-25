import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/models/usulan_ocr_awan.dart';
import 'package:sidik_calibration/screens/calibration/widgets/panel_usulan_ocr_awan.dart';

import 'support/papan_usulan_contoh.dart';

/// PNG untuk persetujuan tampilan layar usulan OCR awan (gerbang 3).
///
/// Menulis berkas HANYA bila env `SIDIK_PNG_DIR` disetel ke folder tujuan;
/// tanpa itu tes ini cuma memastikan layarnya terbangun di tiga keadaan, dan
/// tidak menyentuh disk. Perintah:
///
///   SIDIK_PNG_DIR=C:/Users/USER/sidik-dokumentasi/2026-11-25/ocr/png \
///     flutter test test/usulan_ocr_awan_png_test.dart
///
/// Ini BUKAN golden pembanding: tidak ada PNG acuan di repo, jadi tidak ada
/// yang bisa merah karena rasterisasi font beda antar-OS. Yang dilihat manusia.
/// Data palsu (`support/papan_usulan_contoh.dart`), bukan foto pelanggan.
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

  Future<void> potret(
    WidgetTester tester, {
    required String nama,
    required Brightness mode,
    required PapanUsulanAwan papan,
    String? ubahKunci,
    String? ketik,
  }) async {
    const lebar = 390.0;
    const tinggi = 2400.0;

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(lebar, tinggi);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tema = mode == Brightness.light ? AppTheme.light : AppTheme.dark;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: tema,
        home: Scaffold(
          body: SingleChildScrollView(
            // Batas potret = tinggi isi, bukan tinggi jendela.
            child: RepaintBoundary(
              key: kunciRepaint,
              child: ColoredBox(
                color: tema.scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PanelUsulanOcrAwan(
                    papan: papan,
                    labelSel: labelSelContoh,
                    onPakai: (_) {},
                    onUbah: (_, _) {},
                    onTolak: (_) {},
                    onKembalikan: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (ubahKunci != null) {
      await tester.tap(find.byKey(ValueKey('usulan-ubah-$ubahKunci')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('usulan-isian-$ubahKunci')),
        ketik!,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    // Layar terbangun tanpa meluap: tidak ada galat render yang ditangkap.
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

  // Keadaan campuran: satu dipakai, satu ditolak, sisanya menunggu.
  PapanUsulanAwan campuran() =>
      papanUsulanContoh().pakai(kunciSatuBentuk).tolak(kunciBeralasan);

  testWidgets('PNG 1: awal, semua menunggu (terang)', (tester) async {
    await potret(
      tester,
      nama: 'usulan-1-awal-terang',
      mode: Brightness.light,
      papan: papanUsulanContoh(),
    );
  });

  testWidgets('PNG 2: sebagian diputuskan (terang)', (tester) async {
    await potret(
      tester,
      nama: 'usulan-2-sebagian-terang',
      mode: Brightness.light,
      papan: campuran(),
    );
  });

  testWidgets('PNG 3: mengubah angka, isian salah (terang)', (tester) async {
    await potret(
      tester,
      nama: 'usulan-3-ubah-salah-terang',
      mode: Brightness.light,
      papan: papanUsulanContoh(),
      ubahKunci: kunciDuaBentuk,
      ketik: '4,,',
    );
  });

  testWidgets('PNG 4: awal, semua menunggu (gelap)', (tester) async {
    await potret(
      tester,
      nama: 'usulan-4-awal-gelap',
      mode: Brightness.dark,
      papan: papanUsulanContoh(),
    );
  });
}

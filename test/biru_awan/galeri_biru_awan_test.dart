// Galeri komponen Biru Awan (khusus pengembang) dan pintu masuknya.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/motion/gerak_bersama.dart';
import 'package:sidik_calibration/screens/design_system/design_system_screen.dart';
import 'package:sidik_calibration/screens/pengembang/galeri_biru_awan_screen.dart';
import 'package:sidik_calibration/widgets/biru_awan/avatar_inisial.dart';
import 'package:sidik_calibration/widgets/biru_awan/banner_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/bilah_langkah.dart';
import 'package:sidik_calibration/widgets/biru_awan/chip_saring.dart';
import 'package:sidik_calibration/widgets/biru_awan/dialog_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/garis_waktu.dart';
import 'package:sidik_calibration/widgets/biru_awan/grafik_batang.dart';
import 'package:sidik_calibration/widgets/biru_awan/hero_langit.dart';
import 'package:sidik_calibration/widgets/biru_awan/isian_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/kartu_sidik24.dart';
import 'package:sidik_calibration/widgets/biru_awan/keadaan_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/kepala_layar.dart';
import 'package:sidik_calibration/widgets/biru_awan/kolom_cari.dart';
import 'package:sidik_calibration/widgets/biru_awan/lembar_bawah_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/lencana.dart';
import 'package:sidik_calibration/widgets/biru_awan/panel_baris.dart';
import 'package:sidik_calibration/widgets/biru_awan/stempel_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/stepper_tegak.dart';
import 'package:sidik_calibration/widgets/biru_awan/toast_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/ubin_ikon.dart';
import 'package:sidik_calibration/widgets/biru_awan/ubin_kpi.dart';

import '../support/uji_biru_awan.dart';

Finder _jenis(String nama) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith(nama));

/// Memberi waktu animasi masuk selesai. Bukan `pumpAndSettle`: galeri memuat
/// satu pemutar "sibuk" (gerak berulang yang sah di `ELEMEN.md`).
Future<void> _masuk(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  setUpAll(muatFontUji);

  testWidgets('memuat SEMUA komponen L3a, L3b, L2 dan gerak bersama', (
    tester,
  ) async {
    layarUji(tester, lebar: 390, tinggi: 9000);
    await tester.pumpWidget(
      aplikasiUji(const GaleriBiruAwanScreen(), bergulir: false),
    );
    await _masuk(tester);
    expect(tester.takeException(), isNull);
    for (final t in <Type>[
      TombolSidik,
      TombolBulat,
      IsianSidik,
      StempelSidik,
      ChipSaring,
      KartuSidik24,
      PanelBaris,
      BarisMenu64,
      BarisDaftar72,
      UbinIkon,
      KepalaTab,
      KepalaAnak,
      MasukBerurutan,
      // L3b.
      HeroLangit,
      UbinKpi,
      GrafikBatang,
      StepperTegak,
      GarisWaktu,
      AvatarInisial,
      Lencana,
      LoncengBerlencana,
      BilahLangkah,
      KolomCari,
      // L2.
      ToastSidik,
      DialogSidik,
      LembarBawahSidik,
      BannerSidik,
      KeadaanMemuat,
      KeadaanKosong,
      KeadaanGalat,
    ]) {
      expect(find.byType(t), findsWidgets, reason: '$t tidak ada di galeri');
    }
    expect(_jenis('SegmenPil'), findsWidgets, reason: 'SegmenPil');
  });

  testWidgets('semua ragam dan keadaan penting tampil', (tester) async {
    layarUji(tester, lebar: 390, tinggi: 9000);
    await tester.pumpWidget(
      aplikasiUji(const GaleriBiruAwanScreen(), bergulir: false),
    );
    await _masuk(tester);
    final ragam = tester
        .widgetList<TombolSidik>(find.byType(TombolSidik))
        .map((t) => t.ragam)
        .toSet();
    expect(ragam, RagamTombolSidik.values.toSet());
    final bulat = tester
        .widgetList<TombolBulat>(find.byType(TombolBulat))
        .map((t) => t.ukuran)
        .toSet();
    expect(bulat, UkuranTombolBulat.values.toSet());
    expect(
      tester
          .widgetList<IsianSidik>(find.byType(IsianSidik))
          .any((i) => i.galat != null),
      isTrue,
      reason: 'isian galat',
    );
    expect(
      tester
          .widgetList<IsianSidik>(find.byType(IsianSidik))
          .any((i) => !i.enabled),
      isTrue,
      reason: 'isian mati',
    );
    expect(
      tester
          .widgetList<StempelSidik>(find.byType(StempelSidik))
          .any((s) => s.adalahFail),
      isTrue,
      reason: 'stempel FAIL',
    );
    expect(find.text('Tanpa PASS/FAIL'), findsWidgets);
  });

  for (final gelap in [false, true]) {
    testWidgets(
      '320 dp x huruf 1,3 tanpa luapan (${gelap ? 'gelap' : 'terang'})',
      (tester) async {
        layarUji(tester, lebar: 320, tinggi: 14000);
        await tester.pumpWidget(
          aplikasiUji(
            const GaleriBiruAwanScreen(),
            bergulir: false,
            gelap: gelap,
            skala: 1.3,
          ),
        );
        await _masuk(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('kurangi gerak: semua langsung tampil, tanpa animasi tersisa', (
    tester,
  ) async {
    layarUji(tester, lebar: 390, tinggi: 9000);
    await tester.pumpWidget(
      aplikasiUji(kurangiGerak(const GaleriBiruAwanScreen()), bergulir: false),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('bagian bisa diinteraksi: chip dan segmen berpindah', (
    tester,
  ) async {
    layarUji(tester, lebar: 390, tinggi: 9000);
    await tester.pumpWidget(
      aplikasiUji(const GaleriBiruAwanScreen(), bergulir: false),
    );
    await _masuk(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Ada FAIL')));
    await tester.pump();
    final chip = tester.widget<ChipSaring>(
      find.widgetWithText(ChipSaring, 'Ada FAIL'),
    );
    expect(chip.terpilih, isTrue);
    await tester.tap(find.text('Viewer'));
    await tester.pump();
    final dipilih = tester.widget<Text>(find.text('Viewer')).style!.color;
    final lain = tester.widget<Text>(find.text('Admin')).style!.color;
    expect(dipilih, isNot(lain));
  });

  group('pintu masuk: hanya dari galeri lama, hanya di debug', () {
    testWidgets('DesignSystemScreen (debug) membuka galeri', (tester) async {
      layarUji(tester, lebar: 390, tinggi: 2400);
      await tester.pumpWidget(
        aplikasiUji(const DesignSystemScreen(), bergulir: false),
      );
      await tester.pump();
      await tester.tap(find.text('Buka galeri Biru Awan'));
      await tester.pump();
      await _masuk(tester);
      expect(find.text('Galeri Biru Awan'), findsOneWidget);
      expect(find.byType(GaleriBiruAwanScreen), findsOneWidget);
    });

    test(
      'baris itu dibungkus kDebugMode dan satu-satunya pengimpor galeri',
      () {
        final lama = File(
          'lib/screens/design_system/design_system_screen.dart',
        ).readAsStringSync();
        expect(lama, contains('if (kDebugMode)'));
        final indeksJaga = lama.indexOf('if (kDebugMode)');
        final indeksGaleri = lama.indexOf('GaleriBiruAwanScreen()');
        expect(indeksGaleri, greaterThan(indeksJaga));

        final pengimpor = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where(
              (f) => f.readAsStringSync().contains(
                'pengembang/galeri_biru_awan_screen.dart',
              ),
            )
            .map((f) => f.path.replaceAll('\\', '/'))
            .toList();
        expect(pengimpor, [
          'lib/screens/design_system/design_system_screen.dart',
        ]);
      },
    );
  });
}

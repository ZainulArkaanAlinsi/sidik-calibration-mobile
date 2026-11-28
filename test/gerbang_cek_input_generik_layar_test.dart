import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_draft.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar isian generik (alat tanpa profil), tombol Kirimnya DIJALANKAN.
/// Sejak keputusan pemilik 27 Nov 2026 angka dari "Baca dari foto" TIDAK lagi
/// menahan "Kirim untuk approval": kotaknya tetap bertanda kuning ("Perlu
/// dicek") sampai teknisi mengubah angkanya, panel jumlah dan pesan
/// "ditahan" tidak muncul, dan Simpan draft tetap bebas.
///
/// Jalur kamera aslinya (ML Kit + dua layar koreksi) tidak bisa dijalankan di
/// test; `CalibrationInputScreen.petaFotoUji` menuangkan hasil pemetaannya
/// persis seperti sesudah teknisi menyelesaikan alurnya.
class _Perekam implements CalibrationService {
  int panggilan = 0;
  CalibrationDraft? terakhir;

  @override
  Future<int> buatSesi(String token, CalibrationDraft draft) async {
    panggilan++;
    terakhir = draft;

    return 999;
  }
}

void main() {
  Widget app(_Perekam perekam) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      calibrationServiceProvider.overrideWithValue(perekam),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalibrationInputScreen(
                    petaFotoUji: (
                      titik: [
                        (nilaiAcuan: '50,0', pembacaan: ['50,02', '50,01']),
                      ],
                      satuan: 'mm',
                    ),
                  ),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> pilihIdentitas(WidgetTester tester) async {
    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panjang').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Pilih alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Jangka Sorong Mitutoyo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih standar acuan'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gauge Block Set Grade 0').last);
    await tester.pumpAndSettle();
  }

  Finder kotak(String isi) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == isi,
  );

  Finder tombolKirim() =>
      find.widgetWithText(FilledButton, 'Kirim untuk approval');

  bool kirimMati(WidgetTester tester) =>
      tester.widget<FilledButton>(tombolKirim()).onPressed == null;

  Future<_Perekam> siap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final perekam = _Perekam();
    await tester.pumpWidget(app(perekam));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await pilihIdentitas(tester);

    return perekam;
  }

  testWidgets('angka foto TIDAK menahan Kirim; Simpan draft tetap bebas', (
    tester,
  ) async {
    final perekam = await siap(tester);

    // Tiga kotak dari foto tetap kuning, tetapi tidak ada panel gerbang.
    expect(find.text('Perlu dicek'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('input-cek-jumlah')), findsNothing);
    expect(find.text('3 isian bacaan kamera belum dicek'), findsNothing);
    expect(kirimMati(tester), isFalse);

    final draf = find.widgetWithText(OutlinedButton, 'Simpan draft');
    await tester.ensureVisible(draf);
    expect(tester.widget<OutlinedButton>(draf).onPressed, isNotNull);

    await tester.tap(draf);
    await tester.pumpAndSettle();
    expect(perekam.panggilan, 1, reason: 'draf tidak ditahan');
    expect(perekam.terakhir!.simpanSebagaiDraft, isTrue);
  });

  testWidgets('Kirim langsung berangkat walau tak satu kotak foto diubah', (
    tester,
  ) async {
    final perekam = await siap(tester);
    expect(find.text('Perlu dicek'), findsNWidgets(3));

    await tester.ensureVisible(tombolKirim());
    await tester.tap(tombolKirim());
    await tester.pumpAndSettle();

    expect(perekam.panggilan, 1, reason: 'kuning tidak menahan Kirim');
    expect(perekam.terakhir!.simpanSebagaiDraft, isFalse);
    expect(
      find.textContaining('Kirim final ditahan'),
      findsNothing,
      reason: 'pesan gerbang lama tidak muncul lagi',
    );
  });

  testWidgets('dicek satu per satu: tiap kotak, lalu Kirim berangkat', (
    tester,
  ) async {
    final perekam = await siap(tester);

    for (final kunci in ['target', '0', '1']) {
      final tombol = find.byKey(ValueKey('cek-isian-$kunci'));
      await tester.ensureVisible(tombol);
      await tester.tap(tombol);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('input-cek-jumlah')), findsNothing);
    expect(kirimMati(tester), isFalse);

    await tester.ensureVisible(tombolKirim());
    await tester.tap(tombolKirim());
    await tester.pumpAndSettle();

    expect(perekam.panggilan, 1, reason: 'semua dicek: kirim final berangkat');
    expect(perekam.terakhir!.simpanSebagaiDraft, isFalse);
  });

  testWidgets(
    'angka dikembalikan ke angka mesin: kuning lagi, Kirim tetap hidup',
    (tester) async {
      final perekam = await siap(tester);

      // Ketiga kotak diubah: tidak ada yang kuning, Kirim hidup.
      await tester.enterText(kotak('50,0'), '50,5');
      await tester.enterText(kotak('50,02'), '50,3');
      await tester.enterText(kotak('50,01'), '50,4');
      await tester.pumpAndSettle();
      expect(find.text('Perlu dicek'), findsNothing);
      expect(kirimMati(tester), isFalse);

      // Satu kotak dikembalikan ke angka mesin: kuning lagi (perlu dilihat
      // teknisi), tetapi tidak ada lagi yang mematikan Kirim.
      await tester.enterText(kotak('50,3'), '50,02');
      await tester.pumpAndSettle();
      expect(find.text('Perlu dicek'), findsOneWidget);
      expect(kirimMati(tester), isFalse);
      expect(find.byKey(const ValueKey('input-cek-jumlah')), findsNothing);
      expect(
        find.textContaining('Kirim final ditahan'),
        findsNothing,
        reason: 'pesan gerbang lama tidak muncul lagi',
      );

      // Tidak ada yang terkirim sebelum teknisi sendiri menekan Kirim.
      expect(perekam.panggilan, 0);
    },
  );
}

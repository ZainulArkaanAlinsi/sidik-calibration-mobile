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

/// Layar isian generik (alat tanpa profil), tombol Kirimnya DIJALANKAN:
/// angka dari "Baca dari foto" menahan "Kirim untuk approval" sampai tiap
/// kotak dicek, dan tombol yang sudah basi pun tidak boleh mengirim.
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

  testWidgets('angka foto menahan Kirim; Simpan draft tetap bebas', (
    tester,
  ) async {
    final perekam = await siap(tester);

    expect(find.text('3 isian bacaan kamera belum dicek'), findsOneWidget);
    expect(kirimMati(tester), isTrue);

    final draf = find.widgetWithText(OutlinedButton, 'Simpan draft');
    await tester.ensureVisible(draf);
    expect(tester.widget<OutlinedButton>(draf).onPressed, isNotNull);

    await tester.tap(draf);
    await tester.pumpAndSettle();
    expect(perekam.panggilan, 1, reason: 'draf tidak ditahan gerbang');
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

  testWidgets('tombol Kirim yang basi tidak mengirim apa pun', (tester) async {
    final perekam = await siap(tester);

    // Ketiga kotak diubah (= dicek): Kirim hidup. Tangkap penangannya.
    await tester.enterText(kotak('50,0'), '50,5');
    await tester.enterText(kotak('50,02'), '50,3');
    await tester.enterText(kotak('50,01'), '50,4');
    await tester.pumpAndSettle();
    expect(kirimMati(tester), isFalse, reason: 'prasyarat: semua dicek');

    final basi = tester.widget<FilledButton>(tombolKirim()).onPressed!;

    // Satu kotak dikembalikan ke angka mesin: perlu dicek lagi, Kirim mati.
    await tester.enterText(kotak('50,3'), '50,02');
    await tester.pumpAndSettle();
    expect(kirimMati(tester), isTrue);

    // Penangan lama tetap tidak boleh mengirim (jaring `_submit`).
    basi();
    await tester.pumpAndSettle();

    expect(perekam.panggilan, 0, reason: 'angka kamera belum dicek terkirim');
    expect(
      find.textContaining('Kirim final ditahan: 1 isian bacaan kamera'),
      findsOneWidget,
    );
  });
}

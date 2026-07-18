import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/ph_calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app({bool submitGagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      calibrationServiceProvider.overrideWithValue(
        MockCalibrationService(gagal: submitGagal),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Sama kayak calibration_input_test.dart — butuh Navigator stack
      // beneran biar Navigator.pop() waktu submit sukses nggak nge-crash.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PhCalibrationInputScreen(),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Form pH punya ~68 TextField (3 titik buffer x 21 field) — jauh lebih
/// panjang dari viewport test standar (800x600). `ListView` cuma nge-build
/// item yang deket viewport, jadi index `find.byType(TextField).at(n)`
/// berubah-ubah tiap discroll. Solusinya: bikin viewport test raksasa biar
/// seluruh form ke-build sekaligus, index-nya stabil.
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 10000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _bukaLayar(WidgetTester tester) async {
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

/// Isi form sampai siap submit: alat + standar + kondisi lingkungan + 3
/// titik buffer (masing-masing 5 pembacaan sesudah adjustment).
///
/// Thermohygro sekarang dropdown preset (default `TH-3`, nggak perlu
/// diisi manual) — bukan `TextField` lagi. Urutan `TextField` di layar:
/// suhu awal[0], suhu akhir[1], kelembaban awal[2], kelembaban akhir[3],
/// lalu 3 kartu titik buffer @21 field (nilai standar + 5x2 sebelum +
/// 5x2 sesudah).
Future<void> _isiFormLengkap(WidgetTester tester) async {
  await tester.tap(find.text('Pilih alat'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('pH Meter Mettler Toledo').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih standar acuan'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text('pH Buffer Solution 7').last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).at(0), '21.3');
  await tester.enterText(find.byType(TextField).at(1), '21.5');
  await tester.enterText(find.byType(TextField).at(2), '53');
  await tester.enterText(find.byType(TextField).at(3), '56');

  var index = 4;
  for (var titik = 0; titik < 3; titik++) {
    index++; // nilai standar kartu ini — biarin default
    index += 10; // 5x(pH+suhu) "sebelum adjustment" — biarin kosong
    for (var i = 0; i < 5; i++) {
      await tester.enterText(
        find.byType(TextField).at(index++),
        '${4 + titik * 3}.0',
      );
      await tester.enterText(find.byType(TextField).at(index++), '22.0');
    }
  }
}

void main() {
  testWidgets('nampilin pilihan alat & standar setelah dimuat', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    expect(find.text('Pilih alat'), findsOneWidget);
    expect(find.text('Pilih standar acuan'), findsOneWidget);
    expect(find.text('Buffer pH 4'), findsOneWidget);
    expect(find.text('Buffer pH 7'), findsOneWidget);
    expect(find.text('Buffer pH 10'), findsOneWidget);
  });

  testWidgets('submit tanpa pilih apa-apa → validasi alat dulu', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await tester.tap(find.text('KIRIM UNTUK APPROVAL'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih alat dulu.'), findsOneWidget);
  });

  testWidgets('isi form lengkap → kirim approval sukses & layar ketutup', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiFormLengkap(tester);
    await tester.tap(find.text('KIRIM UNTUK APPROVAL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sesi kalibrasi dikirim untuk approval.'),
      findsOneWidget,
    );
    expect(find.byType(PhCalibrationInputScreen), findsNothing);
  });

  testWidgets('submit gagal di server → pesan error, layar tetap kebuka', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app(submitGagal: true));
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiFormLengkap(tester);
    await tester.tap(find.text('SIMPAN DRAFT'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
    expect(find.byType(PhCalibrationInputScreen), findsOneWidget);
  });
}

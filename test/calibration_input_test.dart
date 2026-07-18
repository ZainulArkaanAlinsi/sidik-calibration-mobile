import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
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
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
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
      // Dibungkus tombol "buka" (bukan langsung `home:`) — CalibrationInputScreen
      // manggil `Navigator.pop()` waktu submit sukses, jadi butuh stack Navigator
      // beneran (bukan root route doang) biar itu bisa jalan kayak di app asli.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalibrationInputScreen(),
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

Future<void> _bukaLayar(WidgetTester tester) async {
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

/// Sejak field "Lokasi Kalibrasi" ditambah, form makin panjang dan
/// `_isiFormLengkap` (pakai `find.byType(TextField).at(n)` langsung tanpa
/// scroll) butuh viewport gede biar `ListView` nge-build semua field-nya
/// sekaligus — sama kasusnya kayak `ph_calibration_input_test.dart`.
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Form-nya lebih panjang dari viewport test — tombol submit di paling
/// bawah perlu di-scroll dulu biar ke-build sebelum di-tap.
Future<void> _scrollKe(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

/// Isi seluruh form sampai siap disubmit: pilih kategori → alat muncul →
/// pilih alat → pilih standar → isi 1 titik ukur dengan 2 pembacaan.
Future<void> _isiFormLengkap(WidgetTester tester) async {
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

  // Urutan TextField di layar: suhu ruang[0], kelembaban[1] (udah keisi
  // default), baru nilai target[2] + satuan[3] + 2 pembacaan[4,5] titik 1.
  await tester.enterText(find.byType(TextField).at(2), '50.0');
  await tester.enterText(find.byType(TextField).at(3), 'mm');
  await tester.enterText(find.byType(TextField).at(4), '50.02');
  await tester.enterText(find.byType(TextField).at(5), '50.01');
}

void main() {
  testWidgets('nampilin pilihan kategori & standar setelah dimuat', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    expect(find.text('Pilih kategori alat'), findsOneWidget);
    expect(find.text('Pilih standar acuan'), findsOneWidget);
  });

  testWidgets('submit tanpa pilih apa-apa → validasi kategori dulu', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    final tombol = find.text('KIRIM UNTUK APPROVAL');
    await _scrollKe(tester, tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Pilih kategori dulu.'), findsOneWidget);
  });

  testWidgets('pilih kategori → daftar alat kefilter sesuai kategori', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panjang').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih alat'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Jangka Sorong Mitutoyo'), findsWidgets);
    expect(find.textContaining('Timbangan Digital Ohaus'), findsNothing);
  });

  testWidgets('isi form lengkap → kirim approval sukses & layar ketutup', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiFormLengkap(tester);
    final tombol = find.text('KIRIM UNTUK APPROVAL');
    await _scrollKe(tester, tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Sesi kalibrasi dikirim untuk approval.'), findsOneWidget);
    expect(find.byType(CalibrationInputScreen), findsNothing);
  });

  testWidgets('submit gagal di server → pesan error, layar tetap kebuka', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app(submitGagal: true));
    await tester.pumpAndSettle();
    await _bukaLayar(tester);

    await _isiFormLengkap(tester);
    final tombol = find.text('SIMPAN DRAFT');
    await _scrollKe(tester, tombol);
    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
    expect(find.byType(CalibrationInputScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// **Lembar Timbangan beneran KEGAMBAR** — bukan cuma payloadnya benar.
///
/// `timbangan_lembar_test.dart` menguji bentuk & payloadnya tanpa merender
/// apa pun. Yang itu nggak bisa menangkap kelas kegagalan yang paling
/// gampang lolos di lembar ini: **kotak yang nggak pernah digambar.**
///
/// Blok Accuracy punya kotak `Nominal keping` yang duduk di `kolom_baris` —
/// mekanisme yang sebelumnya cuma dipakai `no_probe` Thermocouple, dan
/// penggambarnya di-hardcode ke kode itu. Kalau kotak nominalnya nggak
/// kegambar, `titik_ukur` tiap titik jadi NOL di server (dia jumlah nominal),
/// seluruh koreksinya nggak berarti, dan nggak ada satu pun error: tabelnya
/// penuh, tombol kirimnya jalan.
void main() {
  /// Viewport raksasa supaya SELURUH lembar ke-build sekaligus — `ListView`
  /// cuma nge-build yang dekat layar, dan kotak yang belum ke-build kelihatan
  /// sama persis dengan kotak yang memang nggak digambar.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 24000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app() => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      worksheetScanServiceProvider.overrideWithValue(
        MockWorksheetScanService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'timbangan'),
    ),
  );

  Future<void> buka(WidgetTester tester) async {
    await tester.pumpWidget(app());
    // `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer
    // kayak gitu nggak ngejadwalin frame — `pumpAndSettle` doang nggak cukup.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> bukaSemuaHalaman(WidgetTester tester) async {
    await buka(tester);

    final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('tujuh bloknya kegambar, bukan lembar pH', (tester) async {
    perbesarViewport(tester);
    await bukaSemuaHalaman(tester);

    // Judulnya duluan: tanpa jangkar ini, `findsOneWidget` di bawah bisa hijau
    // gara-gara mock jatuh ke cabang `_` dan memajang lembar pH.
    expect(find.text('KALIBRASI MASSA / TIMBANGAN'), findsOneWidget);

    for (final judul in [
      '1. SCALE OBSERVATION',
      '2. EFFECT OF TARE',
      '3. ACCURACY',
      '4. REPEATABILITY',
      '5. LOADING INFLUENCE ON EACH POSITION',
      '6. HYSTERISIS',
    ]) {
      expect(find.text(judul), findsOneWidget, reason: 'Blok `$judul` hilang.');
    }
  });

  testWidgets('kotak Nominal keping kegambar sepuluh kali — satu per titik', (
    tester,
  ) async {
    perbesarViewport(tester);
    await bukaSemuaHalaman(tester);

    expect(
      find.text('Nominal keping (pisahkan dengan +) — kg'),
      findsOneWidget,
      reason:
          'Judul kotak tambahan per baris nggak kegambar. Tanpa kotaknya, '
          '`titik_ukur` tiap titik jadi nol di server — dia jumlah nominal.',
    );

    // Sepuluh kotak, satu per baris tangga 10 %–100 %.
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '20+20+10',
      ),
      findsNWidgets(10),
    );
  });

  testWidgets('dua tabelnya kegambar dengan kepala kolom masing-masing', (
    tester,
  ) async {
    perbesarViewport(tester);
    await bukaSemuaHalaman(tester);

    // Accuracy: empat pembacaan yang artinya BEDA-BEDA, dan kertasnya nulis
    // `z / m / m' / z'` — bukan "Pengulangan 1..4".
    for (final kepala in ['z', 'm', "m'", "z'"]) {
      expect(
        find.text(kepala),
        findsWidgets,
        reason: 'Kepala kolom `$kepala` blok Accuracy hilang.',
      );
    }

    // Repeatability: dua sub-kolom per pengulangan.
    expect(find.text('Zero (zi)'), findsWidgets);
    expect(find.text('Reading (mi)'), findsWidgets);

    // Dua barisnya kapasitas, bukan titik ukur.
    expect(find.text('Middle Capacity'), findsWidgets);
    expect(find.text('Maximum Capacity'), findsWidgets);
  });

  testWidgets('nggak ada tombol kamera di lembar ini', (tester) async {
    perbesarViewport(tester);
    await bukaSemuaHalaman(tester);

    // `bentukPindaiFoto()` mengunci dua-duanya `false`, dan alasannya bukan
    // kelupaan: lab belum pernah menerbitkan kertas lembar ini
    // (`kode_dokumen` null), tabel Repeatability nggak mengirim kepala kolom
    // yang bisa dijangkar pemeta (bawaannya `X1` / `Repeat 1`), dan blok
    // Accuracy di kertas master itu daftar MENURUN, bukan grid. Tombol yang
    // nyala di lembar begini balik NOL sel tiap jepretan — dan yang sampai ke
    // teknisi "tabelnya dikenali, tapi selnya masih kosong".
    expect(find.text('FOTO TABEL INI'), findsNothing);
    expect(find.text('PINDAI LEMBAR KERJA'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/config/app_config.dart';
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

/// **UI pindai dimatiin = tombolnya beneran nggak digambar.**
///
/// ## Kenapa berkas ini ada
///
/// Enam belas berkas test masih nyebut pindai, tapi sepuluh di antaranya
/// nguji LAYANANNYA langsung (`pindai_lembar`, `peta_tabel_foto`,
/// `jalankan_pindai`) — nggak satu pun lewat layar. Artinya `flutter test`
/// hijau bukan bukti tombolnya hilang: kalau `if (pindaiAktif)`-nya kelewat di
/// salah satu dari dua titik render, semua tetap hijau dan teknisi tetap
/// nemu tombol yang nggak boleh dipakai.
///
/// Yang dijaga di sini justru KETIADAANNYA, dari layar aslinya, di kedua
/// titik render sekaligus:
///
///  - `PINDAI LEMBAR KERJA` — sekali di atas tabel, dari `_Bagian`;
///  - `FOTO TABEL INI` — sekali di ATAS SETIAP tabel, dari `LembarKerjaTabel`.
///
/// Test kedua nyalain saklarnya lagi. Tanpa itu, test pertama bisa hijau cuma
/// gara-gara lembarnya gagal kebangun — dan "nggak ada tombol" di layar
/// kosong itu bukan bukti apa-apa.
void main() {
  /// Viewport dibikin raksasa biar SELURUH lembar ke-build sekaligus.
  ///
  /// Ini bukan kosmetik: `ListView` cuma nge-build yang deket layar, dan
  /// tombol yang belum ke-build kelihatannya sama persis kayak tombol yang
  /// emang nggak digambar — `findsNothing`-nya bakal hijau bohongan.
  /// Lebarnya sengaja di bawah ambang dua kolom (1100): ini mode halaman,
  /// yang dipakai teknisi di HP.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app({required bool pindaiAktif}) => ProviderScope(
    overrides: [
      // Waktu mati, providernya sengaja NGGAK di-override sama sekali: yang
      // diuji test pertama itu nilai BAWAANNYA, jadi dia harus lewat jalur
      // yang sama persis dengan produksi (`AppConfig.pindaiLembarAktif`).
      // `overrideWithValue(false)` cuma bakal nguji override-nya sendiri.
      if (pindaiAktif) pindaiLembarAktifProvider.overrideWithValue(true),
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
      // Bawaannya `siap_pindai: false` — sama kayak server sekarang. Sengaja:
      // biar kelihatan bedanya "tombolnya MATI" (lembar belum siap dipindai)
      // sama "tombolnya NGGAK ADA" (saklar UI-nya mati).
      worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'ph_meter'),
    ),
  );

  /// Buka layar sampai halaman yang ada tabelnya.
  ///
  /// `pumpAndSettle` doang nggak cukup: `MockAuthService.me()` jeda 600 ms
  /// lewat `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame.
  ///
  /// Loop `LANJUT KE HALAMAN BERIKUTNYA`-nya jaring pengaman: bentuk pH mock
  /// sekarang satu halaman, tapi lembar aslinya dua — dan tombol yang diuji
  /// ada di halaman yang ada tabelnya.
  Future<void> bukaSampaiTabel(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('saklar bawaan: dua tombol pindainya nggak digambar sama sekali',
      (tester) async {
    // Bawaannya MATI, dan itu bagian dari yang dijaga: begitu ada yang
    // ngubah `defaultValue`-nya jadi true, yang jebol duluan baris ini —
    // bukan teknisi yang tiba-tiba nemu tombol lagi di lapangan.
    expect(
      AppConfig.pindaiLembarAktif,
      isFalse,
      reason: 'UI pindai cuma boleh nyala lewat --dart-define=PINDAI_LEMBAR',
    );

    perbesarViewport(tester);
    await bukaSampaiTabel(tester, app(pindaiAktif: false));

    // Lembarnya beneran kebangun — tanpa jangkar ini, dua `findsNothing` di
    // bawah bisa hijau gara-gara layarnya kosong/gagal muat.
    expect(find.text('Before adjustment Reading'), findsOneWidget);
    expect(find.text('After adjustment Reading'), findsOneWidget);

    expect(
      find.text('PINDAI LEMBAR KERJA'),
      findsNothing,
      reason: 'tombol pindai lembar penuh masih kegambar di `_Bagian`',
    );
    expect(
      find.text('FOTO TABEL INI'),
      findsNothing,
      reason: 'tombol foto per tabel masih kegambar di `LembarKerjaTabel`',
    );
  });

  testWidgets('saklar nyala: dua-duanya balik lagi', (tester) async {
    perbesarViewport(tester);
    await bukaSampaiTabel(tester, app(pindaiAktif: true));

    expect(find.text('PINDAI LEMBAR KERJA'), findsWidgets);

    // Satu per TABEL, bukan satu per lembar — pH punya Before & After.
    expect(find.text('FOTO TABEL INI'), findsNWidgets(2));
  });
}

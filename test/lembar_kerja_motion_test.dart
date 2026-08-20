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
import 'package:sidik_calibration/widgets/tampil_masuk.dart';

/// Kartu bagian lembar kerja yang punya TABEL sengaja nggak dianimasikan.
///
/// Bukan kelewat. `Opacity` memaksa Flutter merender subtree-nya ke lapisan
/// terpisah selama animasi berjalan, dan tabel hasil di layar ini rutin berisi
/// 60 kotak angka. Menganimasikan lapisan sebesar itu bikin lembar kerja
/// terasa LEBIH LAMBAT dibuka — kebalikan dari alasan animasinya ditambahkan.
///
/// Aturan itu nggak kelihatan dari kodenya dan gampang "dirapikan" orang yang
/// mengira ada bagian yang kelewat dibungkus. Salahnya juga nggak muncul
/// sebagai error — cuma layar terberat di app yang jadi tersendat waktu dibuka.
void main() {
  Widget app(String profil) => ProviderScope(
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
      worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );

  /// Berapa bagian yang MESTINYA dianimasikan, dihitung dari bentuk lembarnya
  /// sendiri — bukan angka mati yang ikut basi tiap bentuk mock berubah.
  Future<int> bagianTanpaTabel(String profil) async {
    final bentuk = await MockLembarKerjaService().ambilBentuk(
      'mock-token-1',
      profil: profil,
    );

    return bentuk.bagian.where((b) => b.tabel.isEmpty).length;
  }

  Future<void> buka(WidgetTester tester, String profil) async {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(profil));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('pH Meter: cuma bagian tanpa tabel yang dianimasikan', (
    tester,
  ) async {
    await buka(tester, 'ph_meter');

    expect(
      find.byType(TampilMasuk),
      findsNWidgets(await bagianTanpaTabel('ph_meter')),
    );
  });

  /// Viscometer punya DUA tabel di satu bagian — lembar terberat yang app ini
  /// punya, dan justru yang paling nggak boleh ikut dianimasikan.
  testWidgets('Viscometer: bagian bertabel tetap muncul langsung', (
    tester,
  ) async {
    await buka(tester, 'viscometer');

    final diharapkan = await bagianTanpaTabel('viscometer');

    expect(find.byType(TampilMasuk), findsNWidgets(diharapkan));
    // Penjaga arah: kalau SEMUA bagian ikut dibungkus, angka di atas bakal
    // sama dengan jumlah bagian seluruhnya dan testnya lolos tanpa arti.
    final bentuk = await MockLembarKerjaService().ambilBentuk(
      'mock-token-1',
      profil: 'viscometer',
    );
    expect(
      diharapkan,
      lessThan(bentuk.bagian.length),
      reason: 'lembar Viscometer wajib punya bagian bertabel',
    );
  });
}

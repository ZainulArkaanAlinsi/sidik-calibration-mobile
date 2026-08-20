import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar lembar kerja DO Meter (alat ke-9) beneran kerender — bukan cuma
/// bentuk datanya yang benar.
///
/// DO Meter sengaja NGGAK punya layar sendiri kayak Autoklaf: bentuk lembarnya
/// sama keluarga sama Chlorin Meter (satu titik, Before/After adjustment, tiap
/// sel `mg/L` + `°C`), jadi dia lewat `LembarKerjaScreen` generik. Test ini
/// yang mastiin keputusan itu beneran jalan di layar, bukan cuma di atas kertas.
void main() {
  Widget app(String profil) {
    return ProviderScope(
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
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LembarKerjaScreen(profil: profil),
      ),
    );
  }

  testWidgets('lembar DO Meter kerender dengan titik & satuan yang benar',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app('do_meter'));
    // Layar generik punya debounce autosimpan; ditunggu supaya timernya
    // kebakar di dalam test, bukan nyisa waktu widget tree-nya dibuang.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Judul lembarnya, bukan lembar pH yang jadi cabang bawaan.
    expect(find.textContaining('DO Meter'), findsWidgets);
    expect(find.textContaining('pH Meter'), findsNothing);

    // Dua tahap adjustment, ikut kertasnya.
    // `findsWidgets`, bukan `findsOneWidget`: judul tahapnya muncul di lebih
    // dari satu tempat (judul blok + kepala tabel), dan jumlah persisnya urusan
    // tata letak — yang dijaga di sini KEDUA tahap kegambar, bukan berapa kali.
    expect(find.textContaining('Before adjustment'), findsWidgets);
    expect(find.textContaining('After adjustment'), findsWidgets);

    // Titik 8,77 — bukan 0,00 yang tercetak di kertas Rev.2, dan bukan
    // 4,00/7,00/10,01 punya lembar pH.
    expect(find.textContaining('8,77'), findsWidgets);
    expect(find.textContaining('10,01'), findsNothing);

    // Kuras timer debounce yang masih antre sebelum tree-nya dibuang.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}

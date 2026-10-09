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

/// Kotak tekanan udara Hydrometer benar-benar TERGAMBAR di layar.
///
/// Layar melewati `tekanan_awal`/`tekanan_akhir` di daftar field biasa dan
/// cuma menggambarnya sebagai kolom ketiga tabel Environment Condition — tabel
/// yang hanya lahir kalau suhu & RH awal/akhir ada di bagian yang SAMA.
/// Revisi "ikut kertas" (9 Okt 2026) sempat memindah tekanan ke blok "Di luar
/// kertas": fixture-nya masih memuat kodenya, test model tetap hijau, tapi
/// kotaknya hilang dari layar dan server menahan seluruh hitungan Hydrometer
/// (tekanan kosong). Test ini memeriksa yang digambar, bukan isi bentuknya.
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

  testWidgets('hydrometer: kolom tekanan (hPa) tergambar di tabel lingkungan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 30000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app('hydrometer'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Kepala kolom ketiga tabel Environment Condition. Bukan `hPa`: teks itu
    // juga ada di catatan pengisian, jadi tetap ketemu walau kotaknya hilang.
    expect(find.text('Pressure'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}

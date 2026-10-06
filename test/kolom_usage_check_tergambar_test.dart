import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Kolom di kotak Standard Used (`usage_check`) wajib tergambar.
///
/// Audit 6 Okt 2026: layar cuma menggambar daftar centangnya. Kolom yang
/// menumpang di bagian itu — `gaya.standar`, `tekanan.varian`, `tipe_sensor`
/// TIDS, `piston.timbangan`, `sieve.standar_dipakai` — tidak pernah muncul,
/// jadi tidak bisa diisi, dan server menahan seluruh titik sesinya.
void main() {
  Widget app(String profil) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(MockEquipmentLookupService()),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );

  // Label persis dari bentuk lembar server (fixture hasil generator).
  const kasus = <String, String>{
    'utm': 'Kapasitas Standar (kN)',
    'load_cell': 'Kapasitas Standar (kN)',
    'proving_ring': 'Kapasitas Standar (kN)',
    'pressure_gauge': 'Kalibrator (master olah data)',
    'vacuum_gauge': 'Kalibrator (master olah data)',
    'tids': 'Sensor Standard',
  };

  // Dropdown yang menanyakan ulang baris yang sudah dicentang di Standard
  // Used — dicabut server 6 Okt 2026, standarnya lahir dari centang. Kalau
  // muncul lagi, teknisi mengisi hal yang sama dua kali.
  const dobel = <String, String>{
    'utm': 'Load Cell Standar',
    'load_cell': 'Load Cell Standar',
    'piston_pipette': 'Timbangan',
    'tids': 'Sensor Standard (lama)',
  };

  for (final e in dobel.entries) {
    testWidgets('${e.key}: dropdown dobel "${e.value}" tidak ada', (tester) async {
      tester.view.physicalSize = const Size(1000, 30000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(e.key));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text(e.value), findsNothing);
    });
  }

  for (final e in kasus.entries) {
    testWidgets('${e.key}: kolom "${e.value}" di Standard Used tergambar', (tester) async {
      tester.view.physicalSize = const Size(1000, 30000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(e.key));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        find.text(e.value),
        findsWidgets,
        reason: 'kolom ${e.value} di bagian Standard Used tidak muncul',
      );
    });
  }
}

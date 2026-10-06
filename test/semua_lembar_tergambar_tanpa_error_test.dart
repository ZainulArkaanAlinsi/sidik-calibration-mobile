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

/// SETIAP lembar kerja tergambar utuh tanpa error.
///
/// Audit 6 Okt 2026: lembar UTM, Load Cell, dan Proving Ring melempar
/// `Null check operator used on a null value` waktu menggambar tabel Preload
/// Test. Di HP rilis, error itu tidak memunculkan pesan — tabelnya cuma
/// diganti kotak abu-abu. Tidak ada test yang menggambar ketiga lembar itu,
/// jadi tidak ada yang tahu.
///
/// Daftarnya ditulis tangan, sama alasannya dengan
/// `kepala_tabel_tidak_kepotong_test.dart`: alat baru yang lupa ditambahkan ke
/// sini kelihatan sebagai lembar yang belum terjaga.
void main() {
  const semuaProfil = [
    'ph_meter', 'turbidimeter', 'chlorine_meter', 'conductivity_meter',
    'refractometer', 'spectrophotometer', 'viscometer', 'do_meter',
    'gas_detector', 'tits', 'tids', 'thermocouple', 'thermometer_glass',
    'thermohygro', 'oven', 'furnace', 'bath', 'inkubator', 'refrigerator',
    'autoclave', 'timbangan', 'anak_timbangan', 'timer_stopwatch',
    'centrifuge', 'tachometer', 'micrometer', 'height_gauge', 'dial_indicator',
    'jangka_sorong', 'sieve', 'hydrometer', 'flowmeter_totalizer',
    'flowmeter_flowrate', 'labu_ukur', 'pipet_volume', 'picnometer', 'buret',
    'gelas_ukur', 'pipet_ukur', 'utm', 'load_cell', 'proving_ring',
    'pressure_gauge', 'vacuum_gauge', 'differential_pressure',
    'piston_pipette', 'dispensett', 'buret_digital',
  ];

  for (final profil in semuaProfil) {
    testWidgets('$profil: lembar tergambar tanpa error', (tester) async {
      tester.view.physicalSize = const Size(1000, 30000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
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
      ));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  }
}

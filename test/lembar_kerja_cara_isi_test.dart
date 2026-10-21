import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
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

/// Pintu "Isi manual | Foto lembar kerja" (K-50-11) di lembar BARU. Hanya
/// muncul untuk formulir yang boleh dipindai (siap_pindai atau mode uji).
void main() {
  WorksheetTemplate asli({Map<String, dynamic> ubah = const {}}) {
    final data =
        (jsonDecode(
              File(
                'test/assets/template-asli-ph_meter-0509.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>);

    return WorksheetTemplate.fromJson({
      'data': {...(data['data'] as Map<String, dynamic>), ...ubah},
    });
  }

  Widget app(WorksheetTemplate? formulir) => ProviderScope(
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
        MockWorksheetScanService(formulirAsli: formulir),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(),
    ),
  );

  Future<void> muat(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('formulir siap/mode uji: lembar baru menawarkan dua cara', (
    tester,
  ) async {
    await muat(tester, app(asli()));

    expect(find.byKey(const ValueKey('cara-manual')), findsOneWidget);
    expect(find.byKey(const ValueKey('cara-foto')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cara-manual')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    // Tombol kamera tetap ada untuk ganti pikiran.
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsOneWidget);
  });

  testWidgets('foto tanpa alat dipilih: diminta pilih alat dulu', (
    tester,
  ) async {
    await muat(tester, app(asli()));

    await tester.tap(find.byKey(const ValueKey('cara-foto')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih alatnya dulu'), findsOneWidget);
  });

  testWidgets('formulir belum siap (bukan mode uji) atau tak dipetakan: '
      'tidak ada pintu foto', (tester) async {
    await muat(tester, app(asli(ubah: {'mode_uji': false})));
    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsNothing);

    await muat(tester, app(null));
    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsNothing);
  });
}

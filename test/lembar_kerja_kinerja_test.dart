import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/kinerja_lembar.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Lag lembar kerja: mengetik di kotak keping/kolom-baris tidak boleh
/// membangun ulang SELURUH formulir tiap ketukan (dulu `setState` penuh).
void main() {
  Widget app(ProviderContainer? c) => UncontrolledProviderScope(
    container: c!,
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'timbangan'),
    ),
  );

  ProviderContainer wadah() {
    final c = ProviderContainer(
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
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('mengetik 10 kali di kotak keping: nol pembangunan ulang form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 24000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = wadah();
    await tester.pumpWidget(app(c));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final lanjut = find.text('Lanjut ke halaman berikutnya');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }

    final kotak = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Pisahkan tiap keping dengan +',
    );
    expect(kotak, findsWidgets);

    KinerjaLembar.nolkan();
    for (var i = 0; i < 10; i++) {
      await tester.enterText(kotak.first, '${20 + i}+10');
      await tester.pump();
    }

    expect(
      KinerjaLembar.bangunForm,
      0,
      reason: 'Tiap ketukan dulu memanggil setState di seluruh formulir.',
    );
    // Lembar ditandai kotor: tarikan ulang realtime/resume ditunda.
    expect(c.read(lembarKotorProvider), 1);

    // Tutup lembar → hitungan turun lagi (jangan bocor ke lembar berikutnya).
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.read(lembarKotorProvider), 0);
    await tester.pump(const Duration(seconds: 2));
  });
}

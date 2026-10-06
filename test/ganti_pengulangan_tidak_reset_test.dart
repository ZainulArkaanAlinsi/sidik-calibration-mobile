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

/// Mengganti jumlah pengulangan TIDAK menghapus isian yang sudah diketik.
///
/// Laporan lapangan 6 Okt 2026: "cuma ngubah pengulangan malah ke-reset".
/// Formulirnya dipasang dengan `key: ValueKey(jumlahPengulangan)`, jadi tiap
/// ganti jumlah kotak membuat State baru dan seluruh lembar kembali kosong.
void main() {
  Widget app() => ProviderScope(
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
    child: const MaterialApp(
      locale: Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: 'ph_meter'),
    ),
  );

  Future<void> tunggu(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('ganti 5x → 6x: isian identitas DAN angka tabel tetap ada', (tester) async {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tunggu(tester);

    // Kotak yang bisa diketik: pertama (identitas) dan terakhir (tabel hasil).
    final bisaDiketik = find.byWidgetPredicate(
      (w) => w is TextField && w.enabled != false && !w.readOnly,
    );
    expect(bisaDiketik, findsWidgets);

    await tester.enterText(bisaDiketik.first, 'Merk Uji');
    await tester.enterText(bisaDiketik.last, '7,01');
    await tester.pump();

    // Ganti jumlah pengulangan lewat menu di AppBar.
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is PopupMenuItem<int> && w.value == 6).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Ubah'));
    await tunggu(tester);

    expect(find.text('Merk Uji'), findsOneWidget,
        reason: 'isian identitas hilang waktu jumlah pengulangan diganti');
    expect(find.text('7,01'), findsOneWidget,
        reason: 'angka tabel hilang waktu jumlah pengulangan diganti');
  });
}

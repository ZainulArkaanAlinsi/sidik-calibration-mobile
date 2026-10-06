import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

import 'support/halaman_lembar.dart';

/// TITS: tabel Before Adjustment DILIPAT secara bawaan (keputusan pemilik
/// 6 Okt 2026) — kertas 0505 cuma satu tabel, dan Before tidak dihitung
/// maupun dicetak. Dilipat, bukan dihapus: bisa dibuka, isinya tetap ada.
void main() {
  test('penanda terlipat terbaca dari bentuk lembar', () {
    final bentuk = LembarKerja.fromJson(contohBentukLembarKerjaTits());
    final tabel = bentuk.bagian.expand((b) => b.tabel).toList();

    expect(tabel.firstWhere((t) => t.sebelumAdjustment).terlipat, isTrue);
    expect(tabel.firstWhere((t) => !t.sebelumAdjustment).terlipat, isFalse);
  });

  testWidgets('Before dilipat, After terbuka, pemilih standar tetap kelihatan', (tester) async {
    tester.view.physicalSize = const Size(1000, 20000);
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
      child: const MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LembarKerjaScreen(profil: 'tits'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await keHalamanAkhir(tester);

    // Before terlipat: judulnya ada di kepala lipatan, tabelnya belum digambar.
    expect(find.byKey(const ValueKey('lipat-Before Adjustment Reading')), findsOneWidget);
    final tabelTergambar = tester
        .widgetList<LembarKerjaTabel>(find.byType(LembarKerjaTabel))
        .map((w) => w.tabel.tahap)
        .toList();
    expect(tabelTergambar, ['sesudah_adjustment']);

    // Pemilih standar pindah ke tabel After — tidak ikut terlipat.
    final after = tester.widget<LembarKerjaTabel>(find.byType(LembarKerjaTabel));
    expect(after.tampilkanPemilihStandar, isTrue);

    // Dibuka: tabel Before muncul, tanpa pemilih standar kedua.
    await tester.tap(find.byKey(const ValueKey('lipat-Before Adjustment Reading')));
    await tester.pumpAndSettle();
    final semua = tester.widgetList<LembarKerjaTabel>(find.byType(LembarKerjaTabel)).toList();
    expect(semua.map((w) => w.tabel.tahap), containsAll(['sebelum_adjustment', 'sesudah_adjustment']));
    expect(
      semua.firstWhere((w) => w.tabel.sebelumAdjustment).tampilkanPemilihStandar,
      isFalse,
    );
  });
}

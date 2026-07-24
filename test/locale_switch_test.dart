import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/locale_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Nguji dwibahasa layar NON-auth (dashboard/navbar). Toggle bahasa di layar
/// auth belum diuji: auth neumorphism (PR #16) belum dwibahasa — lihat catatan
/// di bawah.
void main() {
  // Tanpa ini, `SharedPreferences.getInstance()` di localeProvider NYANGKUT
  // (channel plugin nggak dijawab di test) — dan `await setLocale(...)` di test
  // ikut nyangkut sampai timeout 10 menit. Mock-nya bikin resolve seketika.
  setUp(() => SharedPreferences.setMockInitialValues({}));


  // CATATAN (2026-07-24): tes toggle bahasa DI LAYAR AUTH dihapus sementara.
  // Auth neumorphism (di-merge dari PR #16) belum dwibahasa — teksnya di-hardcode
  // Indonesia ('MASUK', dst) dan belum ada toggle bahasa in-screen. Keputusan:
  // ship auth ID-only dulu, i18n auth = utang teknis yang dipasang ulang nanti
  // bareng Arkaan (layarnya dia). Tes dwibahasa layar NON-auth di bawah tetap
  // jalan & membuktikan mekanisme locale-switch app-wide masih benar.
  testWidgets('ganti ke EN → layar non-auth (dashboard + navbar) ikut EN', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          dashboardServiceProvider.overrideWithValue(
            MockDashboardService(jeda: Duration.zero),
          ),
        ],
        child: const SidikApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Default ID.
    expect(find.text('Alat'), findsWidgets, reason: 'label navbar ID');
    expect(find.text('Halo,'), findsOneWidget, reason: 'sapaan dashboard ID');

    // Switcher bahasa belum ada di shell (baru di layar auth), jadi set locale
    // app-wide lewat provider — buktiin terjemahan non-auth beneran kepasang.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(localeProvider.notifier).setLocale(const Locale('en'));
    // Pump terbatas, BUKAN pumpAndSettle: ganti locale bikin delegate lokalisasi
    // di-reload, dan di suite penuh pumpAndSettle-nya bisa nyangkut nungguin
    // frame yang kejadwal terus. Beberapa pump cukup buat naikin teks EN.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Equipment'), findsWidgets, reason: 'label navbar EN');
    expect(find.text('Alat'), findsNothing);
    expect(find.text('Hello,'), findsOneWidget, reason: 'sapaan dashboard EN');
  });
}

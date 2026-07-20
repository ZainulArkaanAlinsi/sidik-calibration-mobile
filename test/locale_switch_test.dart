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

/// Nguji dwibahasa: default ID, dan toggle bener-bener ganti teks ke EN.
void main() {
  // Tanpa ini, `SharedPreferences.getInstance()` di localeProvider NYANGKUT
  // (channel plugin nggak dijawab di test) — dan `await setLocale(...)` di test
  // ikut nyangkut sampai timeout 10 menit. Mock-nya bikin resolve seketika.
  setUp(() => SharedPreferences.setMockInitialValues({}));


  testWidgets('toggle bahasa: default ID → tap → semua teks auth jadi EN', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(MockAuthService()),
          dashboardServiceProvider.overrideWithValue(
            MockDashboardService(jeda: Duration.zero),
          ),
        ],
        child: const SidikApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Default = Indonesia.
    expect(find.text('MASUK'), findsOneWidget);
    expect(find.text('Belum punya akun?'), findsOneWidget);
    expect(
      find.text('Indonesia'),
      findsOneWidget,
      reason: 'toggle nampilin bahasa aktif',
    );

    // Ganti bahasa.
    await tester.tap(find.text('Indonesia'));
    await tester.pumpAndSettle();

    // Sekarang Inggris — teks auth ikut ganti.
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('MASUK'), findsNothing);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

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

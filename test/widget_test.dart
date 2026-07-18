import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/providers/app_config_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// App dalam kondisi udah login (token admin) — soalnya sekarang app mendarat
/// di layar Login dulu kalau nggak ada token tersimpan. Alur login-nya sendiri
/// diuji terpisah di `auth_test.dart`.
Widget _appLoggedIn({String? apiBaseUrl}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    dashboardServiceProvider.overrideWithValue(
      MockDashboardService(jeda: Duration.zero),
    ),
    if (apiBaseUrl != null) apiBaseUrlProvider.overrideWithValue(apiBaseUrl),
  ],
  child: const SidikApp(),
);

void main() {
  group('bottom navigation', () {
    testWidgets('nampilin 5 tab dan mulai dari Dashboard', (tester) async {
      await tester.pumpWidget(_appLoggedIn());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingNavBar), findsOneWidget);
      for (final label in [
        'Dashboard',
        'Alat',
        'Riwayat',
        'Notifikasi',
        'Profil',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'tab $label harus ada');
      }

      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    });

    testWidgets('pindah tab beneran ganti layar', (tester) async {
      await tester.pumpWidget(_appLoggedIn());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alat'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Alat'), findsOneWidget);
      // Search bar-nya selalu kerender lepas dari state async list alat
      // (loading/error/data) — nggak kayak "Daftar Alat" placeholder lama.
      expect(find.text('Cari nama alat'), findsOneWidget);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      // Profil nggak punya judul AppBar (header foto full-bleed sampai tepi
      // layar) — cek gantinya lewat widget layarnya.
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  testWidgets('tab Profil nampilin API base URL dari provider', (tester) async {
    await tester.pumpWidget(
      _appLoggedIn(apiBaseUrl: 'http://localhost:9000/api'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    // Item ini ada di bawah ListView Profil — di-scroll dulu biar ke-build,
    // soalnya bottom-nav mengambang bikin viewport lebih pendek.
    final url = find.text('http://localhost:9000/api');
    await tester.scrollUntilVisible(
      url,
      120,
      scrollable: find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scrollable),
      ),
    );

    expect(url, findsOneWidget);
  });

  test('AppConfig default ke environment dev', () {
    expect(AppConfig.env, AppEnv.dev);
    expect(AppConfig.envLabel, 'DEV');
    expect(AppConfig.isProd, isFalse);
  });
}

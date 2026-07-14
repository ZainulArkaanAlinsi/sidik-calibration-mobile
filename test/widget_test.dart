import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/core/config/app_config.dart';
import 'package:asmo_mobile/providers/app_config_provider.dart';

void main() {
  group('bottom navigation', () {
    testWidgets('nampilin 5 tab dan mulai dari Dashboard', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: AsmoApp()));

      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in [
        'Dashboard',
        'Alat',
        'Riwayat',
        'Notifikasi',
        'Profil',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'tab $label harus ada');
      }

      // Tab awal = Dashboard, jadi AppBar-nya Dashboard yang kelihatan.
      expect(
        find.widgetWithText(AppBar, 'Dashboard'),
        findsOneWidget,
      );
    });

    testWidgets('pindah tab beneran ganti layar', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: AsmoApp()));

      await tester.tap(find.text('Alat'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Alat'), findsOneWidget);
      expect(find.text('Daftar Alat'), findsOneWidget);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    });
  });

  testWidgets('tab Profil nampilin API base URL dari provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiBaseUrlProvider.overrideWithValue('http://localhost:9000/api'),
        ],
        child: const AsmoApp(),
      ),
    );

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('http://localhost:9000/api'), findsOneWidget);
  });

  test('AppConfig default ke environment dev', () {
    expect(AppConfig.env, AppEnv.dev);
    expect(AppConfig.envLabel, 'DEV');
    expect(AppConfig.isProd, isFalse);
  });
}

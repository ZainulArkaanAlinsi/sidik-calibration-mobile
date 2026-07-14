@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/core/theme/app_theme.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/screens/auth/login_screen.dart';
import 'package:asmo_mobile/screens/auth/register_screen.dart';
import 'package:asmo_mobile/screens/shell/main_shell.dart';
import 'package:asmo_mobile/services/dashboard_service.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';

/// Bikin screenshot layar-layar utama ke `test/screenshots/*.png`.
///
/// Jalanin: `flutter test test/screenshot_test.dart --update-goldens`
///
/// Gunanya: lihat tampilan app **tanpa perlu emulator/HP**. Kalau ragu
/// "desainnya udah kepasang belum?", buka PNG-nya.
Future<void> _muatFontInter() async {
  // Di widget test, font custom nggak ke-load otomatis — teks bakal kerender
  // jadi kotak-kotak hitam. Jadi Inter-nya dimuat manual dari disk.
  final loader = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    loader.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await loader.load();
}

Widget _bungkus(Widget layar, {required Brightness mode}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: mode == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: layar,
    ),
  );
}

void main() {
  setUpAll(_muatFontInter);

  /// Ukuran HP beneran (bukan 800x600 bawaan test), biar layoutnya wajar —
  /// dan biar overflow yang cuma muncul di lebar HP ketahuan di sini.
  void pasangUkuranHp(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('login — terang', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const LoginScreen(), mode: Brightness.light),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-terang.png'),
    );
  });

  testWidgets('login — gelap', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const LoginScreen(), mode: Brightness.dark),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-gelap.png'),
    );
  });

  testWidgets('register', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const RegisterScreen(), mode: Brightness.light),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RegisterScreen),
      matchesGoldenFile('screenshots/register.png'),
    );
  });

  testWidgets('dashboard', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const MainShell(), mode: Brightness.light),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('screenshots/dashboard.png'),
    );
  });
}

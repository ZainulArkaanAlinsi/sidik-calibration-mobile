@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/core/theme/app_theme.dart';
import 'package:asmo_mobile/l10n/app_localizations.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/screens/auth/login_screen.dart';
import 'package:asmo_mobile/screens/auth/register_screen.dart';
import 'package:asmo_mobile/screens/auth/splash_screen.dart';
import 'package:asmo_mobile/screens/auth/widgets/neu.dart';
import 'package:asmo_mobile/screens/profile/profile_screen.dart';
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
Future<void> _muatFont() async {
  // Di widget test, font custom nggak ke-load otomatis — teks bakal kerender
  // jadi kotak-kotak hitam. Jadi Inter-nya dimuat manual dari disk.
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();

  // Font ikon Material juga nggak ke-load sendiri — tanpa ini semua ikon
  // kerender jadi kotak kosong. Itu bikin screenshot-nya nyaris nggak ada
  // gunanya: separuh bahasa desain kita ikon, dan aturan "status nggak boleh
  // dibedain lewat warna doang" nggak bisa dicek kalau ikonnya kotak semua.
  //
  // Font-nya ikut SDK, bukan repo. Kalau nggak ketemu (versi Flutter beda),
  // screenshot-nya tetap kebikin — cuma ikonnya balik jadi kotak. Nggak worth
  // bikin test-nya merah cuma gara-gara ini.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;

  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;

  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await ikon.load();
}

/// Pump layar + precache logo + settle.
///
/// Logo PT Sidik = `Image.asset`. Di golden test, decode gambar jalan di async
/// queue yang di-pause, jadi kalau nggak di-precache manual di dalam `runAsync`
/// logonya kerender kosong. Precache dulu → `pumpAndSettle` → logo muncul.
Future<void> _pumpLayar(WidgetTester tester, Widget layar) async {
  await tester.pumpWidget(layar);
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(kLogoPtSidik),
      tester.element(find.byType(MaterialApp)),
    );
  });
  await tester.pumpAndSettle();
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
      // Locale dikunci ke ID biar golden deterministik (nggak ketarik locale
      // mesin CI/dev yang beda-beda).
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: layar,
    ),
  );
}

void main() {
  setUpAll(_muatFont);

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
    await _pumpLayar(tester, _bungkus(const LoginScreen(), mode: Brightness.light));

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-terang.png'),
    );
  });

  testWidgets('login — gelap', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(tester, _bungkus(const LoginScreen(), mode: Brightness.dark));

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('screenshots/login-gelap.png'),
    );
  });

  testWidgets('register', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const RegisterScreen(), mode: Brightness.light),
    );

    await expectLater(
      find.byType(RegisterScreen),
      matchesGoldenFile('screenshots/register.png'),
    );
  });

  testWidgets('dashboard', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(tester, _bungkus(const MainShell(), mode: Brightness.light));

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('screenshots/dashboard.png'),
    );
  });

  testWidgets('profil', (tester) async {
    pasangUkuranHp(tester);
    await _pumpLayar(
      tester,
      _bungkus(const ProfileScreen(), mode: Brightness.light),
    );

    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('screenshots/profil.png'),
    );
  });

  testWidgets('splash', (tester) async {
    pasangUkuranHp(tester);
    await tester.pumpWidget(
      _bungkus(const SplashScreen(), mode: Brightness.dark),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(kLogoPtSidik),
        tester.element(find.byType(MaterialApp)),
      );
    });
    // Bukan pumpAndSettle: splash punya spinner yang muter terus. Pump durasi
    // tetap biar frame golden-nya deterministik.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('screenshots/splash.png'),
    );
  });
}

@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/auth/register_screen.dart';
import 'package:sidik_calibration/screens/auth/splash_screen.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/screens/dashboard/ringkasan_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/shell/main_shell.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

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
/// Aset logo resmi (dulu diekspor `neu.dart`; kini auth memakai badge ikon
/// placeholder, jadi konstanta dipindah ke test yang masih mem-precache-nya).
const String kLogoPtSidik = 'assets/images/logo_pt_sidik.png';

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
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      perhitunganServiceProvider.overrideWithValue(MockPerhitunganService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
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

  /// Lembar kerja Chlorin Meter (`SIDIK-FM-CAL-0531_Rev.2`) — alat ke-3.
  ///
  /// Ada di sini bukan buat gaya-gayaan: bentuk lembarnya datang dari backend
  /// dan gampang "hijau di test tapi jelek di layar". PNG-nya bisa diadu sama
  /// PDF kertasnya tanpa perlu nyalain HP.
  testWidgets('lembar kerja chlorine', (tester) async {
    // Lebih tinggi dari HP beneran: lembarnya satu halaman & panjang, dan yang
    // mau dilihat justru bagian tabel hasilnya, bukan cuma kepala formulir.
    tester.view.physicalSize = const Size(1200, 7600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Bukan `_pumpLayar`: `MockAuthService.me()` jeda 600 ms lewat
    // `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame — jadi
    // `pumpAndSettle` balik duluan dan timernya nyangkut. Sama persis kayak
    // `_muat()` di `lembar_kerja_test.dart`.
    await tester.pumpWidget(
      _bungkus(
        const LembarKerjaScreen(profil: 'chlorine_meter'),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LembarKerjaScreen),
      matchesGoldenFile('screenshots/lembar-kerja-chlorine.png'),
    );
  });

  /// Lembar PERHITUNGAN — layar utama admin.
  ///
  /// Ada di sini karena ini layar yang paling lama dipelototin admin, dan
  /// paling gampang "hijau di test tapi kelihatan dari aplikasi lain": isinya
  /// campuran tabel, blok kondisi, dan bilah aksi yang tiap bagiannya ditulis
  /// terpisah. PNG-nya bikin ketidakkonsistenan langsung kelihatan.
  testWidgets('perhitungan admin', (tester) async {
    tester.view.physicalSize = const Size(1200, 5200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(
        const PerhitunganScreen(calibrationId: 1),
        mode: Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PerhitunganScreen),
      matchesGoldenFile('screenshots/perhitungan-admin.png'),
    );
  });

  /// Panel Ringkasan di lebar desktop.
  ///
  /// Ada di sini gara-gara satu bug yang cuma kelihatan di lebar segini: label
  /// "Sebaran status sesi" dikunci `SizedBox(width: 140)` TANPA jarak ke batang
  /// progresnya, jadi label yang lebih panjang dari itu ("Menunggu approval")
  /// nempel langsung ke bar dan kebaca kayak satu gumpalan. Nol test yang
  /// gagal, nol error — cuma kelihatan kalau dilihat.
  testWidgets('ringkasan desktop', (tester) async {
    tester.view.physicalSize = const Size(2400, 1700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _bungkus(const RingkasanScreen(), mode: Brightness.light),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RingkasanScreen),
      matchesGoldenFile('screenshots/ringkasan-desktop.png'),
    );
  });
}

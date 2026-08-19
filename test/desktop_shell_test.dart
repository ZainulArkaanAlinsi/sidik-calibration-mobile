import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/profile/profile_screen.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';
import 'support/lewati_onboarding.dart';

/// `mock-token-1` = admin · `mock-token-2` = teknisi · `mock-token-3` = viewer.
Widget _app({String token = 'mock-token-1', bool panelDesktop = true}) {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      // Ditimpa terang-terangan: nilai bawaannya nengok platform, dan di
      // bawah `flutter test` selalu false biar suite-nya nggak beda-beda
      // hasilnya antar mesin.
      pakaiPanelDesktopProvider.overrideWithValue(panelDesktop),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      notificationServiceProvider.overrideWithValue(
        MockNotificationService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
      izinServiceProvider.overrideWithValue(MockIzinService()),
    ],
    child: const SidikApp(),
  );
}

/// Jendela desktop beneran — panel ini emang buat layar selebar itu.
Future<void> _jendelaDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _sampaiPanel(
  WidgetTester tester, {
  String token = 'mock-token-1',
}) async {
  await tester.pumpWidget(_app(token: token));
  await tester.pumpAndSettle();
}

/// Tanpa font asli, `flutter test` ngukur teks pakai font fallback yang
/// metriknya beda jauh dari Inter — carousel profil HP yang pas-pasan di
/// tinggi kena overflow palsu gara-gara itu, bukan gara-gara layoutnya
/// beneran nggak muat di HP asli (lihat golden `profil.png` di 360x760 asli:
/// nggak overflow).
Future<void> _muatFont() async {
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();
}

void main() {
  setUpAll(_muatFont);

  testWidgets('desktop dapat panel admin, BUKAN rangka lima tab HP', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    // Sidebar bersekat, bukan navbar/rail yang isinya sama kayak HP.
    expect(find.text('Sidik Calibration'), findsOneWidget);
    expect(find.text('OPERASIONAL'), findsOneWidget);
    expect(find.text('DOKUMEN'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('HP tetap dapat rangka lima tab, bukan panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(panelDesktop: false));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingNavBar), findsOneWidget);
    expect(find.text('OPERASIONAL'), findsNothing);
  });

  testWidgets('halaman pembuka = Ringkasan, angkanya dari dashboard', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    expect(find.text('Ringkasan'), findsWidgets);
    // Judul kartu angka — sumbernya DashboardSummary yang sama kayak layar HP.
    expect(find.text('TOTAL ALAT'), findsOneWidget);
    expect(find.text('MENUNGGU APPROVAL'), findsOneWidget);
  });

  testWidgets('klik menu sidebar ganti isi area kerja', (tester) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    await tester.tap(find.text('Alat'));
    await tester.pumpAndSettle();

    // Ringkasan udah nggak dirender lagi — areanya diganti, bukan ditumpuk.
    expect(find.text('TOTAL ALAT'), findsNothing);
  });

  testWidgets('cari nyaring menu, seksi yang jadi kosong ikut ilang', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    await tester.enterText(find.byType(TextField).first, 'pelanggan');
    await tester.pumpAndSettle();

    expect(find.text('Pelanggan'), findsOneWidget);
    // Judul seksi tanpa isi cuma bikin daftarnya keliatan rusak.
    expect(find.text('OPERASIONAL'), findsNothing);
    expect(find.text('MASTER DATA'), findsOneWidget);
  });

  testWidgets('teknisi nggak dikasih seksi master data & sistem', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester, token: 'mock-token-2');

    // Operasional & dokumen tetap ada — teknisi tetap kerja di panel ini.
    expect(find.text('OPERASIONAL'), findsOneWidget);
    expect(find.text('DOKUMEN'), findsOneWidget);

    expect(find.text('MASTER DATA'), findsNothing);
    expect(find.text('SISTEM'), findsNothing);
  });

  testWidgets('"Tugas Saya" NGGAK ada di mana pun — /orders dibatalin', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester, token: 'mock-token-2');

    // Backend nutup branch Order Kalibrasi & penugasan teknisi permanen
    // (handoff 31 Jul §6) — `/orders` nol route. `MyTasksScreen` nembak
    // `GET /orders?teknisi_id=saya`, jadi menunya pasti 404.
    //
    // Test ini sengaja ngunci ABSENNYA: sebelumnya gw nambahin menu ini ke
    // sidebar karena audit paritas bilang timpang, dan itu bener PADA
    // WAKTUNYA — tapi jadi salah begitu fiturnya dibatalin. Tanpa test ini,
    // "paritas" gampang bikin orang masangnya balik.
    expect(find.text('Tugas Saya'), findsNothing);
  });

  testWidgets('Pengaturan di panel NGGAK ngulang isi sidebar', (tester) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    // Di panel, Profil dibuka lewat avatar inisial di bilah atas — bukan item
    // sidebar, dan bukan teks "Profil".
    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle();

    // Dipastiin layarnya beneran kebuka DULU. Tanpa ini, `findsNothing` di
    // bawah bisa lolos cuma gara-gara layarnya nggak pernah muncul — hijau
    // yang nggak ngebuktiin apa-apa.
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Digeser sejauh yang sama kayak test HP di bawah. Tanpa ini,
    // `findsNothing` bisa lolos cuma gara-gara bloknya kebetulan di bawah
    // lipatan layar dan belum dibangun `ListView` — hijau yang nggak
    // ngebuktiin bloknya beneran ilang.
    await tester.drag(find.byType(ProfileScreen), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Blok "Menu Admin" dulu nampilin Pelanggan/Standar/Organisasi/Tanda
    // Tangan — padahal keempatnya UDAH jadi item sidebar. Admin lihat tujuan
    // yang sama dua kali, dan Pengaturan jadi cuma salinan navigasi utama.
    expect(find.text('MENU ADMIN'), findsNothing);
  });

  testWidgets('di HP blok master data TETAP ada — nggak ada sidebar di sana', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(panelDesktop: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);

    // Di HP, profil itu carousel geser-samping (bukan `ListView` lagi):
    // adegan 0 = Akun, 1 = Preferensi, 2 = Menu Admin. Digeser dua kali biar
    // sampai di adegan admin.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Di HP ini SATU-SATUNYA jalan ke master data, jadi ngilangin blok ini
    // bakal mutus aksesnya sama sekali. Muncul dua kali (judul adegan +
    // label kaki carousel) — makanya `findsWidgets`, bukan `findsOneWidget`.
    expect(find.text('Menu Admin'), findsWidgets);
  });
}

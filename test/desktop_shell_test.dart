import 'package:flutter/material.dart';
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

/// `mock-token-1` = admin · `mock-token-2` = teknisi · `mock-token-3` = viewer.
Widget _app({String token = 'mock-token-1', bool panelDesktop = true}) {
  return ProviderScope(
    overrides: [
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

Future<void> _sampaiPanel(WidgetTester tester, {String token = 'mock-token-1'}) async {
  await tester.pumpWidget(_app(token: token));
  await tester.pumpAndSettle();
}

void main() {
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

  testWidgets('teknisi di laptop dapat "Tugas Saya", bukan cuma Alur Kerja', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester, token: 'mock-token-2');

    // Dulu "Tugas Saya" cuma ada di HP, jadi teknisi yang kerja di laptop
    // nggak punya jalan ke tugasnya sendiri — dia mesti nyisir Alur Kerja
    // yang isinya sesi semua orang.
    expect(find.text('Tugas Saya'), findsOneWidget);
  });

  testWidgets('viewer NGGAK dikasih "Tugas Saya" — dia nggak pernah ditugaskan', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester, token: 'mock-token-3');

    // Syaratnya `bisaInput` = admin ATAU teknisi, jadi admin ikut dapat —
    // dan itu memang disengaja, sama kayak di HP. Yang nggak dapat cuma
    // viewer, karena dia nggak bisa ngisi lembar kerja sama sekali.
    expect(find.text('Tugas Saya'), findsNothing);
  });

  testWidgets('admin ikut dapat "Tugas Saya", persis kayak di HP', (
    tester,
  ) async {
    await _jendelaDesktop(tester);
    await _sampaiPanel(tester);

    // Paritas HP↔laptop itu intinya: menu yang sama buat peran yang sama.
    expect(find.text('Tugas Saya'), findsOneWidget);
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

    // Layar 400x800: header + statistik makan seluruh viewport, dan body-nya
    // `ListView` yang bangun anaknya sesuai viewport. Digeser dulu biar
    // bloknya kebikin.
    await tester.drag(find.byType(ProfileScreen), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Di HP ini SATU-SATUNYA jalan ke master data, jadi ngilangin blok ini
    // bakal mutus aksesnya sama sekali.
    expect(find.text('MENU ADMIN'), findsOneWidget);
  });
}

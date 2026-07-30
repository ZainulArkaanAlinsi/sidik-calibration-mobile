import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
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
}

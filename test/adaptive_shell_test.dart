import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      notificationServiceProvider.overrideWithValue(
        MockNotificationService(jeda: Duration.zero),
      ),
    ],
    child: const SidikApp(),
  );
}

/// Pasang ukuran jendela + pastikan dikembalikan, biar test lain nggak
/// kewarisan ukuran aneh.
Future<void> _ukuran(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Lewatin splash/auth — MainShell baru mount sesudah ini.
Future<void> _sampaiShell(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  group('rangka adaptif: navigasi ikut lebar jendela', () {
    testWidgets('layar HP → navbar bawah, TANPA rail samping', (tester) async {
      await _ukuran(tester, const Size(400, 800));
      await _sampaiShell(tester);

      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('layar desktop → rail samping, TANPA navbar bawah', (
      tester,
    ) async {
      await _ukuran(tester, const Size(1400, 900));
      await _sampaiShell(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      // Dua kontrol navigasi yang isinya sama persis bakal bingungin —
      // navbar bawah HARUS hilang, bukan cuma ketutupan.
      expect(find.byType(FloatingNavBar), findsNothing);
    });

    testWidgets('jendela desktop dikecilin → balik ke navbar bawah', (
      tester,
    ) async {
      await _ukuran(tester, const Size(1400, 900));
      await _sampaiShell(tester);
      expect(find.byType(NavigationRail), findsOneWidget);

      // Yang nentuin itu lebar jendela, bukan merek OS-nya: jendela desktop
      // yang disempitin pantas dapat layout HP.
      await tester.binding.setSurfaceSize(const Size(500, 900));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('rail cuma dibentangkan di layar yang benar-benar lebar', (
      tester,
    ) async {
      await _ukuran(tester, const Size(1000, 800));
      await _sampaiShell(tester);

      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
        reason: '1000px masih sempit — label bakal makan ruang isi layar',
      );

      await tester.binding.setSurfaceSize(const Size(1400, 800));
      await tester.pumpAndSettle();

      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
    });

    testWidgets('tujuan rail sama persis dengan navbar bawah', (tester) async {
      await _ukuran(tester, const Size(400, 800));
      await _sampaiShell(tester);
      final jumlahHp = tester
          .widget<FloatingNavBar>(find.byType(FloatingNavBar))
          .items
          .length;

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpAndSettle();
      final jumlahDesktop = tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .destinations
          .length;

      // Orang yang pindah HP → desktop nggak boleh disuruh belajar peta baru.
      expect(jumlahDesktop, jumlahHp);
    });

    testWidgets('klik tujuan di rail beneran ganti tab', (tester) async {
      await _ukuran(tester, const Size(1400, 900));
      await _sampaiShell(tester);

      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        0,
      );

      // Tab ke-3 (Riwayat) — dipilih lewat rail, bukan navbar.
      await tester.tap(find.text('Riwayat').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        2,
      );
    });
  });
}

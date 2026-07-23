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
import 'package:sidik_calibration/widgets/notification_bell.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';

Widget _app({bool kosong = false, bool gagal = false, Duration jeda = Duration.zero}) {
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
        MockNotificationService(kosong: kosong, gagal: gagal, jeda: jeda),
      ),
    ],
    child: const SidikApp(),
  );
}

/// Notifikasi udah **nggak di navbar bawah** lagi (spesifikasi poin 4):
/// dibuka lewat ikon lonceng di app bar, dan mendarat di halaman sendiri.
Future<void> _bukaHalamanNotifikasi(WidgetTester tester) async {
  await tester.tap(find.byType(NotificationBell));
  await tester.pumpAndSettle();
}

void main() {
  group('4 state notifikasi', () {
    testWidgets('LOADING: skeleton muncul duluan', (tester) async {
      await tester.pumpWidget(
        _app(jeda: const Duration(milliseconds: 300)),
      );
      // Lewatin splash/auth dulu — MainShell (dan notificationProvider ikut
      // mulai nge-build lewat IndexedStack) baru mount di titik ini.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byType(NotificationBell));
      await tester.pump(); // buka halamannya, jangan majuin jam dulu

      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('NORMAL: daftar notifikasi kerender', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaHalamanNotifikasi(tester);

      expect(find.text('3 alat mendekati jatuh tempo'), findsOneWidget);
      expect(find.text('Sesi kalibrasi disetujui'), findsOneWidget);
      expect(find.text('Perlu revisi'), findsOneWidget);
    });

    testWidgets('EMPTY: belum ada notifikasi', (tester) async {
      await tester.pumpWidget(_app(kosong: true));
      await tester.pumpAndSettle();
      await _bukaHalamanNotifikasi(tester);

      expect(find.text('Belum ada notifikasi'), findsOneWidget);
    });

    testWidgets('ERROR: gagal muat → pesan + tombol coba lagi', (
      tester,
    ) async {
      await tester.pumpWidget(_app(gagal: true));
      await tester.pumpAndSettle();
      await _bukaHalamanNotifikasi(tester);

      expect(find.text('Gagal memuat notifikasi.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  testWidgets('tap notifikasi belum dibaca → titik penanda ilang', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _bukaHalamanNotifikasi(tester);

    // Awalnya 2 notifikasi belum dibaca (lihat MockNotificationService).
    final container = ProviderScope.containerOf(
      tester.element(find.text('3 alat mendekati jatuh tempo')),
    );
    expect(
      container.read(notificationProvider).value!.where((n) => !n.dibaca),
      hasLength(2),
    );

    await tester.tap(find.text('3 alat mendekati jatuh tempo'));
    await tester.pumpAndSettle();

    expect(
      container.read(notificationProvider).value!.where((n) => !n.dibaca),
      hasLength(1),
    );
  });
}

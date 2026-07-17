import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';

/// `mock-token-1` = admin · `mock-token-2` = teknisi.
Widget _app({
  String token = 'mock-token-1',
  bool kosong = false,
  bool gagal = false,
  Duration jeda = Duration.zero,
  bool approvalGagal = false,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      historyServiceProvider.overrideWithValue(
        MockHistoryService(kosong: kosong, gagal: gagal, jeda: jeda),
      ),
      approvalServiceProvider.overrideWithValue(
        MockApprovalService(gagal: approvalGagal),
      ),
    ],
    child: const SidikApp(),
  );
}

Future<void> _bukaTabRiwayat(WidgetTester tester) async {
  await tester.tap(find.text('Riwayat'));
  await tester.pumpAndSettle();
}

void main() {
  group('4 state riwayat', () {
    testWidgets('LOADING: skeleton muncul duluan', (tester) async {
      await tester.pumpWidget(
        _app(jeda: const Duration(milliseconds: 300)),
      );
      // Lewatin splash/auth dulu — MainShell (dan historyProvider ikut
      // mulai nge-build lewat IndexedStack) baru mount di titik ini.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Riwayat'));
      await tester.pump(); // ganti tab aktif, jangan majuin jam dulu

      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('NORMAL: daftar sesi kerender dengan badge status', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);

      expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
      expect(find.text('PASS'), findsOneWidget);
      expect(find.text('FAIL'), findsOneWidget);
      expect(find.text('Menunggu approval'), findsOneWidget);
      expect(find.text('Perlu revisi'), findsOneWidget);

      // Kartu admin punya tombol setujui/tolak tambahan (menunggu_approval),
      // jadi list-nya lebih tinggi dari viewport — item terakhir perlu
      // di-scroll dulu biar ke-build.
      final draft = find.text('Draft');
      await tester.scrollUntilVisible(
        draft,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(draft, findsOneWidget);
    });

    testWidgets('EMPTY: belum ada riwayat → ajakan, bukan list kosong', (
      tester,
    ) async {
      await tester.pumpWidget(_app(kosong: true));
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);

      expect(find.text('Belum ada riwayat'), findsOneWidget);
    });

    testWidgets('ERROR: gagal muat → pesan + tombol coba lagi', (
      tester,
    ) async {
      await tester.pumpWidget(_app(gagal: true));
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);

      expect(find.text('Gagal memuat riwayat.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  group('approval (admin doang)', () {
    testWidgets('admin lihat tombol SETUJUI/TOLAK', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);
      expect(find.text('SETUJUI'), findsOneWidget);
      expect(find.text('TOLAK'), findsOneWidget);
    });

    testWidgets('teknisi nggak lihat tombol SETUJUI/TOLAK', (tester) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);
      expect(find.text('SETUJUI'), findsNothing);
      expect(find.text('TOLAK'), findsNothing);
    });

    testWidgets('tap SETUJUI → status berubah jadi PASS/FAIL', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);

      expect(find.text('Menunggu approval'), findsOneWidget);

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();

      expect(find.text('Menunggu approval'), findsNothing);
      expect(find.text('SETUJUI'), findsNothing);
    });

    testWidgets('tap TOLAK → kosong ditolak, diisi → jadi Perlu revisi', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabRiwayat(tester);

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();

      // Kosong ditolak lokal — dialog nggak nutup.
      await tester.tap(find.text('TOLAK SESI'));
      await tester.pumpAndSettle();
      expect(find.text('Tolak sesi kalibrasi?'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Titik ukur kurang dari 3 pembacaan.',
      );
      await tester.tap(find.text('TOLAK SESI'));
      await tester.pumpAndSettle();

      expect(find.text('Tolak sesi kalibrasi?'), findsNothing);
      expect(
        find.textContaining('Titik ukur kurang dari 3 pembacaan.'),
        findsOneWidget,
      );
    });
  });
}

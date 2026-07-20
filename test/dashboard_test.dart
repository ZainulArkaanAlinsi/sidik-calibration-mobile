import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/skeleton.dart';
import 'package:sidik_calibration/widgets/stat_card.dart';

/// `mock-token-1` = admin · `mock-token-2` = teknisi · `mock-token-3` = viewer.
Widget _app({
  String token = 'mock-token-1',
  bool kosong = false,
  bool gagal = false,
  Duration jeda = Duration.zero,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(kosong: kosong, gagal: gagal, jeda: jeda),
      ),
    ],
    child: const SidikApp(),
  );
}

void main() {
  group('4 state dashboard', () {
    testWidgets('LOADING: skeleton muncul duluan, bukan layar kosong', (
      tester,
    ) async {
      await tester.pumpWidget(_app(jeda: const Duration(milliseconds: 300)));

      // Lewatin dulu cek token (auth) — selama itu masih splash, bukan
      // dashboard.
      await tester.pump(const Duration(milliseconds: 700));

      // Sekarang dashboard-nya mount tapi datanya belum nyampe → skeleton
      // harus udah kelihatan, bukan layar kosong.
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(StatCard), findsNothing);

      // Lewatin jedanya sampai data masuk.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.byType(StatCard), findsNWidgets(6));
    });

    testWidgets('NORMAL: angka-angkanya kerender', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(StatCard), findsNWidgets(6));
      expect(find.text('42'), findsOneWidget); // total alat
      expect(find.text('3'), findsOneWidget); // jatuh tempo
      expect(find.text('12'), findsOneWidget); // sertifikat bulan ini
    });

    testWidgets('EMPTY: belum ada data → ajakan mulai, bukan angka nol', (
      tester,
    ) async {
      await tester.pumpWidget(_app(kosong: true));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.byType(StatCard), findsNothing);
      // Teknisi/admin dikasih jalan keluar, bukan cuma dikasih tahu kosong.
      expect(find.text('TAMBAH ALAT'), findsOneWidget);
    });

    testWidgets('ERROR: gagal muat → pesan + tombol coba lagi', (tester) async {
      await tester.pumpWidget(_app(gagal: true));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat dashboard.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  group('beda per role', () {
    // Draft & menunggu-approval dulu ditampilin gantian tergantung role, jadi
    // tiap role cuma lihat separuh gambaran. Sekarang dua-duanya selalu
    // dirender — yang tetap beda per role cuma JUDUL seksinya, karena
    // backend yang nge-scope angkanya (teknisi dapat sesinya sendiri).
    testWidgets('admin → judul "RINGKASAN ORGANISASI", dua kartu antrean ada', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('RINGKASAN ORGANISASI'), findsOneWidget);
      expect(find.text('MENUNGGU APPROVAL'), findsOneWidget);
      expect(find.text('DRAFT KALIBRASI'), findsOneWidget);
    });

    testWidgets('teknisi → judul "RINGKASAN KAMU", dua kartu antrean ada', (
      tester,
    ) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();

      expect(find.text('RINGKASAN KAMU'), findsOneWidget);
      expect(find.text('DRAFT KALIBRASI'), findsOneWidget);
      expect(find.text('MENUNGGU APPROVAL'), findsOneWidget);
    });

    testWidgets('viewer → tombol aksi NGGAK dirender sama sekali', (
      tester,
    ) async {
      await tester.pumpWidget(_app(token: 'mock-token-3'));
      await tester.pumpAndSettle();

      // Viewer read-only: bukan tombolnya di-disable, tapi memang nggak ada.
      expect(find.text('AKSI CEPAT'), findsNothing);
      expect(find.text('MULAI KALIBRASI'), findsNothing);
      expect(find.text('TAMBAH ALAT'), findsNothing);
      // Tapi tetap bisa lihat angkanya.
      expect(find.byType(StatCard), findsNWidgets(6));
    });
  });

  testWidgets('alat overdue → peringatannya muncul, nggak cuma angka', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Banner-nya di bawah grid, jadi perlu di-scroll dulu — persis kayak user.
    final banner = find.textContaining('lewat jatuh tempo kalibrasi');
    await tester.scrollUntilVisible(
      banner,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      banner,
      findsOneWidget,
      reason: 'alat telat kalibrasi itu masalah audit, harus ditonjolin',
    );
  });

  testWidgets(
    'tap "Total alat" → push layar ringkasan (bukan lompat tab navbar)',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TOTAL ALAT'));
      await tester.pumpAndSettle();

      // Layar baru ke-push (AppBar "Total alat" + tombol back) — bukan
      // switch ke tab "Alat" di bottom nav (itu behavior lama yang
      // sengaja diganti karena kerasa kayak "double UI").
      expect(find.widgetWithText(AppBar, 'Total alat'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    },
  );
}

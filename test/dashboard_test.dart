import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/services/dashboard_service.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';
import 'package:asmo_mobile/widgets/skeleton.dart';
import 'package:asmo_mobile/widgets/stat_card.dart';

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
    child: const AsmoApp(),
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
      expect(find.byType(StatCard), findsNWidgets(4));
    });

    testWidgets('NORMAL: angka-angkanya kerender', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(StatCard), findsNWidgets(4));
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
    testWidgets('admin → judul "RINGKASAN ORGANISASI" + antrean approval', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('RINGKASAN ORGANISASI'), findsOneWidget);
      expect(find.text('Menunggu approval'), findsOneWidget);
      expect(find.text('Draft kalibrasi'), findsNothing);
    });

    testWidgets('teknisi → judul "RINGKASAN KAMU" + draft miliknya', (
      tester,
    ) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();

      expect(find.text('RINGKASAN KAMU'), findsOneWidget);
      expect(find.text('Draft kalibrasi'), findsOneWidget);
      expect(find.text('Menunggu approval'), findsNothing);
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
      expect(find.byType(StatCard), findsNWidgets(4));
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

  testWidgets('tap "Total alat" → lompat ke tab Alat', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total alat'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Alat'), findsOneWidget);
  });
}

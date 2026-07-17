import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/providers/equipment_provider.dart';
import 'package:asmo_mobile/screens/equipment/equipment_form_screen.dart';
import 'package:asmo_mobile/screens/equipment/equipment_list_screen.dart';
import 'package:asmo_mobile/services/category_service.dart';
import 'package:asmo_mobile/services/customer_service.dart';
import 'package:asmo_mobile/services/dashboard_service.dart';
import 'package:asmo_mobile/services/equipment_service.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';
import 'package:asmo_mobile/widgets/skeleton.dart';

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
        MockDashboardService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(
        MockEquipmentService(kosong: kosong, gagal: gagal, jeda: jeda),
      ),
      categoryServiceProvider.overrideWithValue(const MockCategoryService()),
      customerServiceProvider.overrideWithValue(const MockCustomerService()),
    ],
    child: const SidikApp(),
  );
}

/// Tab Alat isinya panjang & bottom-nav-nya mengambang (viewport lebih
/// pendek) — pola scroll yang sama kayak `_scrollProfilKe` di `auth_test.dart`,
/// nunjuk `Scrollable`-nya `EquipmentListScreen` biar nggak ketuker sama
/// scrollable tab lain yang tetap ke-mount gara-gara `IndexedStack`.
Future<void> _scrollDiAlat(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find
              .descendant(
                of: find.byType(EquipmentListScreen),
                matching: find.byType(ListView),
              )
              .first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _bukaTabAlat(WidgetTester tester) async {
  await tester.tap(find.text('Alat'));
  await tester.pumpAndSettle();
}

void main() {
  group('4 state daftar Alat', () {
    testWidgets('LOADING: skeleton muncul duluan', (tester) async {
      await tester.pumpWidget(_app(jeda: const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 700)); // lewatin splash

      await tester.tap(find.text('Alat'));
      await tester.pump(); // 1 frame abis pindah tab, jeda-nya belum kelar

      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pump(const Duration(milliseconds: 400)); // lewatin jeda
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('DATA: alat ke-seed kerender', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
      expect(find.textContaining('Timbangan Digital Ohaus'), findsOneWidget);
    });

    testWidgets('EMPTY: belum ada alat → ajakan mulai', (tester) async {
      await tester.pumpWidget(_app(kosong: true));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      expect(find.text('Belum ada data'), findsOneWidget);
    });

    testWidgets('ERROR: gagal muat → pesan + tombol coba lagi', (
      tester,
    ) async {
      await tester.pumpWidget(_app(gagal: true));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      expect(find.text('Gagal memuat daftar alat.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });

  group('search & filter', () {
    testWidgets('cari nama → cuma yang cocok yang kerender', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(EquipmentListScreen),
          matching: find.byType(TextField),
        ),
        'Fluke',
      );
      // Debounce 400ms di layarnya.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Termometer Digital Fluke'), findsOneWidget);
      expect(find.text('Jangka Sorong Mitutoyo'), findsNothing);
    });

    testWidgets('cari yang nggak ketemu → pesan "nggak ketemu"', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(EquipmentListScreen),
          matching: find.byType(TextField),
        ),
        'zzz-nggak-ada',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Nggak ketemu'), findsOneWidget);
    });
  });

  group('beda per role', () {
    testWidgets('teknisi → tombol tambah (FAB) ada', (tester) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('viewer → read-only: FAB nggak ada, kartu nggak bisa di-tap', (
      tester,
    ) async {
      await tester.pumpWidget(_app(token: 'mock-token-3'));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Jangka Sorong Mitutoyo'));
      await tester.pumpAndSettle();

      // Nggak pindah ke form — masih di tab Alat.
      expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
      expect(find.text('Tambah Alat'), findsNothing);
      expect(find.text('Ubah Alat'), findsNothing);
    });
  });

  group('form tambah/ubah/hapus', () {
    testWidgets('tambah alat baru → muncul di daftar', (tester) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Alat'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Micrometer Baru');
      await tester.enterText(fields.at(1), 'SN-BARU-001');
      await tester.enterText(fields.at(2), 'Insize');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panjang').last);
      await tester.pumpAndSettle();

      final tombolSimpan = find.text('SIMPAN ALAT');
      await tester.scrollUntilVisible(
        tombolSimpan,
        200,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(EquipmentFormScreen),
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(tombolSimpan);
      await tester.pumpAndSettle();

      await _scrollDiAlat(tester, find.text('Micrometer Baru'));
      expect(find.text('Micrometer Baru'), findsOneWidget);
    });

    testWidgets('hapus alat → hilang dari daftar', (tester) async {
      await tester.pumpWidget(_app(token: 'mock-token-2'));
      await tester.pumpAndSettle();
      await _bukaTabAlat(tester);

      await tester.tap(find.text('Jangka Sorong Mitutoyo'));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Alat'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Hapus alat ini?'), findsOneWidget);
      await tester.tap(find.text('HAPUS'));
      await tester.pumpAndSettle();

      expect(find.text('Jangka Sorong Mitutoyo'), findsNothing);
    });
  });
}

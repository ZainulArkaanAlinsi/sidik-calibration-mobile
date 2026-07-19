import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show categoryServiceProvider;
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerServiceProvider;
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/customer_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';

/// Dibungkus `SidikApp` (bukan langsung `EquipmentListScreen`) — layar ini
/// nge-watch `authProvider`, dan kalau dibuka lepas dari `AuthGate`,
/// `MockAuthService.me()`-nya yang berjeda 600ms ninggalin timer nyangkut
/// yang bikin `pumpAndSettle` gagal di akhir test (`!timersPending`). Lewat
/// `SidikApp`, timer itu udah kelar waktu splash, sebelum tab Alat dibuka.
Widget _app({String token = 'mock-token-1', bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(
        MockEquipmentService(gagal: gagal),
      ),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      customerServiceProvider.overrideWithValue(MockCustomerService()),
    ],
    child: const SidikApp(),
  );
}

/// Form Alat punya ~13 field — lebih panjang dari viewport test standar
/// (800x600), dan `ListView` cuma nge-build item yang deket viewport (sama
/// kasusnya kayak `ph_calibration_input_test.dart`).
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Tap label "Alat" di bottom nav — bukan `find.text('Alat')` polos, soalnya
/// begitu tab-nya aktif AppBar-nya JUGA berjudul "Alat", jadi ada 2 match.
Future<void> _tapTabAlat(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(FloatingNavBar),
      matching: find.text('Alat'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _bukaTabAlat(WidgetTester tester, {String token = 'mock-token-1'}) async {
  // Widget kosong dulu biar `ProviderScope`/container app sebelumnya (kalau
  // ada, dari pemanggilan `_bukaTabAlat` lain di test yang sama) beneran
  // dibuang — tanpa ini Flutter ngereuse elemen `SidikApp` lama, jadi state
  // auth/tab lama (mis. role admin) masih nyangkut walau token-nya diganti.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_app(token: token));
  await tester.pumpAndSettle();
  await _tapTabAlat(tester);
}

void main() {
  testWidgets('nampilin daftar alat dengan badge status', (tester) async {
    await _bukaTabAlat(tester);

    expect(find.text('Jangka Sorong Mitutoyo'), findsOneWidget);
    expect(find.text('Timbangan Digital Ohaus'), findsOneWidget);
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();
    await _tapTabAlat(tester);

    expect(find.text('Gagal memuat daftar alat.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });

  testWidgets('admin bisa lihat tombol tambah & hapus, viewer nggak', (
    tester,
  ) async {
    await _bukaTabAlat(tester);
    expect(find.text('TAMBAH ALAT'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    // token-3 = viewer (lihat MockAuthService) — instance app baru dari nol,
    // bukan nyambung dari state token admin di atas.
    await _bukaTabAlat(tester, token: 'mock-token-3');
    expect(find.text('TAMBAH ALAT'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('tambah alat baru → muncul di list', (tester) async {
    _perbesarViewport(tester);
    await _bukaTabAlat(tester);

    await tester.tap(find.text('TAMBAH ALAT'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Termometer Digital Baru',
    );
    await tester.enterText(find.byType(TextField).at(1), 'TD-001');

    await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Massa').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih pelanggan'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Maju Jaya').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(find.text('Termometer Digital Baru'), findsOneWidget);
  });

  testWidgets(
    'pilih kategori "Panjang" → dropdown Jenis Alat (Kemampuan Kalibrasi) muncul',
    (tester) async {
      _perbesarViewport(tester);
      await _bukaTabAlat(tester);

      await tester.tap(find.text('TAMBAH ALAT'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panjang').last);
      await tester.pumpAndSettle();

      // MockCategoryService.detail('panjang') balikin 2 kemampuan — dropdown-nya
      // muncul begitu kategori dipilih, bukan cuma field kosong nggak berguna.
      expect(find.text('Pilih jenis alat (opsional, buat CMC akurat)'), findsOneWidget);
      await tester.tap(
        find.text('Pilih jenis alat (opsional, buat CMC akurat)'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jangka Sorong').last);
      await tester.pumpAndSettle();

      expect(find.text('Jangka Sorong'), findsWidgets);
    },
  );

  testWidgets('hapus alat → dikonfirmasi dulu, baru ilang dari list', (
    tester,
  ) async {
    await _bukaTabAlat(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Jangka Sorong Mitutoyo'), findsNothing);
  });
}

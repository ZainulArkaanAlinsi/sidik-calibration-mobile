import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show standardServiceProvider;
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/floating_nav_bar.dart';

/// Dibungkus `SidikApp` (bukan langsung `StandardListScreen`) — layar Profil
/// yang jadi jalan masuknya nge-watch `authProvider`, dan kalau dibuka lepas
/// dari `AuthGate`, `MockAuthService.me()`-nya yang berjeda 600ms ninggalin
/// timer nyangkut (`!timersPending`). Lihat pola yang sama di
/// `equipment_test.dart`.
///
/// `mock-token-1` = admin · `mock-token-3` = viewer.
Widget _app({String token = 'mock-token-1', bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      standardServiceProvider.overrideWithValue(
        MockStandardService(gagal: gagal),
      ),
    ],
    child: const SidikApp(),
  );
}

/// Form standar cukup panjang (10 field) — sama kasusnya kayak form Alat.
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Dashboard → tab Profil → menu "Standar Acuan". Viewport diperbesar biar
/// kartu menu admin (termasuk "Standar Acuan", item ke-3) ke-build — layar
/// Profil punya header foto 260px sebelum menu admin, gampang kepotong di
/// viewport test standar (800x600).
Future<void> _bukaLayarStandar(
  WidgetTester tester, {
  String token = 'mock-token-1',
  bool gagal = false,
}) async {
  _perbesarViewport(tester);
  // Widget kosong dulu biar container app sebelumnya (kalau ada dari
  // pemanggilan lain di test yang sama) beneran dibuang.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_app(token: token, gagal: gagal));
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(FloatingNavBar),
      matching: find.text('Profil'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Standar Acuan'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nampilin daftar standar dengan badge berlaku/kadaluarsa', (
    tester,
  ) async {
    await _bukaLayarStandar(tester);

    expect(find.text('Gauge Block Set Grade 0'), findsOneWidget);
    expect(find.text('Berlaku'), findsWidgets);
    expect(find.text('Kadaluarsa'), findsWidgets); // Standar Massa Kelas F1
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await _bukaLayarStandar(tester, gagal: true);

    expect(find.text('Gagal memuat standar acuan.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });

  testWidgets('admin bisa lihat tombol tambah & hapus', (tester) async {
    await _bukaLayarStandar(tester);
    expect(find.text('TAMBAH STANDAR'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });

  testWidgets('viewer nggak lihat menu "Standar Acuan" di Profil sama sekali', (
    tester,
  ) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app(token: 'mock-token-3'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();

    // Seluruh kartu menu admin (termasuk "Standar Acuan") nggak dirender
    // sama sekali buat viewer — bukan dirender-tapi-disabled.
    expect(find.text('Standar Acuan'), findsNothing);
  });

  testWidgets('tambah standar baru → muncul di list', (tester) async {
    _perbesarViewport(tester);
    await _bukaLayarStandar(tester);

    await tester.tap(find.text('TAMBAH STANDAR'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Termometer Std. Baru');
    // Urutan TextField: nama[0], merk[1], model[2], serial[3], no.
    // sertifikat[4], tertelusur ke[5], lalu ketidakpastian[6] (measurement
    // field pertama sesudah date picker yang bukan TextField).
    await tester.enterText(find.byType(TextField).at(6), '0.05');

    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(find.text('Termometer Std. Baru'), findsOneWidget);
  });

  testWidgets('hapus standar → dikonfirmasi dulu, baru ilang dari list', (
    tester,
  ) async {
    await _bukaLayarStandar(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Gauge Block Set Grade 0'), findsNothing);
  });
}

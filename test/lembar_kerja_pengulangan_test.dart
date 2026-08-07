import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Jumlah kotak pengulangan bisa dipilih teknisi — 5 cuma bawaan.
///
/// Lembar kerja kertas lab nyetak 5 kolom, tapi di lapangan sering cuma perlu
/// 3 (sampel terbatas, atau alatnya udah stabil banget). Dua kolom sisanya cuma
/// jadi ruang kosong yang bikin ragu: "ini wajib diisi apa nggak?"
///
/// Yang berubah CUMA jumlah kotak yang digambar. Rumusnya sendiri selalu ngikut
/// berapa kotak yang beneran diisi — itu dijaga di sisi backend
/// (`PengulanganBebasTest`), bukan di sini.
void main() {
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(MockLembarKerjaService service, {String profil = 'ph_meter'}) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        lembarKerjaServiceProvider.overrideWithValue(service),
        standardServiceProvider.overrideWithValue(MockStandardService()),
        roomServiceProvider.overrideWithValue(MockRoomService()),
        equipmentLookupServiceProvider.overrideWithValue(
          MockEquipmentLookupService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LembarKerjaScreen(profil: profil),
      ),
    );
  }

  /// `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer kayak
  /// gitu nggak ngejadwalin frame — `pumpAndSettle` doang balik duluan.
  Future<void> muat(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  /// Buka menu di AppBar, pilih `n` kali, terus setujui konfirmasinya.
  Future<void> pilihPengulangan(WidgetTester tester, int n) async {
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$n kali pengulangan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
  }

  testWidgets('bawaannya 5, sama kayak form kertas', (tester) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    expect(find.text('5x'), findsOneWidget);
  });

  testWidgets('pilih 3 → lembar kerjanya dibangun ulang jadi 3 kotak',
      (tester) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    await pilihPengulangan(tester, 3);

    expect(find.text('3x'), findsOneWidget);
    expect(find.text('5x'), findsNothing);
  });

  testWidgets('ganti jumlah kotak dikonfirmasi dulu, bukan langsung jalan',
      (tester) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 kali pengulangan').last);
    await tester.pumpAndSettle();

    // Dialognya nyebut angka yang dituju, biar yang salah pencet sadar.
    expect(find.text('Ubah jumlah pengulangan?'), findsOneWidget);
    expect(find.textContaining('3 kolom'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // Dibatalin = nggak ada yang berubah. Isian teknisi nggak boleh ilang cuma
    // gara-gara menu kesenggol.
    expect(find.text('5x'), findsOneWidget);
    expect(find.text('3x'), findsNothing);
  });

  testWidgets('jumlah kotak yang dipilih ikut kekirim ke backend',
      (tester) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    await pilihPengulangan(tester, 4);

    // Backend yang mutusin bentuknya; mobile cuma minta. Kalau angkanya nggak
    // ikut kekirim, layarnya bakal nampilin "4x" tapi tabelnya tetap 5 kotak —
    // salah yang nggak keliatan sampai ada yang ngitung kotaknya.
    expect(service.pengulanganDiminta, contains(4));
  });

  // Dipisah per alat, bukan diulang dalam satu test: `pumpWidget` kedua di test
  // yang sama numpuk di atas dialog yang masih nutup, dan gagalnya kelihatan
  // kayak bug fitur padahal cuma testnya yang saling numpang.
  for (final profil in ['turbidimeter', 'chlorine_meter']) {
    testWidgets('berlaku juga buat $profil', (tester) async {
      perbesarViewport(tester);
      final service = MockLembarKerjaService();
      await muat(tester, app(service, profil: profil));

      await pilihPengulangan(tester, 3);

      expect(find.text('3x'), findsOneWidget);
      expect(service.pengulanganDiminta, contains(3));
    });
  }
}

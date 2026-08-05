import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Tiga alat, tiga lembar kerja — dirender beneran, bukan cuma dicek kontraknya.
///
/// Latarnya: `alur_kerja_screen.dart` dulu buka lembar kerja tanpa ngoper
/// `profil`, jadi sesi Chlorine & Turbidimeter kebuka sebagai pH. Waktu itu
/// diperbaiki, yang paling ditakutin justru pH & Turbidimeter ikut rusak —
/// makanya ketiganya dikunci di sini sekaligus, di layar yang sama.
///
/// Yang diperiksa titik ukur & satuannya, karena dua itu yang nyampe ke
/// sertifikat DAN yang dikirim sebagai petunjuk `nominal`/`satuan` ke AI Vision
/// waktu teknisi motret tabel. Salah profil = salah petunjuk = angka mendarat
/// di sel yang salah.
Widget _layar(String profil) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-2'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
    // Master data ikut di-mock. Kalau nggak, layar nembak `ApiClient` beneran
    // dan `.timeout(20 detik)` di sana nyisain Timer yang bikin test gagal di
    // teardown ("A Timer is still pending").
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LembarKerjaScreen(profil: profil),
  ),
);

void main() {
  Future<void> cek(
    WidgetTester tester, {
    required String profil,
    required List<String> titik,
    required List<String> titikAsing,
  }) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_layar(profil));
    // `pumpAndSettle` doang nggak cukup: `MockAuthService.me()` jeda 600 ms
    // lewat `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame —
    // jadi pumpAndSettle balik duluan dan timernya nyangkut. Pola yang sama
    // dipakai `lembar_kerja_test.dart` & `dashboard_test.dart`.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    for (final t in titik) {
      expect(
        find.textContaining(t, findRichText: true),
        findsWidgets,
        reason: 'profil $profil mestinya punya titik $t',
      );
    }

    // Yang lebih penting daripada "titiknya ada": titik alat LAIN nggak boleh
    // ikut nongol. Itu gejala persis waktu profilnya ketuker.
    for (final t in titikAsing) {
      expect(
        find.textContaining(t, findRichText: true),
        findsNothing,
        reason: 'profil $profil kebawa titik $t dari alat lain — profil ketuker',
      );
    }
  }

  testWidgets('pH Meter → titik 4,00 / 7,00 / 10,01', (tester) async {
    await cek(
      tester,
      profil: 'ph_meter',
      titik: ['4,00', '7,00', '10,01'],
      titikAsing: ['1,74', '1,83'],
    );
  });

  testWidgets('Turbidimeter → titik 1 / 100 / 1000 NTU', (tester) async {
    await cek(
      tester,
      profil: 'turbidimeter',
      titik: ['NTU'],
      titikAsing: ['1,74', '1,83', '10,01'],
    );
  });

  testWidgets('Chlorine Meter → titik 1,74 / 1,83 mg/L', (tester) async {
    await cek(
      tester,
      profil: 'chlorine_meter',
      titik: ['1,74', '1,83', 'mg/L'],
      // Kalau tiga ini muncul, artinya formulir pH yang kerender — bug yang
      // bikin "kameranya meleset".
      titikAsing: ['4,00', '7,00', '10,01'],
    );
  });
}

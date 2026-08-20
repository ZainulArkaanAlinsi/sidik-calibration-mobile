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

/// Layar lembar kerja **Multi Gas Detector** (alat ke-10) beneran kerender.
///
/// Gas Detector sengaja NGGAK punya layar sendiri kayak Autoklaf — bentuk
/// lembarnya struktur generik yang sama dengan delapan alat lain, jadi dia
/// lewat `LembarKerjaScreen`. Yang bikin dia gampang salah bukan strukturnya,
/// tapi EMPAT hal yang cuma dia punya, dan salahnya nggak keluar sebagai error:
///
///  1. Satuan campur per baris (ppm / %LEL / %), `satuan` lembar `null`.
///  2. Tiga pengulangan, bukan lima.
///  3. Tekanan udara awal & akhir — kolom ketiga di tabel Environment
///     Condition, dan cuma alat ini yang punya.
///  4. Empat gas sekaligus dalam satu tabel.
void main() {
  Widget app(String profil) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
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

  Future<void> buka(WidgetTester tester, String profil) async {
    tester.view.physicalSize = const Size(1400, 4600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(profil));
    // Layar generik punya debounce autosimpan; ditunggu supaya timernya
    // kebakar di dalam test, bukan nyisa waktu widget tree-nya dibuang.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> kuras(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('lembar Gas Detector kerender dengan empat gas & satuannya',
      (tester) async {
    await buka(tester, 'gas_detector');

    // Lembarnya sendiri, bukan lembar pH yang jadi cabang bawaan buat profil
    // yang nggak dikenal. Ini kegagalan senyap yang sudah pernah kejadian di
    // Viscometer: profilnya kekirim, lembarnya pH, dan nggak ada yang error.
    expect(find.textContaining('Gas Detector'), findsWidgets);
    expect(find.textContaining('pH Meter'), findsNothing);
    expect(find.textContaining('10,01'), findsNothing);

    // Keempat gas kegambar.
    for (final gas in ['CO', 'H2S', 'CH4', 'O2']) {
      expect(
        find.textContaining(gas),
        findsWidgets,
        reason: 'Baris $gas nggak kegambar di tabel hasil.',
      );
    }

    // Dua tahap adjustment, ikut kertasnya.
    expect(find.textContaining('Before Adjustment'), findsWidgets);
    expect(find.textContaining('After Adjustment'), findsWidgets);

    await kuras(tester);
  });

  testWidgets('satuan nempel per baris, bukan satu satuan buat seluruh lembar',
      (tester) async {
    await buka(tester, 'gas_detector');

    // Tiga satuan berbeda di satu lembar. Kalau layar jatuh ke `satuan` level
    // lembar (yang `null` buat alat ini), ketiganya ilang sekaligus dan tiap
    // baris kelihatan tanpa satuan — angka 50 yang sebenarnya %LEL kebaca
    // sebagai ppm oleh siapa pun yang membacanya nanti.
    expect(find.textContaining('ppm'), findsWidgets);
    expect(find.textContaining('%LEL'), findsWidgets);

    await kuras(tester);
  });

  testWidgets('tabel Environment Condition dapat kolom tekanan', (tester) async {
    await buka(tester, 'gas_detector');

    // Tekanan udara BUKAN pelengkap buat alat ini: komponen suhu & tekanan di
    // budget ketidakpastiannya lahir dari pergeseran ruangan selama sesi
    // (Δ = |akhir − awal|). Kalau kolomnya nggak kegambar, teknisi nggak punya
    // tempat mengisinya dan U95-nya keluar lebih kecil dari yang sebenarnya —
    // tanpa satu pun error.
    expect(find.text('Pressure'), findsOneWidget);
    expect(find.textContaining('hPa'), findsWidgets);

    // Dan tetap satu tabel yang sama, bukan tabel kedua di bawahnya: kepala
    // Temperature & Humidity masih tunggal.
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);

    await kuras(tester);
  });

  testWidgets('delapan alat lain nggak ikut dapat kolom tekanan',
      (tester) async {
    // Penjaga arah sebaliknya. Kolom tekanan digambar dari KEBERADAAN
    // `tekanan_awal`/`tekanan_akhir` di bentuknya, jadi kalau syarat itu
    // longgar, sembilan lembar lain ikut kebagian kolom kosong yang nggak
    // pernah ada di kertasnya.
    await buka(tester, 'do_meter');

    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('Pressure'), findsNothing);

    await kuras(tester);
  });
}

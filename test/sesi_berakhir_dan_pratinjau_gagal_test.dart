import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/models/pratinjau_hitung.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Butir 6 (401 -> pesan jelas + keluar) dan butir 3 (pratinjau gagal tapi
/// angka lama masih ada -> banner, angka lama tidak dihapus).
class _Lembar401 extends MockLembarKerjaService {
  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async =>
      throw const ApiException('Unauthenticated.', status: 401);
}

class _LembarPratinjau extends MockLembarKerjaService {
  bool gagalPratinjau = false;

  @override
  Future<PratinjauHitung> pratinjau(
    String token,
    LembarKerjaSubmission isian,
  ) async {
    if (gagalPratinjau) throw Exception('server nggak nyaut');
    return PratinjauHitung(
      titik: [
        MeasurementResult.fromJson({
          'titik_ke': 1,
          'titik_ukur': 4,
          'rata_rata': 4.0,
          'koreksi': 0.0,
          'ketidakpastian_diperluas': 0.1,
          'desimal': 2,
        }),
      ],
      belumDihitung: const [],
    );
  }
}

void main() {
  const alat = 'pH Meter Mettler Toledo · B628755900';
  setUp(() {
    MockStore.instance.reset();
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(LembarKerjaService lembar, TokenStorage token) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(token),
      simpananDrafLokalProvider.overrideWithValue(SimpananDrafLokalMemori()),
      sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
      authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
      lembarKerjaServiceProvider.overrideWithValue(lembar),
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
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(authProvider);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LembarKerjaScreen(profil: 'ph_meter'),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> pasang(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentLookup>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(alat).last);
    await tester.pumpAndSettle();
  }

  Finder kotakAfter() => find.descendant(
    of: find
        .ancestor(
          of: find.text('After adjustment Reading'),
          matching: find.byType(Column),
        )
        .first,
    matching: find.byType(TextField),
  );

  Future<void> isi(WidgetTester tester, String a, String b) async {
    await tester.enterText(kotakAfter().at(0), a);
    await tester.enterText(kotakAfter().at(1), b);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  testWidgets('kirim ditolak 401: pesan "Sesi berakhir", bukan teks server, '
      'dan token dibuang (keluar)', (tester) async {
    final token = InMemoryTokenStorage('mock-token-1');
    await pasang(tester, app(_Lembar401(), token));
    await isi(tester, '4.00', '22.2');

    await tester.tap(find.text('Kirim ke admin'));
    await tester.pumpAndSettle();
    final konfirmasi = find.text('Kirim sekarang');
    if (konfirmasi.evaluate().isNotEmpty) {
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
    }

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sesi berakhir, silakan masuk lagi.'), findsOneWidget);
    expect(find.textContaining('Unauthenticated'), findsNothing);
    expect(find.textContaining('Gagal menyimpan'), findsNothing);
    expect(await token.read(), isNull, reason: 'logout tidak terpicu');
  });

  testWidgets('pratinjau gagal tapi hasil lama ada: banner muncul, angka lama '
      'tetap; hilang begitu berhasil lagi', (tester) async {
    final lembar = _LembarPratinjau();
    await pasang(tester, app(lembar, InMemoryTokenStorage('mock-token-1')));

    await isi(tester, '4.00', '22.2');
    expect(find.text('HASIL HITUNG SEMENTARA'), findsOneWidget);
    expect(find.byKey(const ValueKey('pratinjau-gagal-basi')), findsNothing);

    lembar.gagalPratinjau = true;
    await isi(tester, '4.01', '22.3');
    expect(find.byKey(const ValueKey('pratinjau-gagal-basi')), findsOneWidget);
    expect(
      find.textContaining('Pratinjau terakhir gagal'),
      findsOneWidget,
    );
    expect(find.text('HASIL HITUNG SEMENTARA'), findsOneWidget);

    lembar.gagalPratinjau = false;
    await isi(tester, '4.02', '22.4');
    expect(find.byKey(const ValueKey('pratinjau-gagal-basi')), findsNothing);
  });
}

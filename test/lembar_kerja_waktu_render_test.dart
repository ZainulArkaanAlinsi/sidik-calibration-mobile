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

/// Ketiga lembar kelompok **Waktu dan Frekuensi** beneran KERENDER — bukan cuma
/// bentuk datanya yang benar.
///
/// Ketiganya lewat `LembarKerjaScreen` generik, tanpa layar sendiri. Test ini
/// yang membuktikan keputusan itu jalan di layar: kalau salah satunya butuh
/// layar khusus, yang ketahuan di sini — bukan waktu teknisi membukanya di
/// lokasi.
///
/// Timer yang paling perlu dijaga. Satu ulangannya EMPAT kotak (`J | M | S |
/// 0.001S`), bentuk yang belum pernah ada di sembilan belas lembar sebelumnya,
/// dan dua tabelnya ber-`tahap` sama — cuma `grup` yang memisahkan kunci selnya.
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
    tester.view.physicalSize = const Size(1800, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(profil));
    // Layar generik punya debounce autosimpan; ditunggu supaya timernya kebakar
    // di dalam test, bukan nyisa waktu widget tree-nya dibuang.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('lembar Timer kerender: dua tabel, empat kotak per ulangan', (
    tester,
  ) async {
    await buka(tester, 'timer_stopwatch');

    // Judulnya sendiri, bukan lembar pH yang jadi cabang bawaan mode mock.
    expect(find.textContaining('Stopwatch'), findsWidgets);
    expect(find.textContaining('pH Meter'), findsNothing);

    // DUA tabel deret, judulnya seperti tercetak.
    expect(find.textContaining('Pembacaan Stopwatch Standar'), findsWidgets);
    expect(find.textContaining('Pembacaan Alat yang Dikalibrasi'), findsWidgets);

    // Kepala keempat kotaknya. `0.001 S` yang paling menentukan: dia yang
    // membedakan lembar ini dari lembar mana pun yang sudah ada.
    for (final label in ['J', 'M', 'S', '0.001 S']) {
      expect(
        find.text(label),
        findsWidgets,
        reason: 'Kepala kotak `$label` nggak kegambar. Tanpa kepalanya, '
            'teknisi nggak punya cara tahu kotak mana yang menit dan mana '
            'yang milidetik — dan salah satu kotak bikin waktunya meleset '
            'enam puluh kali.',
      );
    }

    // Set point saran dari master, dalam DETIK.
    expect(find.textContaining('60'), findsWidgets);
  });

  testWidgets('lembar Centrifuge & Tachometer kerender sebagai tabel datar', (
    tester,
  ) async {
    for (final entri in {
      'centrifuge': 'Centrifuge',
      'tachometer': 'Infrared Tachometer',
    }.entries) {
      await buka(tester, entri.key);

      expect(find.textContaining(entri.value), findsWidgets);
      expect(find.textContaining('pH Meter'), findsNothing);

      // Judul kolom nilainya `Set Point`, bukan `Standard` — yang dicatat di
      // kolom pembacaan justru bacaan tachometer STANDAR.
      expect(find.textContaining('Set Point'), findsWidgets);
    }
  });
}

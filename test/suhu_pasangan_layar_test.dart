import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Layar lembar kerja tiga alat suhu ber-PASANGAN deret — DIGAMBAR, bukan cuma
/// dihitung.
///
/// [suhu_pasangan_lembar_kerja_test.dart] menjaga bentuk & payload-nya. Yang
/// dijaga di SINI cuma satu hal, dan hal itu nggak kelihatan dari state:
/// **kedua tabel benar-benar muncul di layar, dengan kotak isian yang
/// terpisah.**
///
/// Bedanya nyata. Sebelum tiap tabel punya `grup` sendiri, dua tabel ini
/// menulis ke controller yang SAMA: layar tetap menggambar dua tabel utuh,
/// tetap bisa diketik, dan yang terjadi cuma angka deret UUT muncul juga di
/// deret standar. Nol error, dan yang menemukannya nanti teknisi yang menatap
/// dua baris angka kembar sambil yakin dia salah ketik.
void main() {
  Widget app(String profil, MockLembarKerjaService service) => ProviderScope(
    overrides: [
      pindaiLembarAktifProvider.overrideWithValue(false),
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
      worksheetScanServiceProvider.overrideWithValue(
        MockWorksheetScanService(siapPindai: false),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );

  Future<void> buka(WidgetTester tester, String profil) async {
    // Lembarnya panjang — dua tabel × 5–6 baris × 5 kolom, plus blok
    // No. Termokopel. Viewport-nya ditinggikan supaya `ListView` nge-build
    // semuanya; lebarnya sengaja di BAWAH ambang dua kolom (1100), karena yang
    // diuji isinya bukan tata letaknya.
    tester.view.physicalSize = const Size(900, 24000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(profil, MockLembarKerjaService()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  group('dua tabel digambar terpisah', () {
    testWidgets('Thermocouple: tabel standar & UUT, kotaknya nggak nyambung', (
      tester,
    ) async {
      await buka(tester, 'thermocouple');

      final tabel = find.byType(LembarKerjaTabel);
      expect(tabel, findsNWidgets(2));

      expect(find.text('Pembacaan Standard'), findsOneWidget);
      expect(find.text('Pembacaan UUT'), findsOneWidget);

      // 6 titik saran × 5 pengulangan, tiap tabel.
      final kotakStandar = find.descendant(
        of: tabel.at(0),
        matching: find.byType(TextField),
      );
      final kotakUut = find.descendant(
        of: tabel.at(1),
        matching: find.byType(TextField),
      );

      expect(kotakStandar, findsNWidgets(30));
      expect(kotakUut, findsNWidgets(30));

      // INI penjaganya: ketik di deret standar, deret UUT harus tetap kosong.
      await tester.enterText(kotakStandar.at(0), '49.5');
      await tester.pump();

      expect(tester.widget<TextField>(kotakStandar.at(0)).controller?.text, '49.5');
      expect(
        tester.widget<TextField>(kotakUut.at(0)).controller?.text,
        isEmpty,
        reason: 'Dua tabel ber-`tahap` sama. Tanpa `grup` sebagai pembeda, '
            'keduanya berbagi satu controller dan angka ini muncul di '
            'dua-duanya sekaligus.',
      );
    });

    testWidgets('Termometer Gelas: dua tabel + blok uji titik es', (
      tester,
    ) async {
      await buka(tester, 'thermometer_glass');

      expect(find.byType(LembarKerjaTabel), findsNWidgets(2));
      expect(find.text('2. Pembacaan Standard'), findsOneWidget);
      expect(find.text('3. Pembacaan UUT'), findsOneWidget);

      // Uji titik es itu KOMPONEN budget, bukan catatan — kotaknya wajib ada.
      expect(find.text('Ice Point X1'), findsOneWidget);
      expect(find.text('Ice Point X2'), findsOneWidget);
      expect(find.text('Ice Point X3'), findsOneWidget);

      // Oilbath & tipe pencelupan nentuin angka; dua-duanya wajib kegambar.
      expect(find.text('Oilbath Used'), findsOneWidget);
      expect(find.text('Thermometer Type'), findsOneWidget);
    });

    testWidgets('Thermohygro: EMPAT tabel — dua besaran, masing-masing sepasang', (
      tester,
    ) async {
      await buka(tester, 'thermohygro');

      expect(
        find.byType(LembarKerjaTabel),
        findsNWidgets(4),
        reason: 'Blok suhu (standar + UUT) dan blok kelembapan (standar + UUT).',
      );

      expect(find.text('1. KALIBRASI SUHU (TEMPERATURE)'), findsOneWidget);
      expect(find.text('2. KALIBRASI KELEMBAPAN (HUMIDITY)'), findsOneWidget);
      expect(
        find.text('Pembacaan Standard [CHAMBER BIOBASE]'),
        findsOneWidget,
      );
    });
  });

  group('No. Termokopel', () {
    testWidgets('digambar buat tabel standar Thermocouple saja', (
      tester,
    ) async {
      await buka(tester, 'thermocouple');

      // Satu blok, bukan dua: sisi UUT memakai probe bawaan alat pelanggan —
      // yang justru sedang diukur penyimpangannya.
      expect(find.text('No. Termokopel'), findsOneWidget);
      expect(
        find.text(
          'Type N mulai dari nomor 3; PRT PT100 (RTD) selalu nomor 17.',
        ),
        findsOneWidget,
        reason: 'Aturan penomorannya dari kertas lab, dan tercetak di sana — '
            'jadi ditampilkan apa adanya, bukan dihafal teknisi.',
      );

      // Satu dropdown per set point (6 titik saran).
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsAtLeast(6));
    });

    testWidgets('nggak digambar di lembar yang nggak punya kolomnya', (
      tester,
    ) async {
      await buka(tester, 'thermometer_glass');

      expect(
        find.text('No. Termokopel'),
        findsNothing,
        reason: 'Oilbath cuma punya satu probe acuan terpasang (PRT PT100 '
            'nomor 17) — nggak ada yang bisa dipilih teknisi.',
      );

      await buka(tester, 'thermohygro');
      expect(find.text('No. Termokopel'), findsNothing);
    });
  });
}

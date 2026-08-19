import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Pembacaan yang melesetnya satu orde BOLEH dikirim — sesudah teknisi
/// menyatakan angkanya emang segitu.
///
/// **Kejadian nyata 19 Agt 2026, Viscometer DV-11 (SN 8535682).** Lembar
/// kerjanya nggak bisa dikirim sama sekali: penjaga orde nolak `KIRIM KE
/// ADMIN` lewat snackbar, tanpa jalan lain. Titik 60000 cP di master lab
/// sendiri berisi `631.74.2` — dua titik desimal, angka yang belum dijawab
/// lab (lihat `docs/pertanyaan-lab-viscometer.md` §1) — dan begitu teknisi
/// ngetik ulang jadi `631.74`, rasionya ke titik 59003 cuma 0,0107 dan
/// lembarnya terkunci mati.
///
/// Penjaganya BUKAN aturan metrologi: alat yang lagi dikalibrasi emang boleh
/// baca jauh melenceng — rusak, spindle/RPM nggak cocok, atau nol karena
/// torsinya nggak nyampe. Menahan mati bikin satu-satunya jalan keluar
/// teknisi adalah ngarang angka biar lolos, persis kebalikan dari yang mau
/// dijaga. Jadi: ditanyain sekali, bisa diteruskan.
void main() {
  // Lembar kerjanya panjang; viewport dibikin besar biar seluruh formulir
  // ke-build sekaligus dan index kotaknya stabil.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(MockLembarKerjaService service, {String profil = 'ph_meter'}) => ProviderScope(
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
      worksheetScanServiceProvider.overrideWithValue(
        MockWorksheetScanService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LembarKerjaScreen(profil: profil),
    ),
  );

  /// `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer
  /// kayak gitu nggak ngejadwalin frame — `pumpAndSettle` doang balik duluan.
  Future<void> muat(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> siapkanLembar(WidgetTester tester) async {
    await tester.tap(find.text('Pilih alat'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('pH Meter Mettler Toledo · B628755900').last,
    );
    await tester.pumpAndSettle();

    final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  /// Titik pH 4, Repeat 1: pembacaan `0.40` — tepat 10× di bawah nominalnya,
  /// jadi kena penjaga orde. Suhunya diisi biar yang ketangkep bener-bener
  /// penjaga orde, bukan penjaga suhu (yang emang MASIH nahan mati).
  Future<void> isiPembacaanMelesetSeorde(WidgetTester tester) async {
    final tabelAfter = find.ancestor(
      of: find.text('After adjustment Reading'),
      matching: find.byType(Column),
    );
    final kotak = find.descendant(
      of: tabelAfter.first,
      matching: find.byType(TextField),
    );

    await tester.enterText(kotak.at(0), '0.40');
    await tester.enterText(kotak.at(1), '22.2');
    await tester.pumpAndSettle();
  }

  /// Lembar kerja Viscometer yang ASLI — bentuknya dari backend, dua tabel,
  /// tiga titik (99,65 / 1018 / 59003 cP), bukan lembar pH yang dipakai test di
  /// bawah.
  ///
  /// Bedanya menentukan: penjaga orde mengadu pembacaan ke `titik_ukur` BARIS
  /// ITU, dan titik viscometer angkanya besar-besar. `631.74` di baris 59003 cP
  /// rasionya 0,0107 — persis kasus 19 Agt 2026 yang bikin lembarnya kekunci
  /// mati, dan persis angka yang muncul waktu sel master `631.74.2` diketik
  /// ulang teknisi.
  testWidgets('lembar Viscometer asli: 631.74 di titik 59003 bisa nembus', (
    tester,
  ) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service, profil: 'viscometer'));
    await siapkanLembar(tester);

    final tabelAfter = find.ancestor(
      of: find.text('After Adjustment'),
      matching: find.byType(Column),
    );
    final kotak = find.descendant(
      of: tabelAfter.first,
      matching: find.byType(TextField),
    );

    // Baris ketiga (titik 59003 cP), Repeat 1. Tiap Repeat dua sub-kolom
    // (cP + °C) dan tiap baris 5 Repeat, jadi baris ke-3 mulai di indeks 20.
    await tester.enterText(kotak.at(20), '631.74');
    await tester.enterText(kotak.at(21), '24.6');
    await tester.pumpAndSettle();

    await tester.tap(find.text('KIRIM KE ADMIN'));
    await tester.pumpAndSettle();

    expect(find.text('Angkanya kelihatan nggak wajar'), findsOneWidget);
    expect(find.textContaining('melesetnya lebih dari 10×'), findsOneWidget);

    await tester.tap(find.text('Angkanya emang segitu — kirim'));
    await tester.pumpAndSettle();

    final konfirmasi = find.text('Kirim sekarang');
    if (konfirmasi.evaluate().isNotEmpty) {
      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
    }

    expect(service.jumlahKirim, 1, reason: 'lembar viscometer nggak jadi kekirim');

    // Angkanya nyampe APA ADANYA — nggak dibuletin, nggak dibuang.
    final measurements =
        service.payloadTerakhir!['measurements'] as List<dynamic>;
    final titik = measurements.firstWhere(
      (m) => (m as Map)['titik_ukur'] == 59003,
    ) as Map<String, dynamic>;

    expect((titik['pembacaan'] as List<dynamic>).first, 631.74);
  });

  testWidgets('peringatannya dialog, bukan penolakan diam-diam', (
    tester,
  ) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));
    await siapkanLembar(tester);
    await isiPembacaanMelesetSeorde(tester);

    await tester.tap(find.text('KIRIM KE ADMIN'));
    await tester.pumpAndSettle();

    expect(find.text('Angkanya kelihatan nggak wajar'), findsOneWidget);
    expect(find.textContaining('melesetnya lebih dari 10×'), findsOneWidget);
  });

  testWidgets('"Periksa lagi" balik ke formulir, nggak ada yang kekirim', (
    tester,
  ) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));
    await siapkanLembar(tester);
    await isiPembacaanMelesetSeorde(tester);

    await tester.tap(find.text('KIRIM KE ADMIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periksa lagi'));
    await tester.pumpAndSettle();

    expect(service.jumlahKirim, 0);
    expect(find.text('KIRIM KE ADMIN'), findsOneWidget);
  });

  testWidgets('"emang segitu" nembus sampai terkirim, angkanya utuh', (
    tester,
  ) async {
    perbesarViewport(tester);
    final service = MockLembarKerjaService();
    await muat(tester, app(service));
    await siapkanLembar(tester);
    await isiPembacaanMelesetSeorde(tester);

    await tester.tap(find.text('KIRIM KE ADMIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angkanya emang segitu — kirim'));
    await tester.pumpAndSettle();

    // Sesudah peringatan orde, dialog ringkasan angka yang biasa tetap muncul.
    await tester.tap(find.text('Kirim sekarang'));
    await tester.pumpAndSettle();

    expect(service.jumlahKirim, 1);

    final measurements =
        service.payloadTerakhir!['measurements'] as List<dynamic>;
    final titik4 =
        measurements.firstWhere((m) => (m as Map)['titik_ukur'] == 4.00)
            as Map<String, dynamic>;

    // Yang penting: angkanya nyampe APA ADANYA. Penjaga ini nggak boleh
    // diam-diam mbenerin, mbuletin, atau ngebuang pembacaannya.
    expect((titik4['pembacaan'] as List<dynamic>).first, 0.40);
  });
}

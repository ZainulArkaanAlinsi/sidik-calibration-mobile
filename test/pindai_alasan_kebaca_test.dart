import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
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

/// **Alasan pindai ditahan harus jadi KALIMAT, bukan kode internal.**
///
/// ## Yang kejadian di APK v1.0.43
///
/// Begitu UI pindai dinyalain lagi, tombolnya muncul di semua lembar bertabel.
/// Lembar yang belum punya berkas geometri — 11 dari 17, termasuk SELURUH
/// lembar suhu — tombolnya digambar MATI berikut alasannya. Itu memang
/// dirancang begitu.
///
/// Tapi yang tertulis di alasannya kode mentah dari server:
///
///     Belum bisa dipindai: geometri_belum_diukur
///
/// Itu bukan kalimat, dan yang membacanya teknisi lab. Dari matanya, lembar
/// yang sepenuhnya sah kelihatan seperti aplikasi yang rusak — di sebelas
/// lembar sekaligus.
///
/// ## Yang dijaga di sini
///
/// Bukan cuma "ada terjemahannya". Tiap alasan punya TINDAKAN yang beda, dan
/// kode mentahnya nggak menyiratkan satu pun:
///
///  - belum diukur -> nunggu berkas geometri;
///  - belum diverifikasi -> nunggu satu foto lembar cetak;
///  - kurang kotak -> berkasnya ada tapi nggak lengkap.
///
/// Ketiganya harus bilang apa yang harus dilakukan teknisi SEKARANG: isi
/// manual. Tanpa itu, teknisi berdiri di depan alat sambil menebak apakah dia
/// boleh lanjut.
void main() {
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(WorksheetTemplate template) => ProviderScope(
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
      worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
      worksheetTemplateProvider.overrideWith((ref, arg) async => template),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'ph_meter'),
    ),
  );

  Future<void> buka(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  WorksheetTemplate belumSiap(String alasan) => WorksheetTemplate(
    templateId: 'ph_meter',
    versi: 1,
    kodeDokumen: 'SIDIK-FM-CAL-0501_Rev.4',
    judul: 'Calibration Work Sheet - pH Meter',
    tabel: const [],
    sel: const {},
    siapPindai: false,
    alasanBelumSiap: alasan,
  );

  testWidgets('`geometri_belum_diukur` nggak bocor mentah ke layar', (
    tester,
  ) async {
    perbesarViewport(tester);
    await buka(tester, app(belumSiap('geometri_belum_diukur')));

    // Ini yang dibaca teknisi di v1.0.43, dan itu bukan kalimat.
    expect(
      find.textContaining('geometri_belum_diukur'),
      findsNothing,
      reason: 'kode internal servernya kecetak apa adanya ke teknisi',
    );

    // Dan penggantinya harus nyebut apa yang dia lakukan SEKARANG.
    expect(find.textContaining('Isi manual'), findsOneWidget);
  });

  testWidgets('`geometri_belum_diverifikasi` juga', (tester) async {
    perbesarViewport(tester);
    await buka(tester, app(belumSiap('geometri_belum_diverifikasi')));

    expect(find.textContaining('geometri_belum_diverifikasi'), findsNothing);
    expect(find.textContaining('foto nyata'), findsOneWidget);
  });

  testWidgets('`geometri_kurang_7_sel` nyebut angkanya', (tester) async {
    perbesarViewport(tester);
    await buka(tester, app(belumSiap('geometri_kurang_7_sel')));

    expect(find.textContaining('geometri_kurang'), findsNothing);

    // Angkanya ikut, karena "ada beberapa yang kurang" dan "ada 7 yang kurang"
    // beda artinya buat yang mau membetulkan berkasnya.
    expect(find.textContaining('7 kotak'), findsOneWidget);
  });

  testWidgets('kode yang NGGAK dikenal tetap ditampilkan apa adanya', (
    tester,
  ) async {
    perbesarViewport(tester);
    await buka(tester, app(belumSiap('alasan_yang_belum_pernah_ada')));

    // Sengaja: kode baru dari server nggak boleh berubah jadi kalimat kosong
    // yang menyembunyikan keadaan yang belum pernah ditemui. Lebih baik jelek
    // tapi kelihatan daripada rapi tapi bohong.
    expect(find.textContaining('alasan_yang_belum_pernah_ada'), findsOneWidget);
  });
}

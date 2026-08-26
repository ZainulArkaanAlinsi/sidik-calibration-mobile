import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// **Peringatan "sertifikat kadaluarsa" sampai ke mata teknisi, utuh.**
///
/// ## Yang rusak sebelum ini
///
/// Ketiga dropdown standar merangkai peringatannya jadi buntut nama:
///
///     '${s.nama} (${l10n.lkStandarKadaluarsa})'
///
/// Di lembar Refractometer & Gas Detector kolomnya 772 dp dan teks itu minta
/// 953. Yang jatuh di luar 772 justru buntutnya — jadi yang kebaca:
///
///     Temperature Calibrator Constant 40T (sertifik…
///
/// Nama kalibratornya lengkap, peringatannya hilang. Nol error di mana pun.
///
/// Kenapa ini mahal: `Constant 40T` sertifikatnya **beneran** lewat 28 Agustus
/// 2025. Item-nya memang `enabled: false` jadi nggak bisa kepilih, tapi teknisi
/// yang nggak nemu kalibrator yang biasa dia pakai butuh tahu ALASANNYA —
/// kalau nggak, yang dia simpulkan "aplikasinya rusak", bukan "sertifikatnya
/// mesti diperpanjang".
///
/// ## Kenapa diuji dengan MEMBUKA menunya
///
/// Item dropdown yang tertutup hidup di `IndexedStack` — kegambar, keukur, tapi
/// nggak kelihatan. Menegakkan lewat keadaan tertutup doang bakal hijau tanpa
/// pernah menyentuh yang beneran dibaca orang.
void main() {
  Future<void> bukaLembar(WidgetTester tester, String profil) async {
    tester.view.physicalSize = const Size(900, 24000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pindaiLembarAktifProvider.overrideWithValue(false),
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  /// Semua paragraf ONSTAGE yang teksnya memuat [potongan].
  List<RenderParagraph> paragrafOnstage(WidgetTester tester, String potongan) {
    final hasil = <RenderParagraph>[];

    for (final el in find
        .textContaining(potongan, skipOffstage: true)
        .evaluate()) {
      final ro = el.renderObject;
      if (ro is RenderParagraph) hasil.add(ro);
    }

    return hasil;
  }

  for (final profil in const ['refractometer', 'gas_detector']) {
    testWidgets('$profil: alasan standar dimatiin kebaca utuh di daftar', (
      tester,
    ) async {
      await bukaLembar(tester, profil);

      final dropdown = find.byType(DropdownButtonFormField<int>);
      expect(
        dropdown,
        findsAtLeast(1),
        reason: 'Lembar ini mestinya punya dropdown standar.',
      );

      // Dibuka SATU-SATU, bukan cuma yang pertama. Di Gas Detector dropdown
      // paling atas isinya botol gas Rigas — kalibrator suhu yang kadaluarsa
      // itu ada di dropdown lain. Menguji yang pertama doang bikin test ini
      // hijau di lembar yang justru belum kesentuh.
      var ketemuPeringatan = false;
      var ketemuNama = false;

      for (var i = 0; i < dropdown.evaluate().length; i++) {
        await tester.ensureVisible(dropdown.at(i));
        await tester.pumpAndSettle();
        await tester.tap(dropdown.at(i));
        await tester.pumpAndSettle();

        for (final p in paragrafOnstage(tester, 'sertifikat kadaluarsa')) {
          ketemuPeringatan = true;

          expect(
            p.text.toPlainText(),
            'sertifikat kadaluarsa',
            reason: 'Digabung ke nama, peringatannya jadi buntut — dan buntut '
                'itu yang pertama dibuang waktu kolomnya kurang lebar.',
          );
          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: 'Peringatan yang kepotong sama nggak bergunanya dengan '
                'peringatan yang nggak ada.',
          );
        }

        // Nama kalibratornya juga kebaca utuh di daftar — di tombol tertutup
        // dia memang dipangkas satu baris, dan daftar inilah jalan keluarnya.
        for (final p in paragrafOnstage(tester, 'Temperature Calibrator')) {
          ketemuNama = true;

          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: 'Nama "${p.text.toPlainText()}" kepotong di daftar yang '
                'terbuka. Kalau di sini pun terpangkas, nama itu nggak pernah '
                'kebaca utuh di mana pun.',
          );
        }

        // Tutup lagi sebelum buka yang berikutnya.
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
      }

      expect(
        ketemuNama,
        isTrue,
        reason: 'Nggak satu pun dropdown di lembar ini memuat kalibrator suhu '
            '— berarti test-nya nggak pernah menyentuh yang mau dijaga.',
      );
      expect(
        ketemuPeringatan,
        isTrue,
        reason: 'Constant 40T kadaluarsa dan ada di master, jadi alasannya '
            'wajib kegambar di salah satu daftar lembar ini.',
      );
    });
  }
}

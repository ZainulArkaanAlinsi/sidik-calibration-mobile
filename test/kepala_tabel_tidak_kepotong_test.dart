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

/// **Nggak ada satu pun teks di lembar kerja yang kepotong ellipsis.**
///
/// ## Kenapa berkas ini ada
///
/// Kepala tabel dulu digambar tanpa batas baris sama sekali. Waktu lembar suhu
/// masuk membawa judul yang lebih panjang dari jatah 26 dp-nya, batas itu
/// dipasang — tapi dipasang sebagai BAWAAN buat semua sel sekaligus, lengkap
/// dengan `textAlign: center`. Dua-duanya kena ke empat belas lembar lama yang
/// nggak minta apa-apa:
///
/// - `Std Value (λ1)` di Spectrophotometer butuh TIGA baris; dibatasi dua, satu
///   barisnya hilang di balik ellipsis.
/// - Tiap kepala yang membungkus pindah dari rata-kiri jadi rata-tengah.
///
/// Yang menangkapnya golden `lembar-kerja-spectrophotometer.png` — geser 0,15%
/// (4923 px), di atas ambang 0,10%. Dan golden cuma jalan di **macOS CI**:
/// `--update-goldens` sah cuma di sana, jadi di mesin Linux siapa pun bisa
/// mengubah kepala tabel, lihat 1002 test hijau, dan baru tahu rusaknya setelah
/// PR dibuka.
///
/// Berkas ini penjaga yang jalan **di mana saja**. Dia nggak membandingkan
/// piksel — dia nanya satu hal yang nggak butuh baseline: *adakah teks yang
/// kepotong?* Teks kepotong itu informasi yang hilang dari layar teknisi, dan
/// itu benar entah di Linux, macOS, atau HP.
///
/// ## Yang TIDAK dijaga di sini
///
/// Geseran tata letak yang nggak menghilangkan teks (rata-tengah vs rata-kiri)
/// lolos dari sini — itu tetap wilayah golden macOS. Dua penjaga, dua lapis.
void main() {
  // Semua profil yang dilayani `MockLembarKerjaService`, plus `_` yang sengaja
  // jatuh ke pH. Daftarnya ditulis tangan justru supaya menambah alat baru
  // TANPA menambahnya ke sini kelihatan sebagai lembar yang nggak terjaga.
  const semuaProfil = [
    'ph_meter', 'turbidimeter', 'chlorine_meter', 'refractometer',
    'spectrophotometer', 'viscometer', 'do_meter', 'gas_detector', 'tits',
    'thermocouple', 'thermometer_glass', 'thermohygro',
  ];

  // ## Teks yang memang dipangkas, dan itu SAH
  //
  // Dua lembar ini menyisakan satu nama kalibrator yang kepotong di TOMBOL
  // dropdown yang tertutup:
  //
  //     "Temperature Calibrator Yokogawa CA 150 Handy Cal"
  //      lebar 772, butuh 775 — lebih panjang tiga piksel
  //
  // Dibiarkan, dan bedanya sama kasus yang diberantas berkas ini itu tegas:
  // **teks ini punya jalan lain.** Tombol tertutup satu baris itu wajar buat
  // form field, dan begitu daftarnya dibuka namanya kegambar dua baris, utuh —
  // dijaga `standar_kadaluarsa_kelihatan_test.dart`.
  //
  // Yang dulu ada di sini dan sekarang HILANG dari daftar: peringatan
  // "(sertifikat kadaluarsa)" yang nempel di buntut nama dan selalu kebuang
  // duluan. Itu nggak punya jalan lain — dipotong berarti teknisi nggak pernah
  // tahu kenapa kalibratornya nggak bisa dipilih. Sekarang peringatannya berdiri
  // di barisnya sendiri, jadi panjang nama nggak lagi menentukan dia kebaca
  // atau nggak.
  //
  // Didaftar EKSPLISIT, bukan didiamkan: kalau jumlahnya berubah, test-nya
  // gagal dan angkanya wajib ditinjau ulang.
  const dipangkasTapiSah = {
    'refractometer': 2,
    'gas_detector': 4,
  };

  for (final profil in semuaProfil) {
    testWidgets('$profil: nggak ada teks yang kepotong', (tester) async {
      // Ditinggikan supaya `ListView` nge-build SELURUH lembar — sel yang nggak
      // pernah dibangun nggak bisa ketahuan kepotong. Lebarnya 900: di bawah
      // ambang dua kolom (1100), jadi yang diuji lebar sel tersempit yang
      // dipakai lembar ini.
      tester.view.physicalSize = const Size(900, 24000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
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
      ));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final kepotong = <String>[];

      void jelajah(RenderObject o) {
        if (o is RenderParagraph && o.didExceedMaxLines) {
          kepotong.add(
            '"${o.text.toPlainText()}" '
            '(lebar ${o.size.width.toStringAsFixed(0)}, '
            'butuh ${o.getMaxIntrinsicWidth(double.infinity).toStringAsFixed(0)})',
          );
        }
        o.visitChildren(jelajah);
      }

      jelajah(tester.binding.rootElement!.renderObject!);

      expect(
        kepotong.length,
        dipangkasTapiSah[profil] ?? 0,
        reason:
            'Teks berikut kepotong di lembar `$profil`. Yang kepotong itu '
            'informasi yang teknisi butuhkan, bukan hiasan — pendekin '
            'teksnya di profil server, jangan lebarin batas barisnya. '
            'Kalau jumlahnya justru BERKURANG, perbarui `$profil` di '
            '`dipangkasTapiSah`:\n'
            '  ${kepotong.join('\n  ')}',
      );
    });
  }
}

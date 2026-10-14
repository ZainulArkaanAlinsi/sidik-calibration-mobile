import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Golden layar Workbook Alat "Asli Excel" (Tahap A), dibuat di Windows
/// (platform acuan — `test/flutter_test_config.dart`): lembar
/// `PERHITUNGAN U95%` Micrometer 0-25mm dari `MockWorkbookService` — freeze
/// C5, gabungan melintasi freeze, kolom J & baris 2–3 tersembunyi, kepala
/// kuning bergaris & rata tengah-vertikal, AC4 dibungkus, teks panjang
/// B8/B14–B17 MELUBER ke kanan, angka General yang tak muat jadi `####`,
/// X17 bergaris atas tipis + bawah ganda.
///
/// - meja 1280 × 800: inspektur terbuka di samping (bawaan lanskap), K6
///   aktif;
/// - tablet lanskap 1138 × 711: sama, layar penuh (tanpa rail/bilah
///   cangkang — satu bilah);
/// - tablet potret 711 × 1138: inspektur tertutup (bawaan potret), B14
///   aktif.
///
/// Yang dinilai mata: posisi (bilah rumus selebar layar, tab lembar di
/// bawah, zoom di kanan bilah status), luberan teks & garis kisi seperti
/// Excel, kontras gaya sumber di tema gelap.
///
/// Perbarui (di Windows): `flutter test test/grid_golden_test.dart
/// --update-goldens`, lalu PERIKSA gambarnya.
void main() {
  setUpAll(muatFontStudio);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (nama, ukuran, meja, sel) in const [
    ('workbook-grid-1280', Size(1280, 800), true, 'K6'),
    ('workbook-tablet-1138', Size(1138, 711), false, 'K6'),
    ('workbook-tablet-711', Size(711, 1138), false, 'B14'),
  ]) {
    for (final (tema, mode) in const [
      ('terang', ThemeMode.light),
      ('gelap', ThemeMode.dark),
    ]) {
      testWidgets(
        '$nama — $tema',
        (tester) async {
          await pasangUkuran(tester, ukuran);
          await tester.pumpWidget(
            studioUji(
              meja: meja,
              token: 'mock-token-1',
              izin: const Izin(
                role: UserRole.admin,
                boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
              ),
              workbook: MockWorkbookService(),
              tambahan: [
                modeTemaStudioProvider.overrideWith(() => _TemaTetap(mode)),
              ],
            ),
          );
          await tenang(tester);
          await bukaSeksi(tester, SeksiStudio.workbookAlat);
          await tester.tap(
            find.byKey(
              const ValueKey('workbook-${MockWorkbookService.idMicrometer}'),
            ),
          );
          await tenang(tester);
          await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai(sel)!)));
          await tenang(tester);

          expect(
            find.byType(InspekturSelWorkbook),
            meja || ukuran.width > ukuran.height
                ? findsOneWidget
                : findsNothing,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$nama-$tema.png'),
          );
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}

class _TemaTetap extends ModeTemaStudio {
  _TemaTetap(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}

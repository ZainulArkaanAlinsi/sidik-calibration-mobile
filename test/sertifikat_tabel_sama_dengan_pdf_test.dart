import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/angka.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';

/// Tabel **Calibration Report** di pratinjau HARUS sama persis dengan yang
/// dicetak di PDF & Excel.
///
/// ## Kenapa tes ini ada
///
/// 6 Agt 2026 dilaporin: sertifikat chlorine `CAL/2026/08/0009` nampilin `0.091`
/// di layar tapi `0,09` di PDF-nya. Layar ini justru dipakai admin buat
/// nyocokin sebelum sertifikat dikirim ke pelanggan — beda satu digit bikin
/// nggak ada yang tahu mana yang resmi. Layarnya nggak punya widget test sama
/// sekali waktu itu, jadi bedanya nggak ketahuan siapa-siapa.
///
/// ## Angka acuannya
///
/// Dari dua sertifikat lab ASLI, bukan karangan:
///
/// - pH `012-CAL-524` — U95 mentah `0,0211` tercetak **`0,02`**
/// - Chlorine `CAL/2026/08/0009` — U95 mentah `0,091` tercetak **`0,09`**
///
/// Dua-duanya nunjukin U95 ngikut desimal alat, sama kayak tiga kolom lain.
void main() {
  CertificateDetail sertifikatChlorine() => CertificateDetail(
    id: 13,
    nomor: 'CAL/2026/08/0009',
    status: 'terbit',
    snapshot: CertificateSnapshot.fromJson(const {
      'desimal': 2,
      'satuan': 'mg/L',
      'header': {'certificate_number': 'CAL/2026/08/0009'},
      // Nilai mentah dari snapshot beneran di database — sengaja LEBIH PANJANG
      // dari resolusi alatnya, karena di situlah bedanya kelihatan.
      'hasil': [
        {
          'titik_ke': 1,
          'standard_value': 1.74,
          'unit_under_test': 1.758,
          'correction': -0.018,
          'u95': 0.091,
          'desimal': 2,
          'remark': 'Free Chlorine',
        },
        {
          'titik_ke': 2,
          'standard_value': 1.83,
          'unit_under_test': 1.86,
          'correction': -0.03,
          'u95': 0.08,
          'desimal': 2,
          'remark': 'Total Chlorine',
        },
      ],
      'catatan': <String>[],
      'standar_digunakan': <Map<String, dynamic>>[],
      'footer': <String, dynamic>{},
    }),
  );

  Future<void> pasang(WidgetTester tester, CertificateDetail sert) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          certificateDetailProvider(sert.id).overrideWith((ref) async => sert),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SertifikatScreen(certificateId: sert.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('formatSertifikat — padanan Angka::id di backend', () {
    test('dibulatkan ke desimal alat, koma sebagai pemisah', () {
      expect(formatSertifikat(1.758, 2), '1,76');
      expect(formatSertifikat(0.091, 2), '0,09');
      expect(formatSertifikat(0.08, 2), '0,08');
      expect(formatSertifikat(-0.018, 2), '-0,02');
      expect(formatSertifikat(1.74, 2), '1,74');
    });

    test('desimal 0 nggak nyisain koma menggantung', () {
      expect(formatSertifikat(101.0, 0), '101');
      expect(formatSertifikat(-1.0, 0), '-1');
    });

    test('ribuan TANPA pemisah, kayak di master', () {
      // Sempat dipatok `1.000`/`1.001` di sini — ditulis dari kebiasaan format
      // Indonesia, bukan dibaca dari kertasnya. Master Turbidimeter
      // `0189-CAL-624` nulis `1000` & `1001` polos, dan di dokumen yang komanya
      // dipakai buat desimal, titik ribuan justru kebaca ambigu.
      expect(formatSertifikat(1000, 0), '1000');
      expect(formatSertifikat(1001, 0), '1001');
      expect(formatSertifikat(1234.5, 1), '1234,5');
    });

    test('Turbidimeter: tiga titik, tiga resolusi berbeda — sama kayak master', () {
      // Disalin dari master `0189-CAL-624` yang diadu langsung 10 Agt 2026:
      //   1    | 1,00  | -0,00 | 0,04
      //   100  | 100,0 | -0,0  | 3,1
      //   1000 | 1001  | -1    | 22
      // Tiga baris, tiga resolusi (0,01 / 0,1 / 1 NTU). Perhatiin baris kedua:
      // 1 desimal, BUKAN 0 — titik 100 NTU masih di pita 0,1.
      expect(formatNilaiStandar(1.0, 2), '1');
      expect(formatSertifikat(1.004, 2), '1,00');
      expect(formatSertifikat(-0.004, 2), '-0,00');
      expect(formatSertifikat(0.041, 2), '0,04');

      expect(formatNilaiStandar(100.0, 1), '100');
      expect(formatSertifikat(100.02, 1), '100,0');
      expect(formatSertifikat(-0.02, 1), '-0,0');
      expect(formatSertifikat(3.1, 1), '3,1');

      expect(formatNilaiStandar(1000.0, 0), '1000');
      expect(formatSertifikat(1000.6, 0), '1001');
      expect(formatSertifikat(-0.6, 0), '-1');
      expect(formatSertifikat(22.0, 0), '22');
    });

    test('nol negatif hasil pembulatan TETAP bawa tanda minus', () {
      // Kebalikan dari yang dipatok di sini sebelumnya ("orang ngira ada
      // koreksi negatif padahal nggak ada"). Master nulis `-0,00` & `-0,0`, dan
      // tandanya bukan hiasan: dia yang bilang alatnya baca DI ATAS standar.
      expect(formatSertifikat(-0.004, 2), '-0,00');
      expect(formatSertifikat(-0.02, 1), '-0,0');
    });
  });

  group('tabel Calibration Report', () {
    testWidgets('U95 ngikut desimal alat — `0,09`, BUKAN `0.091`',
        (tester) async {
      await pasang(tester, sertifikatChlorine());

      expect(find.text('0,09'), findsOneWidget);
      expect(find.text('0,08'), findsOneWidget);

      // Ini bentuk bug-nya: nilai mentah bocor ke layar.
      expect(find.text('0.091'), findsNothing);
      expect(find.text('0.080'), findsNothing);
    });

    testWidgets('semua kolom pakai koma, sama kayak PDF', (tester) async {
      await pasang(tester, sertifikatChlorine());

      expect(find.text('1,74'), findsOneWidget);
      expect(find.text('1,76'), findsOneWidget); // 1,758 dibulatkan
      expect(find.text('-0,02'), findsOneWidget); // -0,018 dibulatkan

      // Separator titik itu gaya lembar perhitungan, bukan sertifikat.
      expect(find.text('1.74'), findsNothing);
      expect(find.text('1.758'), findsNothing);
    });

    testWidgets('kolom Remark ikut kerender', (tester) async {
      await pasang(tester, sertifikatChlorine());

      expect(find.text('Remark'), findsOneWidget);
      expect(find.text('Free Chlorine'), findsOneWidget);
      expect(find.text('Total Chlorine'), findsOneWidget);
    });

    testWidgets('alat tanpa remark: kolomnya NGGAK dirender sama sekali',
        (tester) async {
      // Sama aturannya kayak `pdf.blade.php`. Kolom berisi strip bikin tabel di
      // layar punya jumlah kolom beda dari PDF buat sertifikat yang sama.
      final tanpaRemark = CertificateDetail(
        id: 2,
        nomor: '012-CAL-524',
        status: 'terbit',
        snapshot: CertificateSnapshot.fromJson(const {
          'desimal': 2,
          'header': {'certificate_number': '012-CAL-524'},
          'hasil': [
            {
              'titik_ke': 2,
              'standard_value': 6.9889072,
              'unit_under_test': 7.004,
              'correction': -0.0150928,
              'u95': 0.0211089499,
              'desimal': 2,
            },
          ],
          'catatan': <String>[],
          'standar_digunakan': <Map<String, dynamic>>[],
          'footer': <String, dynamic>{},
        }),
      );

      await pasang(tester, tanpaRemark);

      expect(find.text('Remark'), findsNothing);

      // Baris asli 012-CAL-524: `6,99` · `7,00` · `-0,02` · `0,02`.
      expect(find.text('6,99'), findsOneWidget);
      expect(find.text('7,00'), findsOneWidget);
      expect(find.text('-0,02'), findsOneWidget);
      expect(find.text('0,02'), findsOneWidget);
    });
  });
}

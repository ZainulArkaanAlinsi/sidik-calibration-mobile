import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/utils/angka.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/history/certificate_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar riwayat & sertifikat buat alat yang titiknya BERKELOMPOK dan nggak
/// divonis PASS/FAIL.
///
/// Dua hal yang dijaga: kelompok dibaca dari `remark` yang dikirim backend
/// (bukan ditebak dari besar angkanya — rentang Holmium 283–641 nm & Didynium
/// 474–810 nm tumpang tindih 167 nm), dan `keputusan: null` tampil sebagai
/// keadaan ketiga, bukan jatuh ke badge hijau LULUS.
void main() {
  /// Snapshot ASLI sertifikat `CAL/2026/08/0039`, hasil alur penuh yang beneran
  /// dijalanin ke backend lokal 13 Agt 2026: lembar kerja dikirim pakai bentuk
  /// payload mobile → admin approve → sertifikat terbit → PDF keunduh
  /// (1,3 MB, `%PDF`).
  ///
  /// Yang dijaga di sini cuma satu: **mobile bisa baca yang backend bekukan.**
  /// Angka-angkanya nggak dihitung ulang di sini dan nggak boleh dibetulin dari
  /// sisi layar — kalau beda, yang salah pemetaan datanya.
  group('snapshot sertifikat asli', () {
    test('tiga kelompok kebaca, U95-nya kembar per kelompok', () {
      final snapshot = CertificateSnapshot.fromJson(_snapshotAsli);

      expect(snapshot.hasil, hasLength(3));
      expect(snapshot.adaRemark, isTrue);
      // Alat ini nggak divonis — `meta.keputusan` null, dan itu keadaan yang
      // sah, bukan "belum diputusin".
      expect(snapshot.keputusan, isNull);

      final holmium = snapshot.hasil[0];

      expect(holmium.remark, 'Wave Length ( λ ) - Filter Holmium');
      expect(holmium.u95, 0.43255708);
      expect(holmium.standardValue, 279.6);
      expect(holmium.unitUnderTest, 280.0);
      expect(holmium.correction, -0.4);
      expect(holmium.desimal, 2);
      expect(holmium.satuan, 'nm');
      expect(holmium.tandaNol, isTrue);

      // Satuan & desimal dibekukan PER TITIK: satu lembar ini nyampur nm
      // (2 desimal) dan %T (3 desimal), jadi `desimal` level snapshot (2) nggak
      // bisa jawab dua-duanya.
      final transmitan = snapshot.hasil[2];

      expect(transmitan.satuan, '%T');
      expect(transmitan.desimal, 3);
      expect(transmitan.remark, 'Accuracy %T and Linierity at λ = 560nm');
      expect(transmitan.u95, 0.5);
    });

    test('angka dicetak persis kayak PDF-nya', () {
      final snapshot = CertificateSnapshot.fromJson(_snapshotAsli);
      final holmium = snapshot.hasil[0];
      final transmitan = snapshot.hasil[2];

      final d = snapshot.desimal;

      expect(formatNilaiStandar(holmium.standardValue, holmium.desimalEfektif(d)), '279,6');
      expect(formatSertifikat(holmium.unitUnderTest, holmium.desimalEfektif(d)), '280,00');
      expect(formatSertifikat(holmium.correction, holmium.desimalEfektif(d)), '-0,40');

      // Nol belakang %T DIPERTAHANKAN — `9,665` bukan `9,67`, dan itu yang
      // bikin `desimal` per titik harus dipakai, bukan angka level snapshot.
      expect(formatSertifikat(transmitan.unitUnderTest, transmitan.desimalEfektif(d)), '9,665');
      expect(formatSertifikat(transmitan.correction, transmitan.desimalEfektif(d)), '0,235');
    });

    test('baris U95 %T dicetak dua desimal, kolom lain tetap tiga', () {
      final snapshot = CertificateSnapshot.fromJson(_snapshotAsli);
      final transmitan = snapshot.hasil[2];
      final d = snapshot.desimal;

      // Master nulis `0,50 %T` di baris U95, tapi `9,665` di kolom UUT — dua
      // angka, dua format, satu tabel. Yang nentuin dokumen resminya.
      expect(transmitan.desimal, 3);
      expect(transmitan.desimalU95, 2);
      expect(formatSertifikat(transmitan.u95, transmitan.desimalU95!), '0,50');
      expect(
        formatSertifikat(transmitan.unitUnderTest, transmitan.desimalEfektif(d)),
        '9,665',
      );
    });
  });

  group('layar detail sesi', () {
    /// Layar ini yang dipakai admin sebelum nerbitin sertifikat, dan dulu cuma
    /// tumpukan kartu setinggi ±18 baris PER TITIK. Buat alat 24 titik itu
    /// nyaris dua puluh layar scroll, tanpa satu tempat pun yang nunjukin hasil
    /// sesi secara utuh.
    testWidgets('tiap kelompok dapat tabel ringkasan', (tester) async {
      await _bukaDetail(tester);

      expect(find.text('Wave Length ( λ ) - Filter Holmium'), findsOneWidget);
      expect(find.text('Wave Length ( λ ) - Filter Didynium'), findsOneWidget);

      // Angkanya sama persis sama yang kecetak di sertifikat — satu jalur
      // formatter & desimal per titik.
      expect(find.text('279,6'), findsWidgets);
      expect(find.text('280,00'), findsWidgets);
      expect(find.text('-0,40'), findsWidgets);
      expect(find.text('0,43'), findsWidgets);
    });

    /// Rantai hitungnya kelihatan, berikut rumus Excel-nya — tanpa itu, `k =
    /// 3,18` muncul tanpa asal-usul dan satu-satunya cara ngecek adalah buka
    /// master Excel di laptop lain.
    testWidgets('proses hitung tampil lengkap sama rumusnya', (tester) async {
      await _bukaDetail(tester);

      expect(find.text('PROSES HITUNG'), findsWidgets);
      expect(find.text('=AVERAGE(X1:X3)'), findsWidgets);
      expect(find.text('=STDEV.S(X1:X3)'), findsWidgets);
      expect(find.text('=SQRT(A² + B²)'), findsWidgets);
      expect(find.text('=TINV(0,05; veff)'), findsWidgets);
      expect(find.text('= uc × k'), findsWidgets);

      // Angkanya dari server, bukan dihitung layar — dan itu ditulis di
      // bawahnya biar nggak ada yang ngira HP-nya ikut ngitung.
      expect(
        find.textContaining('angkanya dihitung server'),
        findsWidgets,
      );

      // veff ikut ditampilin: dia yang nentuin k lewat TINV.
      //
      // Separator TITIK, bukan koma: blok proses hitung itu angka KERJA, satu
      // gaya sama lembar perhitungan. Yang berkoma cuma tabel ringkasan di
      // atasnya, karena itu angka yang bakal kecetak di sertifikat.
      expect(find.text('3.4643'), findsOneWidget);
    });

    /// Alat tanpa batas keberterimaan nggak punya baris toleransi — `± 0,0000`
    /// di situ kebaca kayak batasnya nol, dan itu kebalikan dari "nggak
    /// dinilai".
    testWidgets('titik tanpa vonis nggak nampilin baris toleransi', (
      tester,
    ) async {
      await _bukaDetail(tester);

      expect(find.text('TANPA VONIS'), findsWidgets);
      expect(find.textContaining('± 0,0000'), findsNothing);
    });
  });

  group('layar sertifikat', () {
    testWidgets('sesi tanpa vonis nggak dibadge PASS', (tester) async {
      await _bukaSertifikat(tester);

      // `keputusan: null` = alat ini emang nggak dinilai lulus/gagal. Waktu
      // badge-nya masih `== FAIL ? FAIL : PASS`, sesi Spectrophotometer
      // kebaca "LULUS" di layar sertifikat — dokumen yang dipegang pelanggan.
      expect(find.text('LULUS'), findsNothing);
      expect(find.text('Tanpa PASS/FAIL'), findsOneWidget);
    });

    testWidgets('tabel laporan misahin kelompok lewat kolom Remark', (
      tester,
    ) async {
      await _bukaSertifikat(tester);

      expect(find.text('Remark'), findsOneWidget);
      expect(find.text('Wave Length ( λ ) - Filter Holmium'), findsOneWidget);
      expect(find.text('Wave Length ( λ ) - Filter Didynium'), findsOneWidget);

      // Dua titik, U95 beda, dan yang bilang punya siapa cuma kolom itu:
      // 513,7 nm kelihatan kayak Holmium (283–641) padahal dia Didynium.
      expect(find.text('0,43'), findsOneWidget);
      expect(find.text('0,40'), findsOneWidget);
    });
  });
}

Future<void> _bukaSertifikat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_HistorySpectro()),
        approvalServiceProvider.overrideWithValue(MockApprovalService()),
        pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CertificateScreen(calibrationId: 58),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Sesi Spectrophotometer di layar riwayat/sertifikat — dua titik dari dua
/// kelompok yang beda, dipotong dari respons asli `GET /api/calibrations/58`.
class _HistorySpectro extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 58,
        'nomor_sesi': 'DEMO-SPECTRO-LDC',
        'tanggal_kalibrasi': '2023-07-21T00:00:00.000Z',
        'status': 'disetujui',
        'desimal': 2,
        'certificate_id': 58,
        'equipment': {'nama_alat': 'Spectrophotometer'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        // Alat ini nggak punya batas keberterimaan — sesinya pun nggak divonis.
        'hasil': {'keputusan': null},
        'titik': [
          {
            'titik_ke': 1,
            'titik_ukur': 279.6,
            'satuan': 'nm',
            'desimal': 2,
            'remark': 'Wave Length ( λ ) - Filter Holmium',
            'rata_rata': 280.0,
            'koreksi': -0.4,
            'error': 0.4,
            'standar_deviasi': 0.0,
            'jumlah_pengulangan': 3,
            'type_a': 0.11844666,
            'type_b': 0.06666744,
            'ketidakpastian_gabungan': 0.13591968,
            'derajat_kebebasan_efektif': 3.46426187,
            'ketidakpastian_diperluas': 0.43255708,
            'faktor_cakupan_k': 3.18244631,
            'keputusan': null,
            'toleransi': null,
            'tanda_nol': true,
          },
          {
            'titik_ke': 11,
            'titik_ukur': 513.7,
            'satuan': 'nm',
            'desimal': 2,
            'remark': 'Wave Length ( λ ) - Filter Didynium',
            'rata_rata': 514.2,
            'koreksi': -0.5,
            'jumlah_pengulangan': 3,
            'ketidakpastian_diperluas': 0.4,
            'faktor_cakupan_k': 2.36462425,
            'keputusan': null,
            'toleransi': null,
            'tanda_nol': true,
          },
        ],
      });
}


/// Tiga baris dari snapshot sertifikat `CAL/2026/08/0039` — satu per kelompok,
/// disalin apa adanya dari respons `GET /api/certificates/45`.
const _snapshotAsli = <String, dynamic>{
  'satuan': 'nm',
  'desimal': 2,
  'meta': {'keputusan': null},
  'hasil': [
    {
      'titik_ke': 1,
      'standard_value': 279.6,
      'unit_under_test': 280,
      'correction': -0.4,
      'u95': 0.43255708,
      'satuan': 'nm',
      'desimal': 2,
      'tanda_nol': true,
      'remark': 'Wave Length ( λ ) - Filter Holmium',
    },
    {
      'titik_ke': 11,
      'standard_value': 475.2,
      'unit_under_test': 477.90666667,
      'correction': -2.70666667,
      'u95': 0.4,
      'satuan': 'nm',
      'desimal': 2,
      'tanda_nol': true,
      'remark': 'Wave Length ( λ ) - Filter Didynium',
    },
    {
      'titik_ke': 21,
      'standard_value': 9.9,
      'unit_under_test': 9.665,
      'correction': 0.235,
      'u95': 0.5,
      'satuan': '%T',
      'desimal': 3,
      // Baris U95 blok %T dicetak DUA desimal (`0,50`) sementara kolom UUT &
      // Correction pakai tiga (`9,665`) — diadu ke `SERTIFIKAT.csv` master.
      'desimal_u95': 2,
      'tanda_nol': true,
      'remark': 'Accuracy %T and Linierity at λ = 560nm',
    },
  ],
};

Future<void> _bukaDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_HistorySpectro()),
        approvalServiceProvider.overrideWithValue(MockApprovalService()),
        pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CalibrationDetailScreen(calibrationId: 58),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

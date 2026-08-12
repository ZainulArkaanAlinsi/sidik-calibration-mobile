import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
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
  group('layar sertifikat', () {
    testWidgets('sesi tanpa vonis nggak dibadge PASS', (tester) async {
      await _bukaSertifikat(tester);

      // `keputusan: null` = alat ini emang nggak dinilai lulus/gagal. Waktu
      // badge-nya masih `== FAIL ? FAIL : PASS`, sesi Spectrophotometer
      // kebaca "LULUS" di layar sertifikat — dokumen yang dipegang pelanggan.
      expect(find.text('LULUS'), findsNothing);
      expect(find.text('Tanpa keputusan'), findsOneWidget);
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
            'ketidakpastian_diperluas': 0.4,
            'faktor_cakupan_k': 2.36462425,
            'keputusan': null,
            'toleransi': null,
            'tanda_nol': true,
          },
        ],
      });
}


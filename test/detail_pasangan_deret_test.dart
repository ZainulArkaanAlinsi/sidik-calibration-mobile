import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Dua deret pembacaan digambar sebagai DUA blok, bukan satu.**
///
/// ## Yang rusak sebelum ini
///
/// Layar detail menyaring pembacaan per titik dengan `titik_ke` + `tahap`.
/// Buat tiga alat suhu ber-pasangan deret (Thermocouple, Termometer Gelas,
/// Thermohygrometer) kedua kunci itu SAMA untuk deret standar dan deret UUT,
/// jadi saringannya memulangkan dua-duanya sekaligus dan kartunya menggambar
/// sepuluh angka beruntun di bawah satu label:
///
///     49,5 49,5 49,5 49,5 49,5 49,9 49,9 49,9 49,9 49,9
///
/// Lima pertama probe lab, lima berikutnya alat pelanggan. Selisih di antara
/// keduanya justru yang jadi kolom `Correction` di sertifikat.
///
/// Kenapa ini mahal: layar ini yang dibaca admin **sebelum memutuskan
/// menerbitkan sertifikat**. Dua deret yang menyamar jadi satu bukan sekadar
/// kurang rapi — angkanya kelihatan seperti sepuluh kali pengulangan satu alat,
/// dan sebaran yang kelihatan lebar itu bikin sesi yang sehat kelihatan
/// meragukan. Nol error di sepanjang jalurnya.
void main() {
  Future<void> buka(WidgetTester tester, HistoryService service) async {
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
          historyServiceProvider.overrideWithValue(service),
          approvalServiceProvider.overrideWithValue(MockApprovalService()),
          pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalibrationDetailScreen(calibrationId: 71),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('Thermocouple: deret standar & UUT kepisah, angkanya nggak nyampur', (
    tester,
  ) async {
    await buka(tester, _HistoryThermocouple());

    expect(find.text('PEMBACAAN STANDARD (PROBE LAB)'), findsOneWidget);
    expect(find.text('PEMBACAAN UUT (ALAT PELANGGAN)'), findsOneWidget);

    // Label lama nggak boleh ikut muncul — kalau dia ada, artinya cabang
    // pasangan nggak kepakai dan sepuluh angkanya masih nyampur.
    expect(
      find.text('SESUDAH ADJUSTMENT (DISERTIFIKASI)'),
      findsNothing,
      reason: 'Blok tunggal itu justru bentuk yang salah buat alat pasangan.',
    );

    // INI penjaganya: tiap angka muncul dengan jumlah yang benar, dan yang
    // membuktikan pemisahannya bukan cuma labelnya.
    // Chip pembacaan dicetak `toStringAsFixed` (titik), beda dari kepala
    // titik yang lewat format Indonesia (koma) — dibaca dari layarnya, bukan
    // ditebak.
    expect(find.text('49.500'), findsNWidgets(5)); // probe lab
    expect(find.text('49.900'), findsNWidgets(5)); // alat pelanggan
  });

  testWidgets('alat tanpa pasangan deret tetap satu blok', (tester) async {
    await buka(tester, _HistoryDatar());

    expect(find.text('SESUDAH ADJUSTMENT (DISERTIFIKASI)'), findsOneWidget);
    expect(
      find.text('PEMBACAAN STANDARD (PROBE LAB)'),
      findsNothing,
      reason: 'Tujuh belas alat lain nggak punya peran standar/UUT — '
          'memecahnya bikin blok kedua yang selamanya kosong.',
    );
  });
}

/// Bentuknya disalin dari `CalibrationResource`: `peran_sensor` menempel di
/// tiap pembacaan, dan kedua deret berbagi `titik_ke` serta `tahap`.
class _HistoryThermocouple extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 71,
        'nomor_sesi': 'DEMO-THERMOCOUPLE',
        'tanggal_kalibrasi': '2024-12-03T00:00:00.000Z',
        'status': 'disetujui',
        'desimal': 2,
        'equipment': {'nama_alat': 'Thermocouple Thermometer'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'titik': [
          {
            'titik_ke': 1,
            // Kolom kiri sertifikat = standar TERKOREKSI, bukan set point.
            'titik_ukur': 49.5,
            'satuan': '°C',
            'desimal': 2,
            'rata_rata': 49.9,
            'u95': 0.84,
          },
        ],
        'pembacaan_mentah': [
          for (var i = 1; i <= 5; i++)
            {
              'id': i,
              'titik_ke': 1,
              'titik_ukur': 49.5,
              'pembacaan_ke': i,
              'tahap': 'sesudah_adjustment',
              'pembacaan': 49.5,
              'satuan': '°C',
              'peran_sensor': 'standar',
              'sensor_ke': 1,
            },
          for (var i = 1; i <= 5; i++)
            {
              'id': 10 + i,
              'titik_ke': 1,
              'titik_ukur': 49.5,
              'pembacaan_ke': i,
              'tahap': 'sesudah_adjustment',
              'pembacaan': 49.9,
              'satuan': '°C',
              'peran_sensor': 'uut',
            },
        ],
      });
}

/// Alat bertabel datar — `peran_sensor` null di tiap pembacaan.
class _HistoryDatar extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 71,
        'nomor_sesi': 'DEMO-DATAR',
        'tanggal_kalibrasi': '2026-08-26T00:00:00.000Z',
        'status': 'disetujui',
        'desimal': 2,
        'equipment': {'nama_alat': 'pH Meter'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'titik': [
          {
            'titik_ke': 1,
            'titik_ukur': 4.01,
            'satuan': 'pH',
            'desimal': 2,
            'rata_rata': 4.02,
          },
        ],
        'pembacaan_mentah': [
          for (var i = 1; i <= 3; i++)
            {
              'id': i,
              'titik_ke': 1,
              'titik_ukur': 4.01,
              'pembacaan_ke': i,
              'tahap': 'sesudah_adjustment',
              'pembacaan': 4.02,
            },
        ],
      });
}

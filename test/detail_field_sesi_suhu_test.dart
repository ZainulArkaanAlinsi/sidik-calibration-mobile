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

/// **Tiga field sesi alat suhu kebaca admin, bukan cuma teknisi.**
///
/// ## Yang hilang sebelum ini
///
/// `alat_bantu`, `tipe_pencelupan`, dan `titik_es` sudah lama dipulangkan
/// `GET /api/calibrations/{id}` — tapi cuma dipakai jalur lembar kerja, biar
/// draf yang dibuka lagi keisi utuh. Layar detail yang dibaca admin **sebelum
/// memutuskan menerbitkan sertifikat** nggak pernah menggambarnya.
///
/// Bukan lubang perhitungan: kontribusi titik es tetap kebaca sebagai komponen
/// `stabilitas_titik_es` di tabel Type B. Yang hilang tiga keterangan yang
/// justru dipakai mengadu sesi dengan lembar cetak di meja — dan yang paling
/// mahal `alat_bantu`, karena unit yang dipilih nentuin dua komponen budget.
///
/// ## Yang dijaga di sini, dan kenapa masing-masing gagal dengan cara yang diam
///
///  1. **Nama unit, bukan kodenya.** Kolomnya menyimpan `A`/`satu`. Kalau yang
///     tampil kodenya, layarnya tetap "ada isinya" — cuma nggak berarti apa-apa
///     buat yang baca.
///  2. **Kode asing tetap kelihatan.** Label null gara-gara kode nggak dikenal
///     jangan bikin barisnya hilang: baris yang hilang kebaca sebagai "sesi ini
///     nggak milih alat bantu", padahal dia milih sesuatu yang aneh.
///  3. **Rentang titik es dihitung, bukan cuma ketiga angkanya dipajang.**
///     `Tmaks − Tmin` itu yang masuk budget (`'PERHITUNGAN FC'!Q46`), dan tanpa
///     dia tiga angka mentah nggak nyambung ke komponen Type B di bawahnya.
///  4. **Tujuh belas alat lain nggak kebagian baris kosong.** Field-nya null di
///     sana, dan baris berlabel tanpa isi bikin sesi kelihatan kurang data.
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
          home: const CalibrationDetailScreen(calibrationId: 72),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('Termometer Gelas: oilbath, tipe pencelupan & titik es kebaca', (
    tester,
  ) async {
    await buka(tester, _HistoryGelas());

    // Yang tampil NAMA unitnya, dan kodenya nggak ikut nongol sendirian.
    expect(find.text('Oil Bath 1 (SIDIK/079/2022)'), findsOneWidget);
    expect(
      find.text('satu'),
      findsNothing,
      reason: 'Kode mentah di layar admin sama nggak berartinya dengan kosong.',
    );

    expect(find.text('Total Immersion'), findsOneWidget);

    // Tiga pembacaan apa adanya…
    expect(find.text('UJI TITIK ES (30 MENIT)'), findsOneWidget);
    expect(find.text('X1'), findsOneWidget);
    expect(find.text('X2'), findsOneWidget);
    expect(find.text('X3'), findsOneWidget);
    expect(find.text('0.05 °C'), findsOneWidget);
    expect(find.text('0.02 °C'), findsOneWidget);
    expect(find.text('0.08 °C'), findsOneWidget);

    // …plus rentangnya, yang justru angka yang masuk budget. 0,08 − 0,02.
    // Ini yang nyambungin tiga angka di atas ke komponen `stabilitas_titik_es`
    // di tabel Type B — tanpa dia, keduanya berdiri sendiri-sendiri.
    expect(find.text('0.06 °C'), findsOneWidget);
  });

  testWidgets('kode alat bantu yang nggak dikenal tetap kelihatan', (
    tester,
  ) async {
    await buka(tester, _HistoryKodeAsing());

    // Server pulang `alat_bantu_label: null` karena profilnya nggak kenal `C`
    // — misalnya dryblock baru yang belum kedaftar. Barisnya TETAP digambar
    // pakai kodenya: yang hilang kebaca sebagai "nggak milih alat bantu",
    // padahal teknisi milih sesuatu yang justru pantas dicurigai.
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('Thermocouple: tipe sensor standar kebaca admin', (
    tester,
  ) async {
    await buka(tester, _HistoryThermocouple());

    // Kolom keempat dari keluarga yang sama, dan yang paling gampang kelewat
    // justru karena namanya kedengeran seperti metadata. Bukan: tipe sensor
    // MEMILIH tabel koreksi, lalu nyumbang `ketidakpastian_sensor` &
    // `drift_sensor` ke budget. Salah tipe bikin seluruh kolom Correction
    // sertifikatnya salah, dengan angka yang tetap kelihatan wajar — jadi
    // satu-satunya cara admin nangkepnya ya dengan mengadu baris ini ke
    // lembar cetak di mejanya.
    expect(find.text('Type K'), findsOneWidget);

    // Dryblock-nya ikut, biar test ini nggak diam-diam jadi test satu baris
    // kalau nanti kartu kondisi lingkungannya dirombak.
    expect(find.text('A — Isotech Fast Cal Low (−20…150 °C)'), findsOneWidget);
  });

  testWidgets('alat tanpa keempat field itu nggak dapat baris kosong', (
    tester,
  ) async {
    await buka(tester, _HistoryDatar());

    expect(find.text('Alat bantu'), findsNothing);
    expect(find.text('Tipe pencelupan'), findsNothing);
    expect(
      find.text('Tipe sensor standar'),
      findsNothing,
      reason: 'Lembar pH sensornya nggak bisa dipilih; barisnya nggak boleh ada.',
    );
    expect(
      find.text('UJI TITIK ES (30 MENIT)'),
      findsNothing,
      reason: 'Baris berlabel tanpa isi bikin sesi kelihatan kurang data.',
    );
  });
}

/// Bentuknya disalin dari `CalibrationResource`: ketiga field di level sesi,
/// dan `alat_bantu_label` sudah diresolusi server dari kodenya.
Map<String, dynamic> _sesiGelas({
  String? alatBantu = 'satu',
  String? alatBantuLabel = 'Oil Bath 1 (SIDIK/079/2022)',
}) => {
  'id': 72,
  'nomor_sesi': 'DEMO-GELAS',
  'tanggal_kalibrasi': '2024-12-03T00:00:00.000Z',
  'status': 'disetujui',
  'desimal': 2,
  'equipment': {'nama_alat': 'Glass Thermometer'},
  'teknisi': {'nama': 'Teknisi Sidik'},
  'hasil': {'keputusan': null},
  'alat_bantu': alatBantu,
  'alat_bantu_label': alatBantuLabel,
  'tipe_pencelupan': 'Total Immersion',
  // Sengaja TIDAK terurut — rentangnya mesti datang dari maks/min, bukan dari
  // "elemen terakhir dikurangi elemen pertama".
  'titik_es': [0.05, 0.02, 0.08],
  'titik': [
    {
      'titik_ke': 1,
      'titik_ukur': 29.8,
      'satuan': '°C',
      'desimal': 2,
      'rata_rata': 30.1,
      'u95': 0.5,
    },
  ],
  'pembacaan_mentah': const <Map<String, dynamic>>[],
};

class _HistoryGelas extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(_sesiGelas());
}

/// Kode yang profilnya nggak kenal — `labelAlatBantu()` pulang null.
class _HistoryKodeAsing extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(
        _sesiGelas(alatBantu: 'C', alatBantuLabel: null),
      );
}

/// Thermocouple: dryblock + tipe sensor. `tipe_pencelupan` & `titik_es` null —
/// dua itu cuma punya Termometer Gelas, jadi lembar ini sekaligus membuktikan
/// baris yang nggak berlaku tetap nggak digambar.
class _HistoryThermocouple extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 72,
        'nomor_sesi': 'DEMO-TC',
        'tanggal_kalibrasi': '2024-12-03T00:00:00.000Z',
        'status': 'disetujui',
        'desimal': 2,
        'equipment': {'nama_alat': 'Thermocouple Thermometer'},
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'alat_bantu': 'A',
        'alat_bantu_label': 'A — Isotech Fast Cal Low (−20…150 °C)',
        'tipe_sensor': 'Type K',
        'titik': [
          {
            'titik_ke': 1,
            'titik_ukur': 50.0,
            'satuan': '°C',
            'desimal': 2,
            'rata_rata': 49.9,
            'u95': 0.84,
          },
        ],
        'pembacaan_mentah': const <Map<String, dynamic>>[],
      });
}

/// Tujuh belas alat lain — keempat field null.
class _HistoryDatar extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 72,
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
        'pembacaan_mentah': const <Map<String, dynamic>>[],
      });
}

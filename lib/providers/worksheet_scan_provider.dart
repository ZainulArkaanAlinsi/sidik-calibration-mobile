import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/worksheet_template.dart';
import '../services/pembaca_qr.dart';
import '../services/pembaca_sel.dart';
import '../services/worksheet_scan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final worksheetScanServiceProvider = Provider<WorksheetScanService>((ref) {
  if (AppConfig.useMock) return MockWorksheetScanService();
  return ApiWorksheetScanService(ref.watch(apiClientProvider));
});

/// Pabrik pembaca ML Kit — **bikin baru tiap pindai, tutup sesudahnya**.
///
/// Yang dipegang provider ini fungsinya, bukan pembacanya: `TextRecognizer` &
/// `BarcodeScanner` megang sumber daya di sisi native, jadi satu instans yang
/// hidup selama app jalan itu kebocoran yang cuma kelihatan di HP.
typedef PabrikPembacaPindai = ({
  PembacaSel Function() sel,
  PembacaQr Function() qr,
});

/// Disuntik lewat provider supaya seluruh jalur pindai bisa dijalanin di test
/// tanpa perangkat.
///
/// Sebelum ini `MlKitPembacaSel()` dibikin langsung di dalam widget, dan
/// akibatnya bukan cuma "susah dites": SATU-SATUNYA cara nguji sambungan
/// kamera → server → layar review → formulir adalah lewat HP fisik, dan itu
/// bukan penjaga harian. Yang paling mahal justru sambungannya — angka yang
/// nyampe formulir tapi sesinya nggak ditandai butuh verifikasi, misalnya,
/// nggak ngasih gejala apa pun sampai admin keblokir.
final pabrikPembacaPindaiProvider = Provider<PabrikPembacaPindai>(
  (ref) => (sel: MlKitPembacaSel.new, qr: MlKitPembacaQr.new),
);

/// Kunci [worksheetTemplateProvider]: kode lembar + alat yang lagi dipilih.
///
/// `equipmentId` masuk kunci karena satuan, resolusi, dan desimal per baris
/// lahir dari alat pelanggan — template tanpa alat balikin ketiganya `null`,
/// dan layar nggak boleh ngisi nilai bawaan sendiri.
typedef KunciTemplatePindai = ({String kode, int? equipmentId});

/// Bentuk + kesiapan lembar buat dipindai.
///
/// Sengaja provider terpisah dari lembar kerjanya: kesiapan pindai itu urusan
/// GEOMETRI (koordinat sel diukur dari formulir cetak asli), bukan urusan
/// bentuk formulirnya — dan sekarang keenam lembar masih
/// `geometri_belum_diverifikasi`.
final worksheetTemplateProvider =
    FutureProvider.family<WorksheetTemplate, KunciTemplatePindai>((
      ref,
      kunci,
    ) async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref
          .read(worksheetScanServiceProvider)
          .template(token, kunci.kode, equipmentId: kunci.equipmentId);
    }, retry: (retryCount, error) => null);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/worksheet_template.dart';
import '../services/worksheet_scan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final worksheetScanServiceProvider = Provider<WorksheetScanService>((ref) {
  if (AppConfig.useMock) return MockWorksheetScanService();
  return ApiWorksheetScanService(ref.watch(apiClientProvider));
});

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

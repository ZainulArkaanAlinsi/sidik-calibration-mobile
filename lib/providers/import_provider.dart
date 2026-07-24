import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/import_excel.dart';
import '../services/import_service.dart';
import 'auth_provider.dart';
import 'calibration_input_provider.dart' show standardCrudProvider;
import 'dashboard_provider.dart' show TokenHilangException;
import 'equipment_provider.dart';
import 'master_data_provider.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  if (AppConfig.useMock) return MockImportService();
  return ApiImportService(ref.watch(apiClientProvider));
});

final importControllerProvider = Provider<ImportController>(ImportController.new);

class ImportController {
  ImportController(this._ref);

  final Ref _ref;

  Future<HasilImport> jalankan({
    required String filePath,
    required String tipe,
    required bool ujiCoba,
  }) async {
    final token = await _ref.read(tokenStorageProvider).read();
    if (token == null) throw const TokenHilangException();

    final hasil = await _ref.read(importServiceProvider).unggah(
      token,
      filePath: filePath,
      tipe: tipe,
      ujiCoba: ujiCoba,
    );

    // Uji coba nggak ngubah apa-apa di server (transaksinya di-rollback), jadi
    // cache lokal nggak perlu disegerin. Yang beneran nulis, iya — kalau nggak,
    // admin baru lihat hasil import-nya sesudah restart app.
    if (!ujiCoba) _segarkanMasterData();

    return hasil;
  }

  void _segarkanMasterData() {
    _ref.invalidate(customerProvider);
    _ref.invalidate(customerLookupProvider);
    _ref.invalidate(standardCrudProvider);
    _ref.invalidate(equipmentProvider);
  }
}

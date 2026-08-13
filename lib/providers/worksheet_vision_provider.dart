import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/worksheet_vision.dart';
import 'auth_provider.dart';

// `sumberFotoProvider` pindah ke `sumber_foto_provider.dart` — kamera nggak
// boleh ikut mati waktu jalur AI Vision ini dicabut.

/// Ekstraksi tabel worksheet lewat **AI Vision di backend**. Menggantikan OCR
/// on-device (ML Kit) yang dulu sering meleset di lapangan.
///
/// Di `USE_MOCK` / test pakai [MockWorksheetVisionService] supaya alur foto →
/// pra-isi tetap bisa diuji tanpa backend maupun kamera sungguhan.
final worksheetVisionProvider = Provider<WorksheetVisionService>((ref) {
  if (AppConfig.useMock) return MockWorksheetVisionService();
  return ApiWorksheetVisionService(
    ref.watch(apiClientProvider),
    () => ref.read(tokenStorageProvider).read(),
  );
});

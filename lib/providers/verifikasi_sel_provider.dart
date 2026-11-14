import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/verifikasi_sel_service.dart';
import 'auth_provider.dart';

/// Konfirmasi pembacaan kamera per baris — lihat [VerifikasiSelService].
final verifikasiSelServiceProvider = Provider<VerifikasiSelService>((ref) {
  if (AppConfig.useMock) return MockVerifikasiSelService();
  return ApiVerifikasiSelService(ref.watch(apiClientProvider));
});

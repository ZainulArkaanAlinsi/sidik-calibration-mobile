import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/calibration_history_item.dart';
import '../services/kalibrasi_teknisi_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final kalibrasiTeknisiServiceProvider = Provider<KalibrasiTeknisiService>((
  ref,
) {
  if (AppConfig.useMock) return MockKalibrasiTeknisiService();
  return ApiKalibrasiTeknisiService(ref.watch(apiClientProvider));
});

Future<String> _token(Ref ref) async {
  final token = await ref.read(tokenStorageProvider).read();
  if (token == null) throw const TokenHilangException();
  return token;
}

/// Lembar teknisi yang berstatus perlu revisi. Ikut akun yang login.
final perluRevisiTeknisiProvider = FutureProvider<List<CalibrationHistoryItem>>(
  (ref) async {
    ref.watch(authProvider);
    final token = await _token(ref);
    return ref.read(kalibrasiTeknisiServiceProvider).perluRevisi(token);
  },
  retry: (retryCount, error) => null,
);

/// Sepuluh kiriman terakhir teknisi (baca saja). Ikut akun yang login.
final terkirimTerakhirProvider = FutureProvider<List<CalibrationHistoryItem>>(
  (ref) async {
    ref.watch(authProvider);
    final token = await _token(ref);
    return ref.read(kalibrasiTeknisiServiceProvider).terkirimTerakhir(token);
  },
  retry: (retryCount, error) => null,
);

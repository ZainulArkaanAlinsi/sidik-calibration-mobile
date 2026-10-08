import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/riwayat_tersembunyi_service.dart';
import 'auth_provider.dart';

/// Sembunyikan/tampilkan lagi sesi di Riwayat akun yang login. Status
/// barisnya sendiri hidup di `historyProvider` (`HistoryController.sembunyikan`
/// & `tampilkanLagi`) — provider ini cuma memilih Api atau Mock.
final riwayatTersembunyiServiceProvider = Provider<RiwayatTersembunyiService>((
  ref,
) {
  if (AppConfig.useMock) return MockRiwayatTersembunyiService();
  return ApiRiwayatTersembunyiService(ref.watch(apiClientProvider));
});

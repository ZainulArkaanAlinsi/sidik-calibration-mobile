import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calibration_history_item.dart';
import '../services/history_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// `GET /api/calibrations` sendiri belum live di backend (fitur kalibrasi
/// minggu 4) — jadi provider ini masih nunjuk ke [MockHistoryService].
/// Ganti ke `ApiHistoryService(ref.watch(apiClientProvider))` begitu
/// endpoint-nya jalan (sama kayak riwayat commit dashboardServiceProvider).
final historyServiceProvider = Provider<HistoryService>(
  (ref) => MockHistoryService(),
);

final historyProvider =
    AsyncNotifierProvider<HistoryController, List<CalibrationHistoryItem>>(
      HistoryController.new,
      retry: (retryCount, error) => null,
    );

class HistoryController extends AsyncNotifier<List<CalibrationHistoryItem>> {
  @override
  Future<List<CalibrationHistoryItem>> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const TokenHilangException();
    }

    return ref.read(historyServiceProvider).ambilRiwayat(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

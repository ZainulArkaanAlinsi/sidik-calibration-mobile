import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';

import 'auth_provider.dart';

/// Nyambung ke `GET /api/dashboard` beneran (live 14 Jul).
///
/// `MockDashboardService` sengaja **nggak dihapus** — dia yang dipakai test
/// buat maksa 4 state (loading/empty/normal/error) tanpa perlu server nyala.
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  if (AppConfig.useMock) return MockDashboardService();
  return ApiDashboardService(ref.watch(apiClientProvider));
});

/// Ringkasan dashboard. `AsyncValue` yang ngasih 3 state ke layar:
/// `loading` (skeleton) · `error` (tombol coba lagi) · `data` (empty / normal).
///
/// `retry: null` = **matiin retry otomatis bawaan Riverpod 3.** Defaultnya,
/// provider yang gagal bakal dicoba ulang terus di belakang layar — kalau
/// server lagi mati, itu cuma nge-gempur server sambil ngabisin baterai HP
/// teknisi, dan user nggak tahu apa-apa. Lebih jujur: tampilin gagalnya,
/// kasih tombol "Coba lagi", biar user yang mutusin.
final dashboardProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummary>(
      DashboardController.new,
      retry: (retryCount, error) => null,
    );

class DashboardController extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() async {
    // Nempel ke user yang login: begitu ganti user, angkanya ikut ke-refresh.
    // Tanpa ini, angka punya user lama bisa nyangkut di layar user baru.
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const TokenHilangException();
    }

    return ref.read(dashboardServiceProvider).ambilRingkasan(token);
  }

  /// Dipanggil dari tombol "Coba lagi" dan tarik-buat-refresh.
  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

class TokenHilangException implements Exception {
  const TokenHilangException();

  @override
  String toString() => 'Sesi habis. Login ulang ya.';
}

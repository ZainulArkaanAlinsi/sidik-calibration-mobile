import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/peristiwa_persetujuan.dart';
import '../services/riwayat_persetujuan_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

final riwayatPersetujuanServiceProvider = Provider<RiwayatPersetujuanService>((ref) {
  if (AppConfig.useMock) return MockRiwayatPersetujuanService();
  return ApiRiwayatPersetujuanService(ref.watch(apiClientProvider));
});

/// Riwayat persetujuan satu sesi (khusus admin & super admin). Diambil hanya
/// waktu bagiannya dibuka — teknisi & viewer tidak pernah memanggilnya.
///
/// `autoDispose`: dibuang begitu layarnya ditutup, jadi dibuka lagi = diambil
/// ulang. Setuju/tolak dari aplikasi juga meng-invalidate-nya
/// (`HistoryController`). Tanpa keduanya admin yang baru menolak melihat
/// riwayat basi tanpa penolakan terbarunya (tinjauan 6 Okt 2026).
final riwayatPersetujuanProvider =
    FutureProvider.autoDispose.family<List<PeristiwaPersetujuan>, int>((ref, sesiId) async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();

      return ref.read(riwayatPersetujuanServiceProvider).ambil(token, sesiId);
    }, retry: (retryCount, error) => null);

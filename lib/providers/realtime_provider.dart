import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/realtime_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart';
import 'history_provider.dart';
import 'notification_provider.dart';

/// Sambungan realtime. **Mock (no-op)** kalau realtime nonaktif (kunci Reverb
/// kosong) atau mode mock — jadi dev & test nggak pernah nyoba buka websocket.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  if (!AppConfig.realtimeAktif) return MockRealtimeService();
  final service = PusherRealtimeService();
  ref.onDispose(service.putus);
  return service;
});

/// Nyambungin realtime ke daur hidup auth: begitu user login (+ token) → konek
/// & subscribe channel org/user; tiap peristiwa → refresh provider terkait;
/// logout → putus. Ditahan hidup dengan di-`watch` dari shell utama.
final realtimeSyncProvider = Provider<void>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  final user = ref.watch(authProvider).value;

  if (user == null) return; // belum login → nggak usah konek

  final sub = service.peristiwa.listen((p) => _tangani(ref, p));

  // Konek butuh token dari storage (async) — fire-and-forget.
  Future(() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;
    await service.hubungkan(
      token: token,
      userId: user.id,
      organizationId: user.organizationId,
    );
  });

  ref.onDispose(() {
    sub.cancel();
    service.putus();
  });
});

/// Sinyal tipis → tarik ulang data lewat REST (arsitektur backend: broadcast
/// cuma nandain "ada perubahan", isinya tetap via REST ber-otorisasi).
void _tangani(Ref ref, PeristiwaRealtime p) {
  switch (p) {
    case DataBerubah():
      // Invalidate = lazy: yang lagi ditonton refetch, yang nggak nunggu dibuka.
      ref.invalidate(dashboardProvider);
      ref.invalidate(historyProvider);
      ref.invalidate(antreanApprovalProvider);
    case NotifikasiMasuk():
      // Badge lonceng selalu di-refresh (nyala barengan HP↔desktop); daftar
      // notifikasi refetch lazy saat layarnya dibuka.
      ref.invalidate(notificationProvider);
      ref.read(unreadCountProvider.notifier).muatUlang();
  }
}

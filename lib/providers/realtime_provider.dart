import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/realtime_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart';
import 'history_provider.dart';
import 'notifikasi_perangkat_provider.dart';
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

    // Notifikasi yang UDAH ada waktu sambungan dibuka dicatat tanpa dibunyiin.
    // Admin yang login pagi hari dengan 20 notifikasi belum dibaca nggak boleh
    // kena 20 notifikasi sistem sekaligus — yang kayak gitu bukan bikin dia
    // sadar, tapi bikin dia matiin notifikasi app-nya selamanya.
    //
    // Dibungkus `try`: ini lapisan tambahan. Gagal narik daftar awal — token
    // kedaluwarsa, jaringan putus — nggak boleh ngerusak sambungan realtime
    // yang justru tugas utama provider ini.
    try {
      final awal = await ref.read(notificationProvider.future);
      await ref.read(pengabarNotifikasiProvider).mulai(awal);
    } catch (_) {
      // Loncengnya di dalam app tetap jalan; itu sumber kebenarannya.
    }
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
      // Lalu naik ke bilah SISTEM. Lonceng cuma kelihatan sama orang yang lagi
      // mbuka app-nya; admin yang lagi ngerjain hal lain di laptop nggak bakal
      // tahu ada kiriman teknisi masuk sampai dia kebetulan mbuka app lagi.
      _umumkan(ref);
  }
}

/// Tarik daftar notifikasi yang barusan di-invalidate, lalu umumin yang beneran
/// baru ke bilah sistem.
///
/// Sengaja `unawaited`-style (dibiarkan jalan sendiri): `_tangani` dipanggil
/// dari listener stream yang nggak nunggu siapa-siapa, dan gagal nampilin
/// notifikasi nggak boleh nahan refresh data yang jauh lebih penting.
void _umumkan(Ref ref) {
  Future(() async {
    try {
      final daftar = await ref.read(notificationProvider.future);
      await ref.read(pengabarNotifikasiProvider).umumkan(daftar);
    } catch (_) {
      // Notifikasi sistem itu lapisan tambahan. Kalau gagal — izin dicabut,
      // jaringan putus di tengah refetch — loncengnya di dalam app tetap
      // nyala, dan itu yang jadi sumber kebenarannya.
    }
  });
}

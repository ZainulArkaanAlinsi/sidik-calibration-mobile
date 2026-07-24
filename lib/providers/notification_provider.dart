import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// Nembak API asli. Mock-nya tetap ada buat `--dart-define=USE_MOCK=true`
/// (backend mati / lagi ngoding UI tanpa server) & buat test.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (AppConfig.useMock) return MockNotificationService();
  return ApiNotificationService(ref.watch(apiClientProvider));
});

final notificationProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationItem>>(
      NotificationController.new,
      retry: (retryCount, error) => null,
    );

/// Angka buat badge di ikon notifikasi.
///
/// Dipisah dari [notificationProvider] dengan sengaja: badge-nya nempel di
/// app bar HAMPIR SEMUA layar, jadi kalau dia ikut nunggu daftar penuh,
/// tiap layar yang kebuka narik 20 baris notifikasi cuma buat nampilin satu
/// angka. Ini nembak endpoint ringan `unread-count`.
final unreadCountProvider = AsyncNotifierProvider<UnreadCount, int>(
  UnreadCount.new,
  retry: (retryCount, error) => null,
);

class UnreadCount extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return 0;

    return ref.read(notificationServiceProvider).jumlahBelumDibaca(token);
  }

  Future<void> muatUlang() async {
    state = await AsyncValue.guard(() => build());
  }

  /// Turunin angkanya tanpa nembak server — dipanggil dari
  /// [NotificationController] yang barusan nandain satu notifikasi dibaca.
  void kurangi([int jumlah = 1]) {
    final sekarang = state.value;
    if (sekarang == null) return;
    state = AsyncValue.data((sekarang - jumlah).clamp(0, 9999));
  }

  void nolkan() => state = const AsyncValue.data(0);
}

class NotificationController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    ref.watch(authProvider);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const TokenHilangException();
    }

    return ref.read(notificationServiceProvider).ambilNotifikasi(token);
  }

  Future<void> muatUlang() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
    ref.read(unreadCountProvider.notifier).muatUlang();
  }

  /// Optimistic: penanda "belum dibaca" ilang duluan di UI, baru nembak
  /// server. Kalau gagal, dibalikin ke semula — daripada nunggu roundtrip
  /// buat aksi sepele "tandai dibaca".
  Future<void> tandaiDibaca(String id) async {
    final sebelum = state.value;
    if (sebelum == null) return;

    final sudahDibaca = sebelum.where((n) => n.id == id).any((n) => n.dibaca);
    if (sudahDibaca) return;

    state = AsyncValue.data([
      for (final n in sebelum)
        if (n.id == id) n.copyWith(dibaca: true) else n,
    ]);
    ref.read(unreadCountProvider.notifier).kurangi();

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    try {
      await ref.read(notificationServiceProvider).tandaiDibaca(token, id);
    } catch (_) {
      state = AsyncValue.data(sebelum);
      ref.read(unreadCountProvider.notifier).muatUlang();
    }
  }

  Future<void> tandaiSemuaDibaca() async {
    final sebelum = state.value;
    if (sebelum == null) return;

    state = AsyncValue.data([
      for (final n in sebelum) n.copyWith(dibaca: true),
    ]);
    ref.read(unreadCountProvider.notifier).nolkan();

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    try {
      await ref.read(notificationServiceProvider).tandaiSemuaDibaca(token);
    } catch (_) {
      state = AsyncValue.data(sebelum);
      ref.read(unreadCountProvider.notifier).muatUlang();
    }
  }
}

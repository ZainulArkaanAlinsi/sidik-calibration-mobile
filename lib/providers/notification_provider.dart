import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_item.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart' show TokenHilangException;

/// `GET /api/notifications` belum live di backend (masih "dibutuhin Minggu
/// 9") — provider ini masih nunjuk ke [MockNotificationService]. Ganti ke
/// `ApiNotificationService(ref.watch(apiClientProvider))` begitu jalan.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => MockNotificationService(),
);

final notificationProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationItem>>(
      NotificationController.new,
      retry: (retryCount, error) => null,
    );

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
  }

  /// Optimistic: badge "belum dibaca" ilang duluan di UI, baru nembak
  /// server. Kalau gagal, dibalikin ke semula — daripada nunggu roundtrip
  /// buat aksi sepele "tandai dibaca".
  Future<void> tandaiDibaca(int id) async {
    final sebelum = state.value;
    if (sebelum == null) return;

    final sudahDibaca = sebelum
        .where((n) => n.id == id)
        .any((n) => n.dibaca);
    if (sudahDibaca) return;

    state = AsyncValue.data([
      for (final n in sebelum)
        if (n.id == id) n.copyWith(dibaca: true) else n,
    ]);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    try {
      await ref.read(notificationServiceProvider).tandaiDibaca(token, id);
    } catch (_) {
      state = AsyncValue.data(sebelum);
    }
  }
}

import '../models/notification_item.dart';
import 'api_client.dart';

abstract class NotificationService {
  Future<List<NotificationItem>> ambilNotifikasi(String token);

  Future<void> tandaiDibaca(String token, int id);
}

/// Nembak `GET /api/notifications` + `POST /api/notifications/{id}/read`
/// (`docs/kontrak-api.md` §6). Belum dipakai di [notificationProvider] —
/// endpoint ini sendiri masih ditandai "dibutuhin Minggu 9", belum live.
/// Ganti provider ke ini begitu backend-nya jalan.
class ApiNotificationService implements NotificationService {
  ApiNotificationService(this._api);

  final ApiClient _api;

  @override
  Future<List<NotificationItem>> ambilNotifikasi(String token) async {
    final json = await _api.get('/notifications', token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data
        .cast<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  @override
  Future<void> tandaiDibaca(String token, int id) async {
    await _api.post('/notifications/$id/read', token: token);
  }
}

/// Data tiruan buat layar Notifikasi & test — dipakai sampai
/// `GET /api/notifications` beneran live.
class MockNotificationService implements NotificationService {
  MockNotificationService({
    this.kosong = false,
    this.gagal = false,
    // Nol secara default — lihat alasannya di MockHistoryService.jeda.
    this.jeda = Duration.zero,
  });

  final bool kosong;
  final bool gagal;
  final Duration jeda;

  @override
  Future<List<NotificationItem>> ambilNotifikasi(String token) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);

    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return const [];

    final sekarang = DateTime.now();

    return [
      NotificationItem(
        id: 1,
        tipe: NotificationType.jatuhTempo,
        judul: '3 alat mendekati jatuh tempo',
        pesan: 'Jangka Sorong Mitutoyo jatuh tempo 20 Jul 2026.',
        dibaca: false,
        createdAt: sekarang.subtract(const Duration(hours: 2)),
      ),
      NotificationItem(
        id: 2,
        tipe: NotificationType.approval,
        judul: 'Sesi kalibrasi disetujui',
        pesan: 'Kalibrasi Timbangan Digital Ohaus disetujui admin.',
        dibaca: false,
        createdAt: sekarang.subtract(const Duration(hours: 6)),
      ),
      NotificationItem(
        id: 3,
        tipe: NotificationType.revisi,
        judul: 'Perlu revisi',
        pesan:
            'Kalibrasi Multimeter Fluke 87V ditolak: titik ukur 100mm cuma 2 pembacaan, minimal 3.',
        dibaca: true,
        createdAt: sekarang.subtract(const Duration(days: 1)),
      ),
    ];
  }

  @override
  Future<void> tandaiDibaca(String token, int id) async {
    if (jeda > Duration.zero) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (gagal) throw Exception('server nggak nyaut');
  }
}

import '../models/notification_item.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

abstract class NotificationService {
  Future<List<NotificationItem>> ambilNotifikasi(
    String token, {
    bool belumDibacaSaja,
  });

  /// Angka di badge ikon notifikasi. Dipisah dari [ambilNotifikasi] karena
  /// dipanggil jauh lebih sering (tiap layar dibuka) — nggak perlu narik
  /// seluruh daftar cuma buat satu angka.
  Future<int> jumlahBelumDibaca(String token);

  Future<void> tandaiDibaca(String token, String id);

  Future<void> tandaiSemuaDibaca(String token);

  Future<void> hapus(String token, String id);
}

/// `GET/POST/DELETE /api/notifications*`.
class ApiNotificationService implements NotificationService {
  ApiNotificationService(this._api);

  final ApiClient _api;

  @override
  Future<List<NotificationItem>> ambilNotifikasi(
    String token, {
    bool belumDibacaSaja = false,
  }) async {
    final path = belumDibacaSaja
        ? '/notifications?belum_dibaca=1'
        : '/notifications';
    final json = await _api.get(path, token: token);
    final data = json['data'] as List<dynamic>? ?? const [];

    return parseListAman(data, NotificationItem.fromJson);
  }

  @override
  Future<int> jumlahBelumDibaca(String token) async {
    final json = await _api.get('/notifications/unread-count', token: token);
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return (data['belum_dibaca'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> tandaiDibaca(String token, String id) async {
    await _api.post('/notifications/$id/read', token: token);
  }

  @override
  Future<void> tandaiSemuaDibaca(String token) async {
    await _api.post('/notifications/read-all', token: token);
  }

  @override
  Future<void> hapus(String token, String id) async {
    await _api.delete('/notifications/$id', token: token);
  }
}

/// Data tiruan buat layar Notifikasi & test.
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

  final Set<String> _dibaca = {};

  @override
  Future<List<NotificationItem>> ambilNotifikasi(
    String token, {
    bool belumDibacaSaja = false,
  }) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);

    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return const [];

    final sekarang = DateTime.now();

    final semua = [
      NotificationItem(
        id: 'n-1',
        kategori: NotifKategori.jatuhTempo,
        judul: '3 alat mendekati jatuh tempo',
        isi: 'Jangka Sorong Mitutoyo jatuh tempo 20 Jul 2026.',
        dibaca: _dibaca.contains('n-1'),
        dibuatPada: sekarang.subtract(const Duration(hours: 2)),
        tautan: const NotifTautan(tipe: 'equipment', id: 12),
      ),
      NotificationItem(
        id: 'n-2',
        kategori: NotifKategori.sesiDisetujui,
        judul: 'Sesi kalibrasi disetujui',
        isi: 'Kalibrasi Timbangan Digital Ohaus disetujui admin.',
        dibaca: _dibaca.contains('n-2'),
        dibuatPada: sekarang.subtract(const Duration(hours: 6)),
        tautan: const NotifTautan(tipe: 'calibration', id: 41),
      ),
      NotificationItem(
        id: 'n-3',
        kategori: NotifKategori.sesiPerluRevisi,
        judul: 'Perlu revisi',
        isi:
            'Kalibrasi Multimeter Fluke 87V ditolak: titik ukur 100mm cuma 2 '
            'pembacaan, minimal 3.',
        dibaca: true,
        dibuatPada: sekarang.subtract(const Duration(days: 1)),
        tautan: const NotifTautan(tipe: 'calibration', id: 39),
      ),
    ];

    return belumDibacaSaja ? semua.where((n) => !n.dibaca).toList() : semua;
  }

  @override
  Future<int> jumlahBelumDibaca(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return 0;
    return (await ambilNotifikasi(token)).where((n) => !n.dibaca).length;
  }

  @override
  Future<void> tandaiDibaca(String token, String id) async {
    if (jeda > Duration.zero) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (gagal) throw Exception('server nggak nyaut');
    _dibaca.add(id);
  }

  @override
  Future<void> tandaiSemuaDibaca(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    _dibaca.addAll(['n-1', 'n-2', 'n-3']);
  }

  @override
  Future<void> hapus(String token, String id) async {
    if (gagal) throw Exception('server nggak nyaut');
  }
}

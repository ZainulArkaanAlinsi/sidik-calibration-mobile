import '../models/peristiwa_persetujuan.dart';
import 'api_client.dart';

/// Riwayat persetujuan sesi — `GET /api/calibrations/{id}/riwayat-persetujuan`.
///
/// Service sendiri, bukan metode baru di `HistoryService`: beberapa test
/// memalsukan `HistoryService` lewat `implements`, dan menambah anggota di
/// sana memecahkan semuanya tanpa ada yang berubah perilakunya.
abstract class RiwayatPersetujuanService {
  Future<List<PeristiwaPersetujuan>> ambil(String token, int sesiId);
}

class ApiRiwayatPersetujuanService implements RiwayatPersetujuanService {
  ApiRiwayatPersetujuanService(this._api);

  final ApiClient _api;

  @override
  Future<List<PeristiwaPersetujuan>> ambil(String token, int sesiId) async {
    final json = await _api.get('/calibrations/$sesiId/riwayat-persetujuan', token: token);
    final data = json['data'];
    if (data is! List) return const [];

    return [
      for (final e in data)
        if (e is Map<String, dynamic>) PeristiwaPersetujuan.fromJson(e),
    ];
  }
}

/// Mode mock: dua penolakan dengan alasan berbeda — bentuk yang paling perlu
/// kelihatan benar (alasan lama tetap terbaca walau ditimpa).
class MockRiwayatPersetujuanService implements RiwayatPersetujuanService {
  @override
  Future<List<PeristiwaPersetujuan>> ambil(String token, int sesiId) async {
    final t = DateTime(2026, 10, 6, 9);
    return [
      PeristiwaPersetujuan(jenis: 'diajukan', status: 'menunggu_approval', waktu: t, olehNama: 'Teknisi Contoh'),
      PeristiwaPersetujuan(
        jenis: 'ditolak',
        status: 'perlu_revisi',
        statusSebelumnya: 'menunggu_approval',
        waktu: t.add(const Duration(hours: 1)),
        olehNama: 'Admin Contoh',
        alasan: 'Titik 3 meleset, ulangi pembacaannya.',
        kolom: const ['alat_merk'],
      ),
      PeristiwaPersetujuan(
        jenis: 'diajukan_ulang',
        status: 'menunggu_approval',
        statusSebelumnya: 'perlu_revisi',
        waktu: t.add(const Duration(hours: 2)),
        olehNama: 'Teknisi Contoh',
      ),
      PeristiwaPersetujuan(
        jenis: 'ditolak',
        status: 'perlu_revisi',
        statusSebelumnya: 'menunggu_approval',
        waktu: t.add(const Duration(hours: 3)),
        olehNama: 'Admin Contoh',
        alasan: 'Suhu ruang akhir belum diisi.',
      ),
    ];
  }
}

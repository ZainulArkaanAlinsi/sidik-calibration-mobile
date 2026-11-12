import '../models/audit_log.dart';
import 'api_client.dart';

/// Riwayat perubahan data lab (`GET /api/audit-logs`) — admin & super admin,
/// BACA SAJA. Server tidak punya rute tulis untuk ini: baris riwayat lahir dari
/// perubahan datanya sendiri, jadi service ini pun tidak punya method tulis.
///
/// Ekspor CSV (`/audit-logs/export`) sengaja belum dipakai: itu berkas unduhan
/// untuk asesor dan butuh jalur simpan/bagikan berkas yang belum ada di app.
abstract class AuditLogService {
  /// 25 baris per halaman (`paginate(25)` di server).
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  });
}

class ApiAuditLogService implements AuditLogService {
  ApiAuditLogService(this._api);

  final ApiClient _api;

  @override
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  }) async {
    final query = filter.toQuery(page: page);
    // `Uri` yang menyusun query-nya, bukan interpolasi string: tipe data dan
    // tanggal tidak boleh merusak URL.
    final path = Uri(
      path: '/audit-logs',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    final json = await _api.get(path, token: token);

    return HalamanAuditLog.fromJson(json);
  }
}

/// Versi in-memory buat mode mock & widget test.
///
/// Memotong per [ukuranHalaman] dan menerapkan penyaring yang sama dengan
/// server, supaya "muat lebih banyak" dan filter bisa diuji tanpa jaringan.
/// [jumlahPanggilan] dihitung buat test ganti akun (provider betul-betul lahir
/// ulang, bukan kebetulan datanya mirip).
class MockAuditLogService implements AuditLogService {
  MockAuditLogService({
    List<AuditLogItem>? data,
    this.ukuranHalaman = 25,
    this.gagal = false,
  }) : _data = data ?? contoh();

  final List<AuditLogItem> _data;
  final int ukuranHalaman;
  final bool gagal;

  int jumlahPanggilan = 0;

  /// Filter dan halaman terakhir yang diminta — untuk assert di test.
  FilterAuditLog? filterTerakhir;
  int? halamanTerakhir;

  @override
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  }) async {
    jumlahPanggilan++;
    filterTerakhir = filter;
    halamanTerakhir = page;
    if (gagal) throw Exception('server nggak nyaut');

    final cocok = _data.where((e) {
      if (filter.aksi != null && e.aksi != filter.aksi) return false;
      if (filter.entityType != null && e.entitasTipe != filter.entityType) {
        return false;
      }
      if (filter.entityId != null && e.entitasId != filter.entityId) {
        return false;
      }
      return true;
    }).toList();

    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final dari = (page - 1) * ukuranHalaman;
    final potong = cocok.skip(dari).take(ukuranHalaman).toList();

    return HalamanAuditLog(
      items: potong,
      currentPage: page,
      lastPage: terakhir,
    );
  }

  /// Data contoh yang realistis: bentuknya persis `AuditLogResource`.
  static List<AuditLogItem> contoh() => [
    AuditLogItem(
      id: 3,
      entitasTipe: 'users',
      entitasId: 2,
      aksi: 'diubah',
      perubahan: const [
        PerubahanKolom(
          kolom: 'email',
          lama: 'eko@gmial.com',
          baru: 'eko@gmail.com',
        ),
        PerubahanKolom(kolom: 'password'),
      ],
      pelakuId: 1,
      pelakuNama: 'Budi Santoso',
      pelakuRole: 'admin',
      dicatatPada: DateTime.utc(2026, 10, 20, 9, 30),
    ),
    AuditLogItem(
      id: 2,
      entitasTipe: 'standards',
      entitasId: 7,
      aksi: 'diubah',
      perubahan: const [
        PerubahanKolom(
          kolom: 'tanggal_kalibrasi_berikut',
          lama: '2026-04-29',
          baru: '2027-04-29',
        ),
        PerubahanKolom(kolom: 'aktif', lama: false, baru: true),
      ],
      pelakuId: 1,
      pelakuNama: 'Budi Santoso',
      pelakuRole: 'admin',
      catatan: 'Rekalibrasi standar',
      dicatatPada: DateTime.utc(2026, 10, 19, 3, 5),
    ),
    AuditLogItem(
      id: 1,
      entitasTipe: 'equipments',
      entitasId: 12,
      aksi: 'dibikin',
      olehSistem: true,
      dicatatPada: DateTime.utc(2026, 10, 18, 1, 0),
    ),
  ];
}

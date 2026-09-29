import '../models/penugasan.dart';
import 'api_client.dart';

/// Penugasan teknisi (poin 8). Teknisi cuma dapat punyanya — penyaringnya di
/// SERVER, bukan dengan menyembunyikan tab di sini.
abstract class PenugasanService {
  Future<List<Penugasan>> daftar(String token, {String? status});

  Future<Penugasan> detail(String token, int id);

  /// [teknisi] berurutan: yang PERTAMA jadi ketua.
  Future<Penugasan> buat(
    String token, {
    required String judul,
    required List<int> teknisi,
    required List<BarisPenugasan> baris,
    DateTime? tanggalTarget,
    String? catatan,
  });

  /// Boleh melebihi rencana (paketnya ternyata berisi 12, bukan 10).
  Future<Penugasan> laporProgres(
    String token,
    int barisId, {
    required int jumlahSelesai,
    String? catatan,
  });

  /// Waktu PERTAMA teknisi membuka tugasnya.
  Future<void> tandaiDilihat(String token, int id);
}

class ApiPenugasanService implements PenugasanService {
  ApiPenugasanService(this._api);

  final ApiClient _api;

  @override
  Future<List<Penugasan>> daftar(String token, {String? status}) async {
    final q = status == null ? '' : '?status=${Uri.encodeQueryComponent(status)}';
    final json = await _api.get('/penugasan$q', token: token);
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final d in data.whereType<Map<String, dynamic>>())
        Penugasan.fromJson(d),
    ];
  }

  @override
  Future<Penugasan> detail(String token, int id) async {
    final json = await _api.get('/penugasan/$id', token: token);
    return Penugasan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Penugasan> buat(
    String token, {
    required String judul,
    required List<int> teknisi,
    required List<BarisPenugasan> baris,
    DateTime? tanggalTarget,
    String? catatan,
  }) async {
    final json = await _api.post(
      '/penugasan',
      token: token,
      body: {
        'judul': judul,
        'teknisi': teknisi,
        'item': [for (final b in baris) b.keJson()],
        if (tanggalTarget != null)
          'tanggal_target': tanggalTarget.toIso8601String().substring(0, 10),
        if (catatan != null && catatan.trim().isNotEmpty) 'catatan': catatan.trim(),
      },
    );
    return Penugasan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Penugasan> laporProgres(
    String token,
    int barisId, {
    required int jumlahSelesai,
    String? catatan,
  }) async {
    final json = await _api.patch(
      '/penugasan/item/$barisId',
      token: token,
      body: {
        'jumlah_selesai': jumlahSelesai,
        if (catatan != null) 'catatan': catatan,
      },
    );
    return Penugasan.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> tandaiDilihat(String token, int id) async {
    await _api.post('/penugasan/$id/dilihat', token: token);
  }
}

class MockPenugasanService implements PenugasanService {
  final List<Penugasan> _daftar = [
    Penugasan(
      id: 7,
      judul: 'Kalibrasi minggu ini',
      tipe: 'grup',
      status: 'aktif',
      tanggalTarget: DateTime(2026, 10, 2),
      terlambat: false,
      persenTuntas: 43,
      dibuatOleh: 'Alex Mursito',
      teknisi: const [
        AnggotaPenugasan(id: 2, nama: 'Rizky Pratama', kode: 'RZP', peran: 'ketua'),
        AnggotaPenugasan(id: 5, nama: 'Hana Wijayanti', kode: 'HWJ', peran: 'anggota'),
      ],
      baris: const [
        BarisPenugasan(id: 1, jenisAlat: 'Autoklaf', jumlah: 4, jumlahSelesai: 2),
        BarisPenugasan(id: 2, jenisAlat: 'Timbangan analitik', jumlah: 3, jumlahSelesai: 1),
      ],
    ),
  ];

  @override
  Future<List<Penugasan>> daftar(String token, {String? status}) async =>
      _daftar.where((p) => status == null || p.status == status).toList();

  @override
  Future<Penugasan> detail(String token, int id) async =>
      _daftar.firstWhere((p) => p.id == id);

  @override
  Future<Penugasan> buat(
    String token, {
    required String judul,
    required List<int> teknisi,
    required List<BarisPenugasan> baris,
    DateTime? tanggalTarget,
    String? catatan,
  }) async {
    final baru = Penugasan(
      id: _daftar.length + 100,
      judul: judul,
      tipe: teknisi.length > 1 ? 'grup' : 'personal',
      status: 'aktif',
      tanggalTarget: tanggalTarget,
      terlambat: false,
      persenTuntas: 0,
      catatan: catatan,
      baris: baris,
    );
    _daftar.insert(0, baru);
    return baru;
  }

  @override
  Future<Penugasan> laporProgres(
    String token,
    int barisId, {
    required int jumlahSelesai,
    String? catatan,
  }) async => _daftar.first;

  @override
  Future<void> tandaiDilihat(String token, int id) async {}
}

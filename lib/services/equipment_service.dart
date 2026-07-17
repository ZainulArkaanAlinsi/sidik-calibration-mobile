import '../models/equipment.dart';
import 'api_client.dart';

/// Satu halaman hasil `GET /api/equipments` — item + info paginasi Laravel
/// yang dipakai mobile (`halamanTerakhir`, superset lain diabaikan).
class EquipmentPage {
  const EquipmentPage({required this.items, required this.halamanTerakhir});

  final List<Equipment> items;
  final int halamanTerakhir;
}

abstract class EquipmentService {
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  });

  Future<Equipment> tambah(String token, Equipment equipment, {int? pelangganId});

  Future<Equipment> ubah(
    String token,
    int id,
    Equipment equipment, {
    int? pelangganId,
  });

  Future<void> hapus(String token, int id);
}

/// Nembak `/api/equipments` beneran (live 14 Jul — lihat `docs/kontrak-api.md`
/// §3). Baca boleh semua role; tulis (`tambah`/`ubah`/`hapus`) admin & teknisi
/// doang — viewer ditolak `403` di backend, mobile cuma nyembunyiin tombolnya.
class ApiEquipmentService implements EquipmentService {
  ApiEquipmentService(this._api);

  final ApiClient _api;

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async {
    final json = await _api.get(
      '/equipments',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        'category': ?kategori,
        'status': ?status,
        'page': '$page',
      },
      token: token,
    );

    final items = (json['data'] as List<dynamic>? ?? const [])
        .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>?;

    return EquipmentPage(
      items: items,
      halamanTerakhir: (meta?['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<Equipment> tambah(
    String token,
    Equipment equipment, {
    int? pelangganId,
  }) async {
    final json = await _api.post(
      '/equipments',
      body: equipment.toJson(pelangganId: pelangganId),
      token: token,
    );
    return Equipment.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Equipment> ubah(
    String token,
    int id,
    Equipment equipment, {
    int? pelangganId,
  }) async {
    final json = await _api.put(
      '/equipments/$id',
      body: equipment.toJson(pelangganId: pelangganId),
      token: token,
    );
    return Equipment.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/equipments/$id', token: token);
  }
}

/// Data tiruan — dipakai test & mode offline (`--dart-define=USE_MOCK=true`).
/// Seeded 5 alat (2 overdue), sama kayak catatan seeder di kontrak API, dan
/// beneran mutable (nyimpen tambah/ubah/hapus di memori) biar form kerasa
/// fungsional tanpa server nyala.
class MockEquipmentService implements EquipmentService {
  MockEquipmentService({
    this.gagal = false,
    bool kosong = false,
    this.jeda = const Duration(milliseconds: 500),
  }) : _items = kosong ? [] : _seed();

  final bool gagal;
  final Duration jeda;
  final List<Equipment> _items;
  int _nextId = 6;

  static List<Equipment> _seed() => [
    Equipment(
      id: 1,
      namaAlat: 'Jangka Sorong Mitutoyo',
      serialNumber: 'MT-500-196-30',
      kategori: 'panjang',
      merk: 'Mitutoyo',
      status: EquipmentStatus.aktif,
      pelanggan: const EquipmentCustomer(id: 3, nama: 'PT Maju Jaya'),
      tanggalKalibrasiTerakhir: DateTime(2026, 1, 15),
      tanggalJatuhTempo: DateTime(2027, 1, 15),
      toleransi: 0.05,
    ),
    Equipment(
      id: 2,
      namaAlat: 'Timbangan Digital Ohaus',
      serialNumber: 'OH-200-88',
      kategori: 'massa',
      merk: 'Ohaus',
      status: EquipmentStatus.overdue,
      pelanggan: const EquipmentCustomer(id: 3, nama: 'PT Maju Jaya'),
      tanggalKalibrasiTerakhir: DateTime(2025, 5, 1),
      tanggalJatuhTempo: DateTime(2026, 6, 1),
      toleransi: 0.02,
    ),
    Equipment(
      id: 3,
      namaAlat: 'Termometer Digital Fluke',
      serialNumber: 'FL-1523-12',
      kategori: 'suhu-dan-kelembapan',
      merk: 'Fluke',
      status: EquipmentStatus.overdue,
      pelanggan: const EquipmentCustomer(id: 5, nama: 'PT Sumber Makmur'),
      tanggalKalibrasiTerakhir: DateTime(2025, 4, 20),
      tanggalJatuhTempo: DateTime(2026, 5, 20),
    ),
    Equipment(
      id: 4,
      namaAlat: 'Pressure Gauge WIKA',
      serialNumber: 'WK-77-441',
      kategori: 'tekanan',
      merk: 'WIKA',
      status: EquipmentStatus.aktif,
      pelanggan: const EquipmentCustomer(id: 5, nama: 'PT Sumber Makmur'),
      tanggalKalibrasiTerakhir: DateTime(2026, 3, 10),
      tanggalJatuhTempo: DateTime(2027, 3, 10),
      toleransi: 0.5,
    ),
    Equipment(
      id: 5,
      namaAlat: 'Gelas Ukur Pyrex',
      serialNumber: 'PX-500ML-9',
      kategori: 'volume',
      merk: 'Pyrex',
      status: EquipmentStatus.nonaktif,
    ),
  ];

  Future<void> _tunggu() async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
  }

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async {
    await _tunggu();
    if (gagal) throw Exception('server nggak nyaut');

    var hasil = _items.toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      hasil = hasil
          .where(
            (e) =>
                e.namaAlat.toLowerCase().contains(q) ||
                e.serialNumber.toLowerCase().contains(q),
          )
          .toList();
    }
    if (kategori != null) {
      hasil = hasil.where((e) => e.kategori == kategori).toList();
    }
    if (status != null) {
      hasil = hasil.where((e) => e.status.apiValue == status).toList();
    }

    return EquipmentPage(items: hasil, halamanTerakhir: 1);
  }

  @override
  Future<Equipment> tambah(
    String token,
    Equipment equipment, {
    int? pelangganId,
  }) async {
    await _tunggu();
    if (gagal) throw Exception('server nggak nyaut');

    final baru = Equipment(
      id: _nextId++,
      namaAlat: equipment.namaAlat,
      serialNumber: equipment.serialNumber,
      kategori: equipment.kategori,
      merk: equipment.merk,
      status: equipment.status,
      pelanggan: pelangganId == null
          ? null
          : EquipmentCustomer(id: pelangganId, nama: 'Pelanggan #$pelangganId'),
      toleransi: equipment.toleransi,
    );
    _items.add(baru);
    return baru;
  }

  @override
  Future<Equipment> ubah(
    String token,
    int id,
    Equipment equipment, {
    int? pelangganId,
  }) async {
    await _tunggu();
    if (gagal) throw Exception('server nggak nyaut');

    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) throw Exception('Alat nggak ketemu');

    final lama = _items[idx];
    final baru = Equipment(
      id: id,
      namaAlat: equipment.namaAlat,
      serialNumber: equipment.serialNumber,
      kategori: equipment.kategori,
      merk: equipment.merk,
      status: equipment.status,
      pelanggan: pelangganId == null
          ? lama.pelanggan
          : EquipmentCustomer(id: pelangganId, nama: 'Pelanggan #$pelangganId'),
      tanggalKalibrasiTerakhir: lama.tanggalKalibrasiTerakhir,
      tanggalJatuhTempo: lama.tanggalJatuhTempo,
      toleransi: equipment.toleransi,
    );
    _items[idx] = baru;
    return baru;
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _tunggu();
    if (gagal) throw Exception('server nggak nyaut');
    _items.removeWhere((e) => e.id == id);
  }
}

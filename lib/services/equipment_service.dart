import '../models/equipment.dart';
import 'api_client.dart';

/// CRUD Alat penuh (`docs/kontrak-api.md` §3) — beda sama
/// [EquipmentLookupService] yang cuma buat picker di layar Input Kalibrasi.
///
/// Baca boleh semua role; nulis (`simpan`/`ubah`/`hapus`) admin & teknisi
/// doang — viewer dapat `403` dari backend, ditampilin apa adanya lewat
/// [AuthException] dari [ApiClient].
abstract class EquipmentService {
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  });

  Future<Equipment> simpan(String token, Equipment data);

  Future<Equipment> ubah(String token, Equipment data);

  Future<void> hapus(String token, int id);
}

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
    final params = <String>[
      if (search != null && search.isNotEmpty)
        'search=${Uri.encodeQueryComponent(search)}',
      if (kategori != null && kategori.isNotEmpty)
        'category=${Uri.encodeQueryComponent(kategori)}',
      if (status != null && status.isNotEmpty)
        'status=${Uri.encodeQueryComponent(status)}',
      'page=$page',
    ];
    final json = await _api.get('/equipments?${params.join('&')}', token: token);
    return EquipmentPage.fromJson(json);
  }

  @override
  Future<Equipment> simpan(String token, Equipment data) async {
    final json = await _api.post(
      '/equipments',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Equipment.fromJson(result);
  }

  @override
  Future<Equipment> ubah(String token, Equipment data) async {
    final json = await _api.put(
      '/equipments/${data.id}',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Equipment.fromJson(result);
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/equipments/$id', token: token);
  }
}

/// Data tiruan buat test.
class MockEquipmentService implements EquipmentService {
  MockEquipmentService({this.gagal = false});

  final bool gagal;

  final List<Equipment> _data = [
    const Equipment(
      id: 12,
      namaAlat: 'Jangka Sorong Mitutoyo',
      serialNumber: 'MT-500-196-30',
      kategori: 'panjang',
      status: EquipmentStatus.aktif,
      merk: 'Mitutoyo',
      model: 'CD-15APX',
      pelangganId: 1,
      pelangganNama: 'PT Maju Jaya',
      rangeMin: 0,
      rangeMax: 150,
      satuan: 'mm',
      resolusi: 0.01,
      toleransi: 0.02,
      lokasi: 'Lab. Uji A',
    ),
    const Equipment(
      id: 13,
      namaAlat: 'Timbangan Digital Ohaus',
      serialNumber: 'OH-8825-01',
      kategori: 'massa',
      status: EquipmentStatus.overdue,
      merk: 'Ohaus',
      pelangganId: 2,
      pelangganNama: 'CV Sentosa Abadi',
      satuan: 'g',
      lokasi: 'Lab. Uji B',
    ),
    const Equipment(
      id: 14,
      namaAlat: 'pH Meter Mettler Toledo',
      serialNumber: 'B628755900',
      kategori: 'instrumen-analitik',
      status: EquipmentStatus.aktif,
      merk: 'Mettler Toledo',
      model: 'Five Easy',
      pelangganId: 1,
      pelangganNama: 'PT Maju Jaya',
      rangeMin: 0,
      rangeMax: 14,
      satuan: 'pH',
      resolusi: 0.01,
      lokasi: 'Lab. Uji A',
    ),
  ];

  int get _nextId => _data.isEmpty
      ? 1
      : _data.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    final hasil = _data.where((e) {
      final cocokSearch = search == null ||
          search.isEmpty ||
          e.namaAlat.toLowerCase().contains(search.toLowerCase());
      final cocokKategori =
          kategori == null || kategori.isEmpty || e.kategori == kategori;
      final cocokStatus =
          status == null || status.isEmpty || e.status.rawValue == status;
      return cocokSearch && cocokKategori && cocokStatus;
    }).toList();

    return EquipmentPage(items: hasil, currentPage: 1, lastPage: 1);
  }

  @override
  Future<Equipment> simpan(String token, Equipment data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final baru = Equipment(
      id: _nextId,
      namaAlat: data.namaAlat,
      serialNumber: data.serialNumber,
      kategori: data.kategori,
      status: data.status,
      merk: data.merk,
      model: data.model,
      noIdentifikasi: data.noIdentifikasi,
      pelangganId: data.pelangganId,
      pelangganNama: data.pelangganNama,
      rangeMin: data.rangeMin,
      rangeMax: data.rangeMax,
      satuan: data.satuan,
      resolusi: data.resolusi,
      toleransi: data.toleransi,
      lokasi: data.lokasi,
    );
    _data.add(baru);
    return baru;
  }

  @override
  Future<Equipment> ubah(String token, Equipment data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final index = _data.indexWhere((e) => e.id == data.id);
    if (index != -1) _data[index] = data;
    return data;
  }

  @override
  Future<void> hapus(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    _data.removeWhere((e) => e.id == id);
  }
}

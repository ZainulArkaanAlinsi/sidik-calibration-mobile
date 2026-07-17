import '../models/equipment_lookup.dart';
import 'api_client.dart';

/// Cuma buat picker "Alat" di layar Input Kalibrasi — bukan layanan CRUD
/// Alat yang lengkap (itu domain layar Alat sendiri).
abstract class EquipmentLookupService {
  Future<List<EquipmentLookup>> cari(String token, {String? search, String? kategori});
}

/// Nembak `GET /api/equipments` — live sejak 14 Jul (`docs/kontrak-api.md`
/// §3), baca boleh semua role.
class ApiEquipmentLookupService implements EquipmentLookupService {
  ApiEquipmentLookupService(this._api);

  final ApiClient _api;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
  }) async {
    final params = <String>[
      if (search != null && search.isNotEmpty)
        'search=${Uri.encodeQueryComponent(search)}',
      if (kategori != null && kategori.isNotEmpty)
        'category=${Uri.encodeQueryComponent(kategori)}',
    ];
    final path = params.isEmpty ? '/equipments' : '/equipments?${params.join('&')}';

    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data
        .cast<Map<String, dynamic>>()
        .map(EquipmentLookup.fromJson)
        .toList();
  }
}

/// Data tiruan buat test.
class MockEquipmentLookupService implements EquipmentLookupService {
  MockEquipmentLookupService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    final semua = const [
      EquipmentLookup(
        id: 12,
        namaAlat: 'Jangka Sorong Mitutoyo',
        serialNumber: 'MT-500-196-30',
        kategori: 'panjang',
        status: 'aktif',
      ),
      EquipmentLookup(
        id: 13,
        namaAlat: 'Timbangan Digital Ohaus',
        serialNumber: 'OH-8825-01',
        kategori: 'massa',
        status: 'overdue',
      ),
    ];

    return semua.where((e) {
      final cocokKategori = kategori == null || kategori.isEmpty || e.kategori == kategori;
      final cocokSearch = search == null ||
          search.isEmpty ||
          e.namaAlat.toLowerCase().contains(search.toLowerCase());
      return cocokKategori && cocokSearch;
    }).toList();
  }
}

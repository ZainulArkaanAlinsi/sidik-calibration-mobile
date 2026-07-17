import '../models/standard.dart';
import 'api_client.dart';

abstract class StandardService {
  Future<List<Standard>> daftar(String token);
}

/// Nembak `GET /api/standards` — live sejak 14 Jul, semua role
/// (`docs/kontrak-api.md` §4). Nggak dipaginasi.
class ApiStandardService implements StandardService {
  ApiStandardService(this._api);

  final ApiClient _api;

  @override
  Future<List<Standard>> daftar(String token) async {
    final json = await _api.get('/standards', token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data.cast<Map<String, dynamic>>().map(Standard.fromJson).toList();
  }
}

/// Data tiruan buat test.
class MockStandardService implements StandardService {
  MockStandardService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<Standard>> daftar(String token) async {
    if (gagal) throw Exception('server nggak nyaut');

    return const [
      Standard(
        id: 1,
        nama: 'Gauge Block Set Grade 0',
        merk: 'Mitutoyo',
        serialNumber: 'GB-STD-001',
        masihBerlaku: true,
        ketidakpastian: 0.0004,
        satuanKetidakpastian: 'mm',
        faktorCakupan: 2,
      ),
      Standard(
        id: 2,
        nama: 'Standar Massa Kelas F1',
        merk: 'Mettler Toledo',
        serialNumber: 'MS-STD-002',
        masihBerlaku: false,
        ketidakpastian: 0.002,
        satuanKetidakpastian: 'g',
        faktorCakupan: 2,
      ),
      Standard(
        id: 3,
        nama: 'pH Buffer Solution 7',
        merk: 'Supelco/Merck',
        serialNumber: 'HC46341939',
        masihBerlaku: true,
        ketidakpastian: 0.02,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
      ),
    ];
  }
}

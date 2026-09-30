import '../models/customer.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';
import 'auth_service.dart' show AuthException;

/// Kalau pelanggan masih punya alat, `hapus()` ngelempar `AuthException`
/// (dari `ApiClient`) dengan pesan asli dari backend (`422`) —
/// `docs/kontrak-api.md` §8 minta itu ditampilin apa adanya, bukan diganti.
abstract class CustomerService {
  Future<List<Customer>> daftar(String token, {String? search});

  /// Satu pelanggan lengkap (`GET /customers/{id}`) — dipakai Pusat pelanggan.
  Future<Customer> detail(String token, int id);

  Future<Customer> simpan(String token, Customer data);

  Future<Customer> ubah(String token, Customer data);

  Future<void> hapus(String token, int id);
}

/// Nembak `GET/POST/PUT/DELETE /api/customers` — admin doang, live sejak
/// 14 Jul (`docs/kontrak-api.md` §8).
class ApiCustomerService implements CustomerService {
  ApiCustomerService(this._api);

  final ApiClient _api;

  @override
  Future<List<Customer>> daftar(String token, {String? search}) async {
    final path = search == null || search.isEmpty
        ? '/customers'
        : '/customers?search=${Uri.encodeQueryComponent(search)}';
    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return parseListAman(data, Customer.fromJson);
  }

  @override
  Future<Customer> detail(String token, int id) async {
    final json = await _api.get('/customers/$id', token: token);
    return Customer.fromJson((json['data'] ?? json) as Map<String, dynamic>);
  }

  @override
  Future<Customer> simpan(String token, Customer data) async {
    final json = await _api.post(
      '/customers',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Customer.fromJson(result);
  }

  @override
  Future<Customer> ubah(String token, Customer data) async {
    final json = await _api.put(
      '/customers/${data.id}',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Customer.fromJson(result);
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/customers/$id', token: token);
  }
}

/// Data tiruan buat test.
class MockCustomerService implements CustomerService {
  /// [awal] mengganti daftar bawaan (test & golden yang butuh pelanggan
  /// tertentu) tanpa menyentuh data yang dipakai puluhan test lain.
  MockCustomerService({this.gagal = false, List<Customer>? awal}) {
    if (awal != null) {
      _data
        ..clear()
        ..addAll(awal);
    }
  }

  final bool gagal;

  final List<Customer> _data = [
    const Customer(
      id: 1,
      nama: 'PT Maju Jaya',
      alamat: 'Jl. Industri No. 5, Bekasi',
      contactPerson: 'Budi Santoso',
      telepon: '021-9876543',
      email: 'budi@majujaya.co.id',
      jumlahAlat: 3,
    ),
    const Customer(
      id: 2,
      nama: 'CV Sentosa Abadi',
      alamat: 'Jl. Raya No. 10, Tangerang',
      contactPerson: 'Siti Rahayu',
      telepon: '021-1112223',
      email: 'siti@sentosaabadi.co.id',
      jumlahAlat: 0,
    ),
  ];

  @override
  Future<List<Customer>> daftar(String token, {String? search}) async {
    if (gagal) throw Exception('server nggak nyaut');
    if (search == null || search.isEmpty) return List.unmodifiable(_data);

    final q = search.toLowerCase();
    return _data.where((c) => c.nama.toLowerCase().contains(q)).toList();
  }

  @override
  Future<Customer> detail(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    return _data.firstWhere((c) => c.id == id);
  }

  @override
  Future<Customer> simpan(String token, Customer data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final baru = Customer(
      id:
          (_data.isEmpty
              ? 0
              : _data.map((c) => c.id).reduce((a, b) => a > b ? a : b)) +
          1,
      nama: data.nama,
      alamat: data.alamat,
      contactPerson: data.contactPerson,
      telepon: data.telepon,
      email: data.email,
    );
    _data.add(baru);
    return baru;
  }

  @override
  Future<Customer> ubah(String token, Customer data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final index = _data.indexWhere((c) => c.id == data.id);
    if (index != -1) _data[index] = data;
    return data;
  }

  @override
  Future<void> hapus(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    final target = _data.firstWhere((c) => c.id == id);
    if (target.jumlahAlat > 0) {
      throw const AuthException(
        'Pelanggan ini masih punya alat terdaftar, nggak bisa dihapus.',
      );
    }
    _data.removeWhere((c) => c.id == id);
  }
}

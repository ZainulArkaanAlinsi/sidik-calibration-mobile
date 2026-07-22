import '../models/customer_lookup.dart';
import 'api_client.dart';

/// Daftar pelanggan buat **dropdown** — bukan layanan CRUD Pelanggan
/// (itu [CustomerService], khusus layar Pelanggan yang admin-only).
abstract class CustomerLookupService {
  Future<List<CustomerLookup>> cari(String token, {String? search});
}

/// Nembak `GET /api/arsip/perusahaan` — sengaja **bukan** `GET /api/customers`.
///
/// `/customers` itu admin-only, padahal `POST /equipments` boleh dipakai
/// teknisi. Waktu dropdown pelanggan di form Tambah Alat masih narik dari
/// `/customers`, hasilnya: form-nya jalan mulus waktu dites pakai akun admin,
/// tapi di akun teknisi request-nya ditolak 403 → dropdown kosong. Dan karena
/// `pelanggan_id` itu **wajib**, teknisi jadi nggak bisa nyimpen alat sama
/// sekali — mentok di form tanpa penjelasan.
///
/// `/arsip/perusahaan` kebuka buat semua role dan ngasih persis yang
/// dibutuhin dropdown (`id` + `nama`), plus dukung `?search=`.
class ApiCustomerLookupService implements CustomerLookupService {
  ApiCustomerLookupService(this._api);

  final ApiClient _api;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    final path = search == null || search.isEmpty
        ? '/arsip/perusahaan'
        : '/arsip/perusahaan?search=${Uri.encodeQueryComponent(search)}';

    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data
        .cast<Map<String, dynamic>>()
        .map(CustomerLookup.fromJson)
        .toList();
  }
}

/// Data tiruan buat test.
class MockCustomerLookupService implements CustomerLookupService {
  MockCustomerLookupService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<CustomerLookup>> cari(String token, {String? search}) async {
    if (gagal) throw Exception('server nggak nyaut');

    const semua = [
      CustomerLookup(id: 1, nama: 'PT Maju Jaya'),
      CustomerLookup(id: 2, nama: 'CV Sentosa Abadi'),
      CustomerLookup(id: 3, nama: 'PT Industri Presisi'),
    ];

    if (search == null || search.isEmpty) return semua;

    final q = search.toLowerCase();
    return semua.where((c) => c.nama.toLowerCase().contains(q)).toList();
  }
}

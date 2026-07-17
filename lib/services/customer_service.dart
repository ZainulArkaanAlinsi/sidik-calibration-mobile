import '../models/customer.dart';
import 'api_client.dart';

abstract class CustomerService {
  Future<List<Customer>> cari(String token, {String? search});
}

/// `GET /api/customers?search=` — **admin-only** di kontrak API §8. Teknisi
/// & viewer dapat `403`, jadi cuma dipanggil dari form Alat waktu user-nya
/// admin (lihat `equipment_form_screen.dart`).
class ApiCustomerService implements CustomerService {
  ApiCustomerService(this._api);

  final ApiClient _api;

  @override
  Future<List<Customer>> cari(String token, {String? search}) async {
    final json = await _api.get(
      '/customers',
      query: {if (search != null && search.isNotEmpty) 'search': search},
      token: token,
    );
    return (json['data'] as List<dynamic>? ?? const [])
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Data tiruan buat mode offline/test.
class MockCustomerService implements CustomerService {
  const MockCustomerService();

  static const _pelanggan = [
    Customer(id: 3, nama: 'PT Maju Jaya'),
    Customer(id: 5, nama: 'PT Sumber Makmur'),
  ];

  @override
  Future<List<Customer>> cari(String token, {String? search}) async {
    if (search == null || search.isEmpty) return _pelanggan;
    final q = search.toLowerCase();
    return _pelanggan.where((c) => c.nama.toLowerCase().contains(q)).toList();
  }
}

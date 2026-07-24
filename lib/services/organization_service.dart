import '../models/organization.dart';
import 'api_client.dart';

abstract class OrganizationService {
  Future<Organization> ambil(String token);

  Future<Organization> simpan(String token, Organization data);
}

/// Nembak `GET`/`PUT /api/organization` — admin doang, live sejak 14 Jul
/// (`docs/kontrak-api.md` §8).
class ApiOrganizationService implements OrganizationService {
  ApiOrganizationService(this._api);

  final ApiClient _api;

  @override
  Future<Organization> ambil(String token) async {
    final json = await _api.get('/organization', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return Organization.fromJson(data);
  }

  @override
  Future<Organization> simpan(String token, Organization data) async {
    final json = await _api.put(
      '/organization',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Organization.fromJson(result);
  }
}

/// Data tiruan buat test.
class MockOrganizationService implements OrganizationService {
  MockOrganizationService({this.gagal = false});

  final bool gagal;

  Organization _data = const Organization(
    nama: 'PT Sistem Dirgantara Inovasi Teknologi (PT Sidik)',
    alamat: 'Jl. Contoh No. 1, Jakarta',
    telepon: '021-1234567',
    email: 'info@ptsidik.co.id',
    noAkreditasi: 'LK-285-IDN',
  );

  @override
  Future<Organization> ambil(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    return _data;
  }

  @override
  Future<Organization> simpan(String token, Organization data) async {
    if (gagal) throw Exception('server nggak nyaut');
    _data = data;
    return _data;
  }
}

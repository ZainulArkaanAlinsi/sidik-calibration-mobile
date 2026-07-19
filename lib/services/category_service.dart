import '../models/category.dart';
import 'api_client.dart';

abstract class CategoryService {
  Future<List<Category>> daftar(String token);

  /// `GET /api/categories/{kode}` — daftar penuh kemampuan kalibrasi (CMC)
  /// kategori itu, dipakai buat dropdown "Jenis Alat (Kemampuan Kalibrasi)"
  /// di form Alat (`docs/kontrak-api.md` §3).
  Future<CategoryDetail> detail(String token, String kode);
}

/// Nembak `GET /api/categories` — live sejak 14 Jul, semua role
/// (`docs/kontrak-api.md` §3). Nggak dipaginasi, 10 kategori doang.
class ApiCategoryService implements CategoryService {
  ApiCategoryService(this._api);

  final ApiClient _api;

  @override
  Future<List<Category>> daftar(String token) async {
    final json = await _api.get('/categories', token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data.cast<Map<String, dynamic>>().map(Category.fromJson).toList();
  }

  @override
  Future<CategoryDetail> detail(String token, String kode) async {
    final json = await _api.get('/categories/$kode', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return CategoryDetail.fromJson(data);
  }
}

/// Data tiruan buat test — 10 kategori lampiran akreditasi.
class MockCategoryService implements CategoryService {
  MockCategoryService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<Category>> daftar(String token) async {
    if (gagal) throw Exception('server nggak nyaut');

    return const [
      Category(kode: 'panjang', nama: 'Panjang', satuan: 'mm'),
      Category(kode: 'massa', nama: 'Massa', satuan: 'g'),
      Category(kode: 'suhu-dan-kelembapan', nama: 'Suhu & Kelembapan', satuan: '°C'),
      Category(kode: 'tekanan', nama: 'Tekanan', satuan: 'bar'),
    ];
  }

  @override
  Future<CategoryDetail> detail(String token, String kode) async {
    if (gagal) throw Exception('server nggak nyaut');

    const kemampuanPanjang = [
      CalibrationCapability(
        namaAlat: 'Jangka Sorong',
        rangeMin: 0,
        rangeMax: 150,
        satuan: 'mm',
        ketidakpastianTerbaik: 0.02,
        satuanKetidakpastian: 'mm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0515_Rev.3',
      ),
      CalibrationCapability(
        namaAlat: 'Micrometer',
        rangeMin: 0,
        rangeMax: 25,
        satuan: 'mm',
        ketidakpastianTerbaik: 0.00083,
        satuanKetidakpastian: 'mm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0515_Rev.3',
      ),
    ];

    return switch (kode) {
      'panjang' => const CategoryDetail(
        kode: 'panjang',
        nama: 'Panjang',
        kemampuan: kemampuanPanjang,
      ),
      _ => CategoryDetail(kode: kode, nama: kode, kemampuan: const []),
    };
  }
}

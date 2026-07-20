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
      Category(kode: 'instrumen-analitik', nama: 'Instrumen Analitik', satuan: 'pH'),
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

    // 3 baris pH (titik 4/7/10) + 1 alat lain — persis kasus nyata di
    // `instrumen-analitik`, dipakai buat mastiin `InstrumentPickerScreen`
    // nge-dedupe 3 baris pH itu jadi 1 kartu "pH Meter".
    const kemampuanInstrumenAnalitik = [
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 4,
        rangeMax: 4,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.02343221,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0506_Rev.6',
      ),
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 7,
        rangeMax: 7,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.02110895,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0506_Rev.6',
      ),
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 10,
        rangeMax: 10,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.03032720,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0506_Rev.6',
      ),
      CalibrationCapability(
        
        namaAlat: 'Conductivity Meter',
        rangeMin: 0,
        rangeMax: 1000,
        satuan: 'µS/cm',
        ketidakpastianTerbaik: 1.5,
        satuanKetidakpastian: 'µS/cm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0507_Rev.6',
      ),
    ];

    return switch (kode) {
      'panjang' => const CategoryDetail(
        kode: 'panjang',
        nama: 'Panjang',
        kemampuan: kemampuanPanjang,
      ),
      'instrumen-analitik' => const CategoryDetail(
        kode: 'instrumen-analitik',
        nama: 'Instrumen Analitik',
        kemampuan: kemampuanInstrumenAnalitik,
      ),
      _ => CategoryDetail(kode: kode, nama: kode, kemampuan: const []),
    };
  }
}

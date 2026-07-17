import '../models/category.dart';
import 'api_client.dart';

abstract class CategoryService {
  Future<List<CalibrationCategory>> daftar(String token);
}

/// `GET /api/categories` (live 14 Jul) — nggak pakai paginasi, daftarnya
/// pendek (10 kategori), langsung kekirim semua.
class ApiCategoryService implements CategoryService {
  ApiCategoryService(this._api);

  final ApiClient _api;

  @override
  Future<List<CalibrationCategory>> daftar(String token) async {
    final json = await _api.get('/categories', token: token);
    return (json['data'] as List<dynamic>? ?? const [])
        .map((e) => CalibrationCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// 10 kategori dari lampiran akreditasi (`docs/kontrak-api.md` §3) — dipakai
/// mode offline/test. **Jangan dianggap sumber kebenaran**: kalau backend
/// nambah/ubah kategori, yang berlaku tetap `GET /api/categories` beneran.
class MockCategoryService implements CategoryService {
  const MockCategoryService();

  static const _kategori = [
    CalibrationCategory(kode: 'panjang', nama: 'Panjang'),
    CalibrationCategory(kode: 'massa', nama: 'Massa'),
    CalibrationCategory(kode: 'volume', nama: 'Volume'),
    CalibrationCategory(kode: 'tekanan', nama: 'Tekanan'),
    CalibrationCategory(kode: 'gaya', nama: 'Gaya'),
    CalibrationCategory(kode: 'aliran', nama: 'Aliran'),
    CalibrationCategory(kode: 'densitas', nama: 'Densitas'),
    CalibrationCategory(kode: 'instrumen-analitik', nama: 'Instrumen Analitik'),
    CalibrationCategory(
      kode: 'suhu-dan-kelembapan',
      nama: 'Suhu & Kelembapan',
    ),
    CalibrationCategory(
      kode: 'waktu-dan-frekuensi',
      nama: 'Waktu & Frekuensi',
    ),
  ];

  @override
  Future<List<CalibrationCategory>> daftar(String token) async => _kategori;
}

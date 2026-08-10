import '../models/category.dart';
import '../core/utils/parse_list.dart';
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

    return parseListAman(data, Category.fromJson);
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
      // CMC pH ikut LAMPIRAN AKREDITASI (LK-285-IDN no. 41: 0,023 / 0,021 /
      // 0,031), bukan hasil hitung satu sesi. Angka lama di sini (0,02343221 /
      // 0,02110895 / 0,03032720) itu uc hasil hitungan yang kejebak jadi CMC —
      // backend udah dibenerin di `07078c3`, mobile-nya ketinggalan, jadi kartu
      // di layar beda dari yang dipakai ngitung sertifikat.
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 4,
        rangeMax: 4,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.023,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0506_Rev.6',
      ),
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 7,
        rangeMax: 7,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.021,
        satuanKetidakpastian: 'pH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0506_Rev.6',
      ),
      CalibrationCapability(
        namaAlat: 'pH Meter',
        rangeMin: 10,
        rangeMax: 10,
        satuan: 'pH',
        ketidakpastianTerbaik: 0.031,
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
      // 2 titik Chlorin Meter — angkanya dari lampiran akreditasi LK-285-IDN
      // no. 42 (`docs/Rekap-Data-Kemampuan-Kalibrasi.md`), dan sama persis sama
      // `Chlorine_Meter_CSV/DATABASE.csv`. Namanya ditulis "Chlorin" (tanpa
      // 'e') karena begitu bunyinya di lampiran — backend narik dari situ.
      // Lembar kerjanya sendiri nulis "Chlorine"; dua-duanya dikenali
      // `InstrumentPickerScreen.profilUntuk`.
      CalibrationCapability(
        namaAlat: 'Chlorin Meter',
        rangeMin: 1.74,
        rangeMax: 1.74,
        satuan: 'mg/L',
        ketidakpastianTerbaik: 0.091,
        satuanKetidakpastian: 'mg/L',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0524_Rev.1',
      ),
      CalibrationCapability(
        namaAlat: 'Chlorin Meter',
        rangeMin: 1.83,
        rangeMax: 1.83,
        satuan: 'mg/L',
        ketidakpastianTerbaik: 0.08,
        satuanKetidakpastian: 'mg/L',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0524_Rev.1',
      ),
      // 3 titik Turbidimeter (CMC 0,041/3,1/22 NTU) — biar di USE_MOCK kartu
      // "Turbidimeter" muncul & bisa dites offline, nyambung ke profil
      // turbidimeter (larutan 1/100/1000 NTU). Tanpa ini, build mock nggak
      // punya jalan buat nyoba worksheet turbidimeter sama sekali.
      CalibrationCapability(
        namaAlat: 'Turbidimeter',
        rangeMin: 1,
        rangeMax: 1,
        satuan: 'NTU',
        ketidakpastianTerbaik: 0.041,
        satuanKetidakpastian: 'NTU',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0523_Rev.1',
      ),
      CalibrationCapability(
        namaAlat: 'Turbidimeter',
        rangeMin: 100,
        rangeMax: 100,
        satuan: 'NTU',
        ketidakpastianTerbaik: 3.1,
        satuanKetidakpastian: 'NTU',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0523_Rev.1',
      ),
      CalibrationCapability(
        namaAlat: 'Turbidimeter',
        rangeMin: 1000,
        rangeMax: 1000,
        satuan: 'NTU',
        ketidakpastianTerbaik: 22,
        satuanKetidakpastian: 'NTU',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0523_Rev.1',
      ),
      // 4 titik Refractometer — angkanya dipetik dari
      // `RefractometerCapabilitySeeder` di backend, yang sendiri nyalin sheet
      // DATABASE `Master Olah Data_Refractometer.xlsm` & lampiran akreditasi
      // LK-285-IDN no. 45. Jangan dibulatkan di sini: kartu di layar mesti sama
      // dengan yang dipakai backend ngitung sertifikat.
      //
      // **Tanpa empat baris ini fiturnya nggak bisa dipakai sama sekali.**
      // Teknisi nyampe ke lembar kerja Refractometer lewat Kategori → Instrumen
      // Analitik → Refractometer, dan kartunya cuma muncul kalau jenis alatnya
      // ada di daftar kemampuan. Ketahuan 7 Agt 2026 waktu app-nya beneran
      // dijalanin di HP: seluruh test hijau, tapi picker-nya cuma nampilin
      // empat alat lama — test-nya manggil `LembarKerjaScreen(profil:
      // 'refractometer')` langsung, jadi ngelewatin pintu masuknya.
      //
      // Dua titik n20D & dua titik °Brix, ikut satu botol fisik yang dibaca dua
      // satuan (BSAG2.5-0034 = 2,5 °Brix DAN 1,33659 n20D). Nilai titiknya versi
      // bulat tabel CMC (1,3366 / 1,3999), beda dari nominal larutan di lembar
      // kerja (1,33659 / 1,39986) — itu dua hal yang berbeda dan memang beda di
      // masternya.
      CalibrationCapability(
        namaAlat: 'Refractometer',
        rangeMin: 1.3366,
        rangeMax: 1.3366,
        satuan: 'n20D',
        ketidakpastianTerbaik: 6.2e-05,
        satuanKetidakpastian: 'n20D',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0516',
      ),
      CalibrationCapability(
        namaAlat: 'Refractometer',
        rangeMin: 1.3999,
        rangeMax: 1.3999,
        satuan: 'n20D',
        ketidakpastianTerbaik: 6.7e-05,
        satuanKetidakpastian: 'n20D',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0516',
      ),
      CalibrationCapability(
        namaAlat: 'Refractometer',
        rangeMin: 2.5,
        rangeMax: 2.5,
        satuan: '°Brix',
        ketidakpastianTerbaik: 0.019,
        satuanKetidakpastian: '°Brix',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0516',
      ),
      CalibrationCapability(
        namaAlat: 'Refractometer',
        rangeMin: 40,
        rangeMax: 40,
        satuan: '°Brix',
        ketidakpastianTerbaik: 0.02,
        satuanKetidakpastian: '°Brix',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0516',
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

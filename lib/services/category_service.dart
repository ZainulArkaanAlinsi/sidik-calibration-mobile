import '../models/category.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Backend nolak nama alatnya karena **udah ada** di kategori itu — `422`
/// dengan keluhannya di `errors.nama_alat` (kontrak `POST
/// /api/categories/{kode}/kemampuan`).
///
/// Dibedain dari gagal lain SENGAJA. Kalau semua kegagalan tampil sebagai
/// "gagal nambah alat", teknisi yang alatnya sebenernya udah terdaftar bakal
/// nyoba lagi dengan nama yang beda tipis ("pH Meter " → "PH meter") sampai
/// ada yang nyangkut — dan daftar kemampuan lab jadi kembar tiga.
class NamaAlatKembarException implements Exception {
  const NamaAlatKembarException(this.namaAlat);

  final String namaAlat;

  @override
  String toString() => 'NamaAlatKembarException($namaAlat)';
}

abstract class CategoryService {
  Future<List<Category>> daftar(String token);

  /// `GET /api/categories/{kode}` — daftar penuh kemampuan kalibrasi (CMC)
  /// kategori itu, dipakai buat dropdown "Jenis Alat (Kemampuan Kalibrasi)"
  /// di form Alat (`docs/kontrak-api.md` §3).
  Future<CategoryDetail> detail(String token, String kode);

  /// `POST /api/categories/{kode}/kemampuan` — teknisi nambah nama alat yang
  /// belum ada di daftar, **tanpa nunggu persetujuan admin**.
  ///
  /// Keputusan pemiliknya begitu: alat yang ditambah langsung bisa dipakai.
  /// Alasannya lapangan — teknisi udah berdiri di depan alat pelanggan, dan
  /// nunggu admin bangun besok pagi artinya sesinya nggak jadi hari itu.
  ///
  /// Yang lahir dari sini `tanpa_cmc: true`: namanya ada, tapi lampiran
  /// akreditasi nggak pernah nyebut dia, jadi nggak ada lantai CMC. Itu WAJIB
  /// diomongin ke teknisi sebelum dia nyimpen — lihat peringatan di
  /// `instrument_picker_screen.dart`.
  ///
  /// Lempar [NamaAlatKembarException] kalau namanya udah kepakai.
  Future<CalibrationCapability> tambahKemampuan(
    String token,
    String kode,
    String namaAlat,
  );
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

  @override
  Future<CalibrationCapability> tambahKemampuan(
    String token,
    String kode,
    String namaAlat,
  ) async {
    try {
      final json = await _api.post(
        '/categories/$kode/kemampuan',
        token: token,
        body: {'nama_alat': namaAlat},
      );

      // `201 { "data": { ...baris kemampuan... } }`. Baris yang balik dipakai
      // apa adanya — dia yang tau `profil` & `tanpa_cmc`-nya, bukan kita.
      final data = (json['data'] ?? json) as Map<String, dynamic>;
      return CalibrationCapability.fromJson(data);
    } on ApiException catch (e) {
      // 422 di sini BUKAN error tak terduga — itu jawaban normal buat nama
      // yang udah kepakai (lihat kontraknya di [CategoryService]). Yang lain
      // (403 role, 404 server lama yang belum punya endpoint ini, 500)
      // diterusin apa adanya biar pesannya nggak dipalsuin jadi "udah ada".
      if (e.status == 422 && _mengeluhNamaAlat(e.body)) {
        throw NamaAlatKembarException(namaAlat);
      }
      rethrow;
    }
  }

  /// `errors.nama_alat` ada isinya = yang ditolak memang kolom namanya.
  ///
  /// Dicek, bukan diasumsikan dari status 422 doang: sekali waktu 422 bisa
  /// datang dari hal lain (rate limit form, kolom lain yang ditambah backend
  /// nanti), dan bilang "alatnya udah ada" buat kegagalan yang bukan itu
  /// nyuruh teknisi nyari kartu yang nggak akan pernah dia temuin.
  bool _mengeluhNamaAlat(Map<String, dynamic> body) {
    final errors = body['errors'];
    return errors is Map && errors['nama_alat'] != null;
  }
}

/// Data tiruan buat test — 10 kategori lampiran akreditasi.
class MockCategoryService implements CategoryService {
  MockCategoryService({this.gagal = false});

  final bool gagal;

  /// Nama alat yang ditambah teknisi lewat [tambahKemampuan], dikelompokin per
  /// kode kategori.
  ///
  /// Nempel di instance, bukan `static`: `categoryServiceProvider` nyimpen satu
  /// [MockCategoryService] selama app nyala, jadi di `USE_MOCK=true` alat yang
  /// barusan ditambah tetap ada waktu layarnya dibuka lagi — sementara tiap
  /// test yang bikin instance sendiri mulai dari daftar yang bersih.
  final Map<String, List<CalibrationCapability>> _tambahan = {};

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
        punyaToleransi: false,
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
      // 3 baris Spectrophotometer — disalin dari
      // `SpectrophotometerCapabilitySeeder` di backend. Sama alasannya kayak
      // Refractometer di atas: **tanpa baris ini lembar kerjanya nggak bisa
      // dibuka lewat jalur mana pun**. Teknisi nyampe ke situ dari Kategori →
      // Instrumen Analitik → pilih alat, dan kartunya cuma muncul kalau jenis
      // alatnya ada di daftar kemampuan.
      //
      // `rangeMin != rangeMax` di sini, beda dari pH/Turbidimeter/Conductivity
      // yang nge-CMC per titik: dua kelompok panjang gelombangnya dibedain
      // lewat PARAMETER, bukan lewat angka — rentang Holmium (283–641) dan
      // Didynium (474–810) tumpang tindih 167 nm.
      CalibrationCapability(
        namaAlat: 'Spectrophotometer',
        rangeMin: 283,
        rangeMax: 641,
        satuan: 'nm',
        ketidakpastianTerbaik: 0.4,
        satuanKetidakpastian: 'nm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0508_Rev.4',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Spectrophotometer',
        rangeMin: 474,
        rangeMax: 810,
        satuan: 'nm',
        ketidakpastianTerbaik: 0.4,
        satuanKetidakpastian: 'nm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0508_Rev.4',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Spectrophotometer',
        rangeMin: 10,
        rangeMax: 30.5,
        satuan: '%T',
        ketidakpastianTerbaik: 0.5,
        satuanKetidakpastian: '%T',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0508_Rev.4',
        punyaToleransi: false,
      ),
      // 3 titik Viscometer (alat ke-7) — angkanya dari lampiran akreditasi
      // LK-285-IDN no. 44 (`docs/Rekap-Data-Kemampuan-Kalibrasi.md`). Sama
      // alasannya kayak Refractometer & Spectrophotometer di atas: tanpa baris
      // ini kartunya nggak muncul di picker walau `_profilKhusus` udah kenal
      // namanya, dan lembar kerjanya nggak bisa dibuka lewat jalur mana pun.
      CalibrationCapability(
        namaAlat: 'Viscometer',
        rangeMin: 102,
        rangeMax: 102,
        satuan: 'cP',
        ketidakpastianTerbaik: 0.2,
        satuanKetidakpastian: 'cP',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0517_Rev.3',
      ),
      CalibrationCapability(
        namaAlat: 'Viscometer',
        rangeMin: 1028,
        rangeMax: 1028,
        satuan: 'cP',
        ketidakpastianTerbaik: 2.1,
        satuanKetidakpastian: 'cP',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0517_Rev.3',
      ),
      CalibrationCapability(
        namaAlat: 'Viscometer',
        rangeMin: 58021,
        rangeMax: 58021,
        satuan: 'cP',
        ketidakpastianTerbaik: 1.4,
        satuanKetidakpastian: 'cP',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0517_Rev.3',
      ),
      // DO Meter (alat ke-9) — satu titik, 8,77 mg/L. Sama alasannya kayak
      // Viscometer & Spectrophotometer di atas: tanpa baris ini kartunya nggak
      // muncul di picker walau `_profilKhusus` udah kenal namanya, dan lembar
      // kerjanya nggak bisa dibuka lewat jalur mana pun.
      //
      // U95 0,16 mg/L itu CMC dari lampiran akreditasi, dan di master dia yang
      // MENANG atas U hitung (0,148) lewat `MAX(U, CMC)`. Jadi selama alatnya
      // sehat, angka yang terbit 0,16.
      CalibrationCapability(
        namaAlat: 'DO Meter',
        rangeMin: 8.77,
        rangeMax: 8.77,
        satuan: 'mg/L',
        ketidakpastianTerbaik: 0.16,
        satuanKetidakpastian: 'mg/L',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0530_Rev.2',
        punyaToleransi: false,
      ),
      // Gas Detector (alat ke-10) — SATU baris buat empat gas, bukan empat.
      //
      // Rentang 0–1999 ppm itu rentang ukur CO di alat contoh, dipakai sebagai
      // rentang PENCOCOKAN, bukan klaim kemampuan: CMC-nya nol karena KAN
      // belum mengakreditasi gas detector. Memecahnya jadi empat baris cuma
      // menambah baris identik yang saling menutupi — rentang CO sudah
      // mencakup ketiga gas lain. Begitu akreditasinya turun, yang benar
      // memang empat baris dengan CMC masing-masing.
      //
      // Satuannya campur (ppm / %LEL / %); kolom yang cuma muat satu diisi
      // yang paling banyak dipakai. Satuan yang BENAR per baris datang dari
      // bentuk lembar kerjanya, bukan dari sini.
      CalibrationCapability(
        namaAlat: 'Gas Detector',
        rangeMin: 0,
        rangeMax: 1999,
        satuan: 'ppm',
        ketidakpastianTerbaik: 0,
        satuanKetidakpastian: 'ppm',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0536_Rev.0',
        punyaToleransi: false,
      ),
    ];

    // TITS — Temperature Indicator tanpa Sensor (alat ke-11), dan alat pertama
    // di kategori `suhu-dan-kelembapan` yang punya lembar kerja sendiri.
    // Sebelum ini kategorinya pulang KOSONG dari mock, jadi kartunya nggak
    // pernah nongol di picker walau `_profilKhusus` udah kenal namanya — sama
    // persis kayak yang kejadian di Viscometer, Spectrophotometer, & DO Meter.
    //
    // TUJUH baris, satu per tipe sensor, dan angkanya beda-beda: lampiran
    // akreditasi LK-285-IDN no. 1 (`database/data/kemampuan-kalibrasi.json` di
    // backend) ngasih CMC sendiri per tipe. Picker nge-dedupe-nya jadi SATU
    // kartu "Temperature Indicator tanpa Sensor", persis kayak 3 baris pH.
    //
    // Type B nggak ada di sini karena emang nggak diklaim lab — sesinya boleh
    // disimpan tapi U95-nya nggak terbit, dan backend yang ngasih alasannya
    // lewat `belum_dihitung`.
    const kemampuanSuhu = [
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type K',
        rangeMin: -20,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 0.63,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type J',
        rangeMin: 0,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 0.63,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type T',
        rangeMin: -20,
        rangeMax: 400,
        satuan: '°C',
        ketidakpastianTerbaik: 0.56,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type N',
        rangeMin: -20,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 0.83,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type R',
        rangeMin: 0,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 1,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Thermocouple sensor type S',
        rangeMin: 0,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 1.2,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperature Indicator tanpa Sensor',
        parameter: 'Resistance sensor',
        rangeMin: -20,
        rangeMax: 800,
        satuan: '°C',
        ketidakpastianTerbaik: 0.50,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0502_Rev.3',
        punyaToleransi: false,
      ),

      // TIDS — Temperatur Indikator DENGAN Sensor, lampiran akreditasi
      // LK-285-IDN no. 2. Ejaannya beda bahasa dari no. 1 di atas
      // ("Temperature Indicator tanpa Sensor", Inggris) dan itu bukan salah
      // ketik yang boleh dirapiin di sini: yang ngiket lab tulisan di
      // lampirannya, dan backend narik `nama_alat` dari situ apa adanya.
      // Justru dua ejaan inilah yang bikin gerbang Temperatur Indikator
      // nyocokin BENTUK nama, bukan daftar ejaan.
      //
      // `profil` sengaja NGGAK diisi. Backend baru punya `TitsProfile`; profil
      // `tids` masih dibangun, dan `kodeProfilDariNama()` di sana emang
      // mulangin null buat nama yang belum punya profil. Ngisi `'tids'` di
      // mock bikin build offline kelihatan lebih jadi daripada kenyataannya —
      // dan yang ketutup justru satu-satunya penanda yang ngasih tau lembarnya
      // belum ada.
      //
      // Tiga baris, CMC-nya naik ikut rentang: 0,86 / 1,4 / 3,1 °C.
      CalibrationCapability(
        namaAlat: 'Temperatur Indikator dengan Sensor',
        rangeMin: -20,
        rangeMax: 150,
        satuan: '°C',
        ketidakpastianTerbaik: 0.86,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0503_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperatur Indikator dengan Sensor',
        rangeMin: 150,
        rangeMax: 400,
        satuan: '°C',
        ketidakpastianTerbaik: 1.4,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0503_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Temperatur Indikator dengan Sensor',
        rangeMin: 400,
        rangeMax: 600,
        satuan: '°C',
        ketidakpastianTerbaik: 3.1,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0503_Rev.6',
        punyaToleransi: false,
      ),

      // ENCLOSURE — lima jenis, alat ke-12, dan masalahnya persis sama dengan
      // TITS di atas: lembar kerjanya sudah jadi & teruji, tapi kategorinya
      // nggak pernah memulangkan satu pun dari lima ini, jadi kartunya nggak
      // ada yang bisa ditekan.
      //
      // Kelimanya kartu TERPISAH, bukan satu kartu "Enclosure": tiap jenis
      // punya CMC sendiri di lampiran akreditasi LK-285-IDN, dan CMC itu yang
      // jadi lantai U95 yang tercetak. Digabung jadi satu kartu, teknisi
      // nggak punya cara memberi tahu sistem oven-nya oven atau furnace —
      // padahal bedanya 1,5 °C lawan 3,0 °C.
      //
      // Angkanya disalin dari `database/data/kemampuan-kalibrasi.json` no. 6-10
      // di backend, bukan dikarang.
      CalibrationCapability(
        namaAlat: 'Oven',
        // Batas bawahnya "ambient" — teks di lampiran, bukan angka. Itu
        // sebabnya `rangeMin` boleh null dan ada `rangeNote`.
        rangeMax: 300,
        rangeNote: 'ambient s/d 300 °C',
        satuan: '°C',
        ketidakpastianTerbaik: 1.5,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0501_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Bath',
        rangeMin: 0,
        rangeMax: 100,
        satuan: '°C',
        ketidakpastianTerbaik: 1.2,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0501_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Inkubator',
        rangeMin: 15,
        rangeMax: 100,
        satuan: '°C',
        ketidakpastianTerbaik: 1.4,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0501_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Furnace',
        rangeMin: 300,
        rangeMax: 1000,
        satuan: '°C',
        ketidakpastianTerbaik: 3.0,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0501_Rev.6',
        punyaToleransi: false,
      ),
      CalibrationCapability(
        namaAlat: 'Refrigerator',
        rangeMin: -20,
        rangeMax: 10,
        satuan: '°C',
        ketidakpastianTerbaik: 1.5,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0501_Rev.6',
        punyaToleransi: false,
      ),

      // TIGA ALAT SUHU TERAKHIR (ke-18, 19, 20). Lembar kerjanya udah jadi &
      // teruji — contohnya ada utuh di `contoh_lembar_kerja_suhu.dart` — tapi
      // baris kemampuannya belum pernah ada di sini, dan itu artinya sama
      // persis kayak yang dulu kejadian di Viscometer, Spectrophotometer, &
      // TITS: di build `USE_MOCK=true` kartunya nggak nongol di picker, jadi
      // ketiga lembarnya nggak bisa dibuka lewat jalur mana pun.
      //
      // Angkanya disalin dari `database/data/kemampuan-kalibrasi.json` di
      // backend (lampiran akreditasi LK-285-IDN), bukan dikarang.
      //
      // **Ketiganya bawa `profil` sendiri, dan itu wajib.** Penentu lembar di
      // picker-nya `kemampuan.profil ?? profilLembarKerjaUntuk(namaAlat)`, dan
      // penebak-dari-nama (`_profilKhusus`) NGGAK kenal ketiga nama ini —
      // sengaja, karena tabel ejaan itu justru yang sedang dikecilkan (dia
      // nangkring di HP orang, bukan di server). Tanpa `profil` di sini, di
      // build `USE_MOCK=true` kartunya nongol tapi yang kebuka form GENERIK,
      // bukan lembar suhunya — kelihatan jadi, padahal nggak.
      //
      // Baris mock lain belum bawa `profil` karena namanya kebetulan masih
      // dikenal penebak lokal. Itu kebetulan, bukan rancangan.

      // Thermocouple — tiga golongan ketidakpastian, satu alat. Rentangnya
      // nyambung (-20-150, 150-400, 400-600), jadi alatnya rentang -20-600 °C.
      CalibrationCapability(
        namaAlat: 'Thermocouple',
        rangeMin: -20,
        rangeMax: 150,
        satuan: '°C',
        ketidakpastianTerbaik: 0.84,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0529_Rev.2',
        punyaToleransi: false,
        profil: 'thermocouple',
      ),
      CalibrationCapability(
        namaAlat: 'Thermocouple',
        rangeMin: 150,
        rangeMax: 400,
        satuan: '°C',
        ketidakpastianTerbaik: 1.5,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0529_Rev.2',
        punyaToleransi: false,
        profil: 'thermocouple',
      ),
      CalibrationCapability(
        namaAlat: 'Thermocouple',
        rangeMin: 400,
        rangeMax: 600,
        satuan: '°C',
        ketidakpastianTerbaik: 3.3,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0529_Rev.2',
        punyaToleransi: false,
        profil: 'thermocouple',
      ),

      // Termometer Gelas — dua golongan, 0-100 & 100-200 °C.
      CalibrationCapability(
        namaAlat: 'Termometer Gelas',
        rangeMin: 0,
        rangeMax: 100,
        satuan: '°C',
        ketidakpastianTerbaik: 0.58,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0527_Rev.0',
        punyaToleransi: false,
        profil: 'thermometer_glass',
      ),
      CalibrationCapability(
        namaAlat: 'Termometer Gelas',
        rangeMin: 100,
        rangeMax: 200,
        satuan: '°C',
        ketidakpastianTerbaik: 1.0,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0527_Rev.0',
        punyaToleransi: false,
        profil: 'thermometer_glass',
      ),

      // Thermohygrometer — SATU alat, DUA besaran. Ini satu-satunya di
      // kategori ini yang satuannya beda antar baris, dan bedanya bukan
      // kosmetik: rentangnya nggak boleh digabung jadi "15-90" (lihat
      // `golonganRentangDari`).
      CalibrationCapability(
        namaAlat: 'Thermohygrometer',
        parameter: 'Suhu',
        rangeMin: 15,
        rangeMax: 50,
        satuan: '°C',
        ketidakpastianTerbaik: 1.7,
        satuanKetidakpastian: '°C',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0518_Rev.4',
        punyaToleransi: false,
        profil: 'thermohygro',
      ),
      CalibrationCapability(
        namaAlat: 'Thermohygrometer',
        parameter: 'Kelembapan',
        rangeMin: 30,
        rangeMax: 90,
        satuan: '%RH',
        ketidakpastianTerbaik: 4.8,
        satuanKetidakpastian: '%RH',
        faktorCakupan: 2,
        metode: 'SIDIK-IK-CAL-0518_Rev.4',
        punyaToleransi: false,
        profil: 'thermohygro',
      ),
    ];

    final bawaan = switch (kode) {
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
      'suhu-dan-kelembapan' => const CategoryDetail(
        kode: 'suhu-dan-kelembapan',
        nama: 'Suhu & Kelembapan',
        kemampuan: kemampuanSuhu,
      ),
      _ => CategoryDetail(kode: kode, nama: kode, kemampuan: const []),
    };

    // Alat tambahan teknisi ditempel di BELAKANG daftar lampiran akreditasi —
    // urutannya sama kayak yang backend pulangin (baris baru = id paling
    // besar), jadi yang kelihatan di layar mock sama dengan yang nanti
    // kelihatan lawan server asli.
    final tambahan = _tambahan[kode];
    if (tambahan == null || tambahan.isEmpty) return bawaan;

    return CategoryDetail(
      kode: bawaan.kode,
      nama: bawaan.nama,
      kemampuan: [...bawaan.kemampuan, ...tambahan],
    );
  }

  @override
  Future<CalibrationCapability> tambahKemampuan(
    String token,
    String kode,
    String namaAlat,
  ) async {
    if (gagal) throw Exception('server nggak nyaut');

    final nama = namaAlat.trim();
    final isi = await detail(token, kode);

    if (isi.kemampuan.any((k) => _samaNama(k.namaAlat, nama))) {
      throw NamaAlatKembarException(nama);
    }

    // Persis bentuk yang backend pulangin buat alat yang lahir dari teknisi:
    // `tanpa_cmc: true` (lampiran akreditasi nggak pernah nyebut dia) dan
    // `profil: null` (jatuh ke form generik). Ngasih CMC karangan di sini
    // bakal bikin build mock kelihatan lebih meyakinkan daripada kenyataannya
    // — dan justru peringatan yang mesti diuji itu yang ilang.
    final baru = CalibrationCapability(namaAlat: nama, tanpaCmc: true);
    (_tambahan[kode] ??= []).add(baru);

    return baru;
  }

  /// Dua nama dianggap alat yang sama kalau cuma beda huruf besar/kecil atau
  /// spasi. "pH Meter", "PH  meter", dan "ph meter " itu satu alat buat orang
  /// yang megang, jadi mock-nya nolak ketiganya — kalau nggak, test 422 di
  /// sini lolos padahal backend (yang bandinginnya juga nggak peka huruf)
  /// bakal nolak.
  static bool _samaNama(String a, String b) => _rapiin(a) == _rapiin(b);

  static String _rapiin(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

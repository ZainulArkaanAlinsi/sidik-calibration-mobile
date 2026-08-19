import '../models/equipment_lookup.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

/// Cuma buat picker "Alat" di layar Input Kalibrasi — bukan layanan CRUD
/// Alat yang lengkap (itu domain layar Alat sendiri).
abstract class EquipmentLookupService {
  Future<List<EquipmentLookup>> cari(String token, {String? search, String? kategori});
}

/// Nembak `GET /api/equipments` — live sejak 14 Jul (`docs/kontrak-api.md`
/// §3), baca boleh semua role.
class ApiEquipmentLookupService implements EquipmentLookupService {
  ApiEquipmentLookupService(this._api);

  final ApiClient _api;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
  }) async {
    final params = <String>[
      if (search != null && search.isNotEmpty)
        'search=${Uri.encodeQueryComponent(search)}',
      if (kategori != null && kategori.isNotEmpty)
        'category=${Uri.encodeQueryComponent(kategori)}',
    ];
    final path = params.isEmpty ? '/equipments' : '/equipments?${params.join('&')}';

    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return parseListAman(data, EquipmentLookup.fromJson);
  }
}

/// Daftar alat tiruan. Ditaruh di luar kelas karena dipakai bareng sama
/// [MockLembarKerjaService] buat namain sesi yang barusan dikirim — satu
/// sumber, biar nama di antrean approval nggak beda sama alat yang dipilih
/// teknisi.
const daftarAlatMock = <EquipmentLookup>[
  EquipmentLookup(
    id: 12,
    namaAlat: 'Jangka Sorong Mitutoyo',
    serialNumber: 'MT-500-196-30',
    kategori: 'panjang',
    status: 'aktif',
  ),
  EquipmentLookup(
    id: 13,
    namaAlat: 'Timbangan Digital Ohaus',
    serialNumber: 'OH-8825-01',
    kategori: 'massa',
    status: 'overdue',
  ),
  // Angkanya disamain sama worksheet asli 012-CAL-524 biar test bisa
  // ngunci kolom Identitas Alat ke nilai yang beneran ada di kertas.
  EquipmentLookup(
    id: 14,
    namaAlat: 'pH Meter Mettler Toledo',
    serialNumber: 'B628755900',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Mettler Toledo',
    model: 'Five Easy',
    satuan: 'pH',
    rangeMin: 0,
    rangeMax: 14,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
    pelangganAlamat:
        'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. Cicalengka, '
        'Kab. Bandung, Jawa Barat',
  ),
  // Tanpa baris ini, worksheet Turbidimeter di USE_MOCK nggak punya alat yang
  // bisa dipilih sama sekali — dan tombol kirim nahan sampai alat kepilih,
  // jadi alurnya buntu sebelum sempat dicoba.
  EquipmentLookup(
    id: 15,
    namaAlat: 'Turbidimeter Hach',
    serialNumber: 'HC-2100Q-114',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Hach',
    model: '2100Q',
    satuan: 'NTU',
    rangeMin: 0,
    rangeMax: 1000,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
    pelangganAlamat:
        'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. Cicalengka, '
        'Kab. Bandung, Jawa Barat',
  ),
  // Alat & rentangnya dari sesi asli 0189-CAL-624 (`Chlorine_Meter_CSV/
  // INPUT_DATA.csv`): Hanna HI97711, rentang 0–4 mg/L, resolusi 0,01. Pelanggan
  // sengaja dipakai ulang dari baris di atas, bukan disalin dari sesi aslinya —
  // repo ini publik, dan nambah nama pelanggan baru ke sini itu keputusan
  // sendiri yang belum pernah diambil.
  EquipmentLookup(
    id: 16,
    namaAlat: 'Chlorine Meter Hanna',
    serialNumber: '905320134111',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Hanna Instrument',
    model: 'HI97711',
    satuan: 'mg/L',
    rangeMin: 0,
    rangeMax: 4,
    resolusi: 0.01,
    pelangganNama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
    pelangganAlamat:
        'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. Cicalengka, '
        'Kab. Bandung, Jawa Barat',
  ),
  // Alat & rentangnya dari sesi master 2211.11.R (`Refractometer_CSV/INPUT
  // DATA.csv`): Hanna HI 96811, "Capacity/Graduation : 1.7 n20D / 0.0001 n20D".
  //
  // Resolusinya 0,0001 — SATU-SATUNYA alat di daftar ini yang lebih teliti dari
  // 0,01, dan itu yang bikin dia berguna buat nangkep pembulatan yang kelewat
  // di layar. Pelanggannya sengaja dipakai ulang dari baris di atas: pelanggan
  // asli sesi ini instansi beneran, dan repo ini publik.
  EquipmentLookup(
    id: 17,
    namaAlat: 'Refractometer',
    serialNumber: 'C12345',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Hanna Instrument',
    model: 'HI 96811',
    satuan: 'n20D',
    rangeMin: 0,
    rangeMax: 1.7,
    resolusi: 0.0001,
    pelangganNama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
    pelangganAlamat:
        'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. Cicalengka, '
        'Kab. Bandung, Jawa Barat',
  ),
  // Refractometer kedua, kecatat di skala **°Brix** — bukan duplikat malas.
  //
  // Satu alat fisik bisa dipindah antara n20D & °Brix, dan pilihannya nentuin
  // koefisien normalisasi suhu (0,00045/°C vs 0,07/°C). Tanpa ada satu pun alat
  // °Brix di daftar ini, jalur "alatnya kecatat bukan di satuan bawaan" nggak
  // pernah kejalan sekali pun — dan itu jalur yang gagalnya diam: layar nulis
  // n20D, hitungannya °Brix, nggak ada yang error.
  EquipmentLookup(
    id: 18,
    namaAlat: 'Refractometer',
    serialNumber: 'C67890',
    kategori: 'instrumen-analitik',
    status: 'aktif',
    merk: 'Atago',
    model: 'MASTER-53M',
    satuan: '°Brix',
    rangeMin: 0,
    rangeMax: 53,
    resolusi: 0.1,
    pelangganNama: 'PT TIRTA GRACIA SEMESTA MANDIRI',
    pelangganAlamat:
        'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung Kec. Cicalengka, '
        'Kab. Bandung, Jawa Barat',
  ),
];

/// Nama alat buat `equipment_id` yang dipilih di picker mock. `null` kalau
/// idnya bukan dari [daftarAlatMock].
String? namaAlatMock(int id) {
  for (final e in daftarAlatMock) {
    if (e.id == id) return e.namaAlat;
  }
  return null;
}

/// Data tiruan buat test.
class MockEquipmentLookupService implements EquipmentLookupService {
  MockEquipmentLookupService({this.gagal = false});

  final bool gagal;

  @override
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    return daftarAlatMock.where((e) {
      final cocokKategori = kategori == null || kategori.isEmpty || e.kategori == kategori;
      final cocokSearch = search == null ||
          search.isEmpty ||
          e.namaAlat.toLowerCase().contains(search.toLowerCase());
      return cocokKategori && cocokSearch;
    }).toList();
  }
}

import '../models/standard.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

abstract class StandardService {
  Future<List<Standard>> daftar(String token);

  /// Admin doang — `docs/kontrak-api.md` §4.
  Future<Standard> simpan(String token, Standard data);

  Future<Standard> ubah(String token, Standard data);

  Future<void> hapus(String token, int id);
}

/// Nembak `GET/POST/PUT/DELETE /api/standards` — live sejak 14 Jul, baca
/// semua role, tulis admin doang (`docs/kontrak-api.md` §4).
class ApiStandardService implements StandardService {
  ApiStandardService(this._api);

  final ApiClient _api;

  @override
  Future<List<Standard>> daftar(String token) async {
    final json = await _api.get('/standards', token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return parseListAman(data, Standard.fromJson);
  }

  @override
  Future<Standard> simpan(String token, Standard data) async {
    final json = await _api.post('/standards', token: token, body: data.toJson());
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Standard.fromJson(result);
  }

  @override
  Future<Standard> ubah(String token, Standard data) async {
    final json = await _api.put(
      '/standards/${data.id}',
      token: token,
      body: data.toJson(),
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return Standard.fromJson(result);
  }

  @override
  Future<void> hapus(String token, int id) async {
    await _api.delete('/standards/$id', token: token);
  }
}

/// Data tiruan buat test.
class MockStandardService implements StandardService {
  MockStandardService({this.gagal = false});

  final bool gagal;

  final List<Standard> _data = [
    const Standard(
      id: 1,
      nama: 'Gauge Block Set Grade 0',
      merk: 'Mitutoyo',
      serialNumber: 'GB-STD-001',
      masihBerlaku: true,
      ketidakpastian: 0.0004,
      satuanKetidakpastian: 'mm',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 2,
      nama: 'Standar Massa Kelas F1',
      merk: 'Mettler Toledo',
      serialNumber: 'MS-STD-002',
      masihBerlaku: false,
      ketidakpastian: 0.002,
      satuanKetidakpastian: 'g',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 3,
      nama: 'pH Buffer Solution 7',
      merk: 'Supelco/Merck',
      serialNumber: 'HC46341939',
      masihBerlaku: true,
      ketidakpastian: 0.02,
      satuanKetidakpastian: 'pH',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 4,
      nama: 'pH Buffer Solution 4',
      merk: 'Supelco/Merck',
      serialNumber: 'HC32513535',
      masihBerlaku: true,
      ketidakpastian: 0.02,
      satuanKetidakpastian: 'pH',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 5,
      nama: 'pH Buffer Solution 10',
      merk: 'Supelco/Merck',
      serialNumber: 'HC45400338',
      masihBerlaku: true,
      // 0,03 ngikut sertifikat aslinya (`kalibrasi-ph-meter.json` di backend).
      ketidakpastian: 0.03,
      satuanKetidakpastian: 'pH',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 6,
      nama: 'Termometer & Sensor Std.',
      merk: 'Yokogawa/CA 150 Handy Cal',
      serialNumber: '23P1005',
      masihBerlaku: true,
      // 0,72 — punya TERMOMETER. Angka lama 0,06 itu punya Sensor Suhu PT100,
      // alat lain; ketuker waktu mock ini ditulis.
      ketidakpastian: 0.72,
      satuanKetidakpastian: 'oC',
      faktorCakupan: 2,
    ),
    // Tiga larutan turbidity — nama, serial & U95 dari
    // `Master Data TurbidiMeter_CSV/DATABASE.csv` (Supelco/Merck, U95 0,04 / 3
    // / 21 NTU, k=2). Id-nya 20/21/22 ngikut yang dirujuk bentuk lembar
    // turbidimeter; sebelum ini id itu NGGAK ADA isinya, jadi baris STANDARD-nya
    // ngaku `terdaftar` tapi serial & ketertelusurannya kosong di layar.
    const Standard(
      id: 20,
      nama: 'Turbidity Standard 1 NTU',
      merk: 'Supelco/Merck',
      serialNumber: 'LRAD7304',
      masihBerlaku: true,
      ketidakpastian: 0.04,
      satuanKetidakpastian: 'NTU',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 21,
      nama: 'Turbidity Standard 100 NTU',
      merk: 'Supelco/Merck',
      serialNumber: 'LRAD7305',
      masihBerlaku: true,
      ketidakpastian: 3,
      satuanKetidakpastian: 'NTU',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 22,
      nama: 'Turbidity Standard 1000 NTU',
      merk: 'Supelco/Merck',
      serialNumber: 'LRAD7089',
      masihBerlaku: true,
      ketidakpastian: 21,
      satuanKetidakpastian: 'NTU',
      faktorCakupan: 2,
    ),
    // Dua larutan chlorine — angka & nama dari `Chlorine_Meter_CSV/DATABASE.csv`
    // (Supelco/Merck, U95 0,09 & 0,06 mg/L, k=2). Tanpa ini baris STANDARD di
    // lembar Chlorine nggak ketaut ke master dan kebaca "belum terdaftar".
    const Standard(
      id: 30,
      nama: 'Chlorine Standard Solution 1.74 mg/L',
      merk: 'Supelco/Merck',
      serialNumber: 'QC1065-2ML',
      masihBerlaku: true,
      ketidakpastian: 0.09,
      satuanKetidakpastian: 'mg/L',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 31,
      nama: 'Chlorine Standar Cuvettes 1.83 mg/L',
      merk: 'Supelco/Merck',
      serialNumber: 'LRAD8911',
      masihBerlaku: true,
      ketidakpastian: 0.06,
      satuanKetidakpastian: 'mg/L',
      faktorCakupan: 2,
    ),
    // Dua kalibrator suhu buat TITS (alat ke-11). Nama & serialnya harus PERSIS
    // sama kayak baris STANDARD di bentuk lembar kerjanya — itu satu-satunya
    // yang nautin kotak "Usage Check" ke master standar.
    //
    // `ketidakpastian` NOL, bukan angka: ketidakpastian kalibrator ini beda per
    // TIPE SENSOR dan per TITIK, tabelnya hidup di backend
    // (`database/data/tabel-kalibrator-suhu.json`). Naruh satu angka di sini
    // bakal kelihatan sah di layar padahal nggak pernah dipakai hitungan.
    //
    // Constant 40T sengaja `masihBerlaku: false` — sertifikatnya beneran lewat
    // 28 Agustus 2025, dan kedua sesi master pakai Yokogawa. Lencana kadaluarsa
    // yang muncul di lembar kerja itu keadaan nyata lab, bukan data mock rusak.
    const Standard(
      id: 50,
      nama: 'Temperature Calibrator Constant 40T',
      merk: 'Constant',
      model: '40T',
      serialNumber: '99875850',
      tertelusurKe: 'LK-202-IDN',
      masihBerlaku: false,
      ketidakpastian: 0,
      satuanKetidakpastian: '°C',
      faktorCakupan: 2,
    ),
    const Standard(
      id: 51,
      nama: 'Temperature Calibrator Yokogawa CA 150 Handy Cal',
      merk: 'Yokogawa',
      model: 'CA 150 Handy Cal',
      serialNumber: '23P1005',
      tertelusurKe: 'LK-241-IDN',
      masihBerlaku: true,
      ketidakpastian: 0,
      satuanKetidakpastian: '°C',
      faktorCakupan: 2,
    ),
    // Unit thermohygro. `parameterKondisi` yang bikin `punyaParameterKondisi`
    // true — itu satu-satunya saringan yang dipakai picker "Thermohygro used".
    //
    // Sebelum ini mock NGGAK punya satu pun, jadi di USE_MOCK kolom Thermohygro
    // mati total: lembar Turbidimeter & Chlorine nampilin "Belum ada unit
    // thermohygro terdaftar", dan yang bergantung ke situ (koreksi + U95%
    // kondisi lingkungan) nggak bisa dicoba offline sama sekali. pH lolos cuma
    // karena pilihannya di-hardcode di bentuk formulirnya.
    //
    // Koreksi & U95-nya dari `DATABASE.csv` baris TH-2 & TH-4 di titik 20 °C /
    // 50 %RH — titik yang paling dekat sama kondisi lab.
    const Standard(
      id: 40,
      nama: 'TH-2',
      merk: 'Thermohygrometer',
      serialNumber: 'TH-2',
      masihBerlaku: true,
      ketidakpastian: 1.7,
      satuanKetidakpastian: 'oC',
      faktorCakupan: 2,
      parameterKondisi: {
        'suhu': {'koreksi': -0.39, 'u95': 1.7},
        'kelembaban': {'koreksi': -1.0, 'u95': 4.8},
      },
    ),
    const Standard(
      id: 41,
      nama: 'TH-4',
      merk: 'Thermohygrometer',
      serialNumber: 'TH-4',
      masihBerlaku: true,
      ketidakpastian: 1.7,
      satuanKetidakpastian: 'oC',
      faktorCakupan: 2,
      parameterKondisi: {
        'suhu': {'koreksi': -0.16, 'u95': 1.7},
        'kelembaban': {'koreksi': -1.96, 'u95': 4.8},
      },
    ),
    const Standard(
      id: 42,
      nama: 'TH-6',
      merk: 'Thermohygrometer',
      serialNumber: 'TH-6',
      masihBerlaku: true,
      ketidakpastian: 1.7,
      satuanKetidakpastian: 'oC',
      faktorCakupan: 2,
      parameterKondisi: {
        'suhu': {'koreksi': -0.23, 'u95': 1.7},
        'kelembaban': {'koreksi': -3.17, 'u95': 4.8},
      },
    ),
    const Standard(
      id: 43,
      nama: 'TH-7',
      merk: 'Thermohygrometer',
      serialNumber: 'TH-7',
      masihBerlaku: true,
      ketidakpastian: 1.7,
      satuanKetidakpastian: 'oC',
      faktorCakupan: 2,
      parameterKondisi: {
        'suhu': {'koreksi': -0.43, 'u95': 1.7},
        'kelembaban': {'koreksi': -2.55, 'u95': 4.8},
      },
    ),
  ];

  @override
  Future<List<Standard>> daftar(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    return List.unmodifiable(_data);
  }

  @override
  Future<Standard> simpan(String token, Standard data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final id = (_data.isEmpty ? 0 : _data.map((s) => s.id).reduce((a, b) => a > b ? a : b)) + 1;
    final baru = Standard(
      id: id,
      nama: data.nama,
      merk: data.merk,
      model: data.model,
      serialNumber: data.serialNumber,
      noSertifikat: data.noSertifikat,
      tertelusurKe: data.tertelusurKe,
      berlakuSampai: data.berlakuSampai,
      masihBerlaku: true,
      ketidakpastian: data.ketidakpastian,
      satuanKetidakpastian: data.satuanKetidakpastian,
      faktorCakupan: data.faktorCakupan,
      drift: data.drift,
    );
    _data.add(baru);
    return baru;
  }

  @override
  Future<Standard> ubah(String token, Standard data) async {
    if (gagal) throw Exception('server nggak nyaut');
    final index = _data.indexWhere((s) => s.id == data.id);
    if (index != -1) _data[index] = data;
    return data;
  }

  @override
  Future<void> hapus(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    _data.removeWhere((s) => s.id == id);
  }
}

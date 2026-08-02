import 'mock_store.dart';
import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import 'api_client.dart';

/// Lembar kerja teknisi: ambil bentuk formulirnya, kirim isiannya.
abstract class LembarKerjaService {
  /// Bentuk formulir dari `GET /api/calibrations/lembar-kerja`. Responsnya
  /// udah disaring per-role di backend, jadi hasilnya beda antara teknisi &
  /// admin — layar nggak perlu nyaring apa-apa lagi.
  ///
  /// [profil] = kode jenis alat (`ph_meter` / `turbidimeter`). Backend milih
  /// bentuk lembar kerjanya dari sini; default pH kalau kosong.
  Future<LembarKerja> ambilBentuk(String token, {String? profil});

  /// `POST /api/calibrations` — balikin id sesi yang kebentuk.
  Future<int> kirim(String token, LembarKerjaSubmission isian);

  /// `PUT /api/calibrations/{id}` — lanjut draft atau perbaiki sesi yang
  /// dikembalikan admin.
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian);
}

class ApiLembarKerjaService implements LembarKerjaService {
  ApiLembarKerjaService(this._api);

  final ApiClient _api;

  @override
  Future<LembarKerja> ambilBentuk(String token, {String? profil}) async {
    final path = profil == null || profil.isEmpty
        ? '/calibrations/lembar-kerja'
        : '/calibrations/lembar-kerja?profil=$profil';
    final json = await _api.get(path, token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return LembarKerja.fromJson(data);
  }

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    final json = await _api.post(
      '/calibrations',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async {
    final json = await _api.put(
      '/calibrations/$id',
      token: token,
      body: isian.toJson(),
    );
    return _idDari(json);
  }

  int _idDari(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Tiruan buat test. [payloadTerakhir] nyimpen body yang bakal dikirim ke
/// server — itu yang diperiksa test, bukan tampilannya, karena aturan yang
/// paling gampang rusak diam-diam ada di bentuk payload-nya (sel kosong wajib
/// jadi `null`, bukan dibuang).
class MockLembarKerjaService implements LembarKerjaService {
  MockLembarKerjaService({
    this.gagal = false,
    this.untukAdmin = false,
    this.gagalKirimSampaiPercobaanKe = 0,
  });

  final bool gagal;
  final bool untukAdmin;

  /// Bikin `kirim`/`perbarui` gagal sampai percobaan ke-n — buat niru sinyal
  /// putus di lapangan, dan mastiin retry-nya bawa `client_request_id` yang
  /// SAMA (kalau berubah, backend bikin sesi dobel).
  final int gagalKirimSampaiPercobaanKe;

  /// Semua payload yang pernah dicoba dikirim, termasuk yang gagal.
  final List<Map<String, dynamic>> payload = [];

  Map<String, dynamic>? get payloadTerakhir =>
      payload.isEmpty ? null : payload.last;

  int get jumlahKirim => payload.length;

  @override
  Future<LembarKerja> ambilBentuk(String token, {String? profil}) async {
    if (gagal) throw Exception('server nggak nyaut');
    return LembarKerja.fromJson(
      profil == 'turbidimeter'
          ? contohBentukLembarKerjaTurbidi(untukAdmin: untukAdmin)
          : contohBentukLembarKerja(untukAdmin: untukAdmin),
    );
  }

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async {
    // Dicatat ke ingatan bersama, bukan balikin id karangan: tanpa ini sesi
    // yang barusan dikirim teknisi nggak pernah nongol di antrean approval,
    // dan alur dari lembar kerja sampai sertifikat nggak bisa dicoba sama
    // sekali tanpa backend nyala. Lihat [MockStore].
    final id = MockStore.instance.tambahSesi(
      namaAlat: 'pH Meter (sesi baru)',
      namaTeknisi: 'Teknisi',
    );

    return _catat(isian, id);
  }

  @override
  Future<int> perbarui(String token, int id, LembarKerjaSubmission isian) async =>
      _catat(isian, id);

  int _catat(LembarKerjaSubmission isian, int id) {
    // Dicatat DULUAN, baru dilempar errornya — payload percobaan yang gagal
    // itu justru yang mau diperiksa test.
    payload.add(isian.toJson());

    if (gagal || payload.length <= gagalKirimSampaiPercobaanKe) {
      throw Exception('server nggak nyaut');
    }

    return id;
  }
}

/// Salinan bentuk yang dibalikin `GET /api/calibrations/lembar-kerja`
/// (`LembarKerjaTemplate` di backend). Ditaruh di lib, bukan di test, biar
/// dipakai bareng sama mock — dan biar kalau bentuk backend berubah,
/// ketahuannya dari satu tempat.
Map<String, dynamic> contohBentukLembarKerja({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {'titik_ukur': 4.00, 'label': '4,00'},
      {'titik_ukur': 7.00, 'label': '7,00'},
      {'titik_ukur': 10.01, 'label': '10,01'},
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'pH', 'tipe': 'angka', 'satuan': 'pH'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field(
          'equipment.range_resolusi',
          '2. Range/Resolution',
          'teks',
          sumber: 'otomatis',
          satuan: 'pH',
        ),
        // Tiga kolom ini DIKETIK TEKNISI dari badan alat, bukan disalin
        // master — lihat LembarKerjaTemplate di backend.
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field(
          'thermohygro_standard_id',
          '6. Thermohygro used',
          'pilihan',
          sumber: 'master_thermohygro',
          pilihan: [
            {'nilai': '7', 'label': 'TH-2', 'grup': 'Insitu'},
            {'nilai': '11', 'label': 'TH-6', 'grup': 'Insitu'},
            {'nilai': '12', 'label': 'TH-7', 'grup': 'Insitu'},
            {'nilai': '9', 'label': 'TH-4', 'grup': 'Inlab'},
          ],
        ),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      // Lima baris TERCETAK di formulir, bukan katalog standar lab. Baris
      // terakhir sengaja `standard_id: null` — di lab beneran pun standar itu
      // belum kedaftar di master, dan barisnya tetap harus kelihatan.
      'baris': [
        {'label': 'pH Buffer Solutions 4', 'standard_id': 2, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 7', 'standard_id': 3, 'terdaftar': true},
        {'label': 'pH Buffer Solutions 10', 'standard_id': 4, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 5, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field(
          'lokasi',
          '1. Location',
          'pilihan',
          pilihan: [
            {'nilai': 'lab', 'label': 'In lab'},
            {'nilai': 'onsite', 'label': 'Insitu'},
          ],
        ),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field(
            'calibration_method_id',
            '2. Calibration Methode',
            'pilihan',
            sumber: 'master_metode',
            hanyaAdmin: true,
          ),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 2,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 2,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0509_Rev.4',
    'judul': 'Calibration Worksheet - pH Meter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [4.00, 7.00, 10.01],
    'satuan': 'pH',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

/// Salinan bentuk Turbidimeter (`?profil=turbidimeter`, `TurbidimeterProfile`
/// di backend). Titik 1/100/1000 NTU dengan resolusi per-titik (0,01/0,1/1),
/// dipakai mock biar alur turbidimeter bisa dicoba tanpa backend.
Map<String, dynamic> contohBentukLembarKerjaTurbidi({bool untukAdmin = false}) {
  Map<String, dynamic> field(
    String kode,
    String label,
    String tipe, {
    String? sumber,
    String? satuan,
    List<Map<String, String>> pilihan = const [],
    bool hanyaAdmin = false,
  }) => {
    'kode': kode,
    'label': label,
    'tipe': tipe,
    'wajib': false,
    'sumber': sumber,
    'satuan': satuan,
    'pilihan': pilihan,
    'hanya_admin': hanyaAdmin,
  };

  Map<String, dynamic> tabel(String tahap, String judul) => {
    'tahap': tahap,
    'judul': judul,
    'baris': [
      {'titik_ukur': 0.04, 'label': '0.04', 'resolusi': 0.01, 'desimal': 2},
      {'titik_ukur': 15.0, 'label': '15', 'resolusi': 0.01, 'desimal': 2},
      {'titik_ukur': 100.0, 'label': '100', 'resolusi': 0.1, 'desimal': 1},
      {'titik_ukur': 750.0, 'label': '750', 'resolusi': 1.0, 'desimal': 0},
      {'titik_ukur': 2000.0, 'label': '2000', 'resolusi': 1.0, 'desimal': 0},
    ],
    'kolom': [
      {'kode': 'pembacaan', 'label': 'NTU', 'tipe': 'angka', 'satuan': 'NTU'},
      {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
    ],
    'pengulangan': [1, 2, 3, 4, 5],
  };

  final bagian = <Map<String, dynamic>>[
    {
      'kode': 'identitas_alat',
      'halaman': 1,
      'judul': 'EQUIPMENT IDENTITY AND CUSTOMER DATA',
      'field': [
        field('tanggal_terima', 'Received Date', 'tanggal'),
        field('tanggal_kalibrasi', 'Calibration Date', 'tanggal'),
        field('equipment_id', 'Equipment', 'pilihan', sumber: 'master_alat'),
        field('equipment.nama_alat', '1. Name', 'teks', sumber: 'otomatis'),
        field('equipment.range_resolusi', '2. Range/Resolution', 'teks',
            sumber: 'otomatis', satuan: 'NTU'),
        field('alat_model', '3. Type/Model', 'teks'),
        field('alat_serial_number', '4. Serial Number/LPI', 'teks'),
        field('alat_merk', '5. Merk/Manufacture', 'teks'),
        field('thermohygro_standard_id', '6. Thermohygro used', 'pilihan',
            sumber: 'master_thermohygro'),
      ],
    },
    {
      'kode': 'pemilik',
      'halaman': 1,
      'judul': 'OWNER',
      'field': [
        field('pemilik_nama', '1. Name', 'teks'),
        field('pemilik_alamat', '2. Address', 'teks_panjang'),
      ],
    },
    {
      'kode': 'usage_check',
      'halaman': 1,
      'judul': 'STANDARD',
      'baris': [
        {'label': 'Turbidity Std. Solutions 0.04 NTU', 'standard_id': 20, 'terdaftar': true},
        {'label': 'Turbidity Std. Solutions 15 NTU', 'standard_id': 21, 'terdaftar': true},
        {'label': 'Turbidity Std. Solutions 100 NTU', 'standard_id': 22, 'terdaftar': true},
        {'label': 'Turbidity Std. Solutions 750 NTU', 'standard_id': 23, 'terdaftar': true},
        {'label': 'Turbidity Std. Solutions 2000 NTU', 'standard_id': 24, 'terdaftar': true},
        {'label': 'RTD Sensor/SH1/20', 'standard_id': 5, 'terdaftar': true},
        {'label': 'Victor 14+/992613877', 'standard_id': null, 'terdaftar': false},
      ],
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'data_kalibrasi',
      'halaman': 1,
      'judul': 'CALIBRATION DATA',
      'field': [
        field('lokasi', '1. Location', 'pilihan', pilihan: [
          {'nilai': 'lab', 'label': 'In lab'},
          {'nilai': 'onsite', 'label': 'Insitu'},
        ]),
        field('room_id', 'Ruangan', 'pilihan', sumber: 'master_ruangan'),
        if (untukAdmin)
          field('calibration_method_id', '2. Calibration Methode', 'pilihan',
              sumber: 'master_metode', hanyaAdmin: true),
      ],
    },
    {
      'kode': 'hasil',
      'halaman': 1,
      'judul': 'CALIBRATION RESULT',
      'field': [
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
      'halaman': 1,
      'judul': 'Catatan & Tanda Tangan',
      'field': [
        field('catatan_teknisi', 'Catatan', 'teks_panjang'),
        field('teknisi.nama', 'Calibrated by', 'teks', sumber: 'otomatis'),
        field('reviewer.nama', 'Checked by', 'teks', sumber: 'otomatis'),
      ],
    },
  ];

  return {
    'kode_dokumen': 'SIDIK-FM-CAL-0530_Rev.2',
    'judul': 'Calibration Worksheet - Turbidimeter',
    'untuk': untukAdmin ? 'admin' : 'teknisi',
    'jumlah_pengulangan': 5,
    'larutan_standar': [0.04, 15.0, 100.0, 750.0, 2000.0],
    'satuan': 'NTU',
    'satuan_suhu': '°C',
    'semua_kolom_opsional': true,
    'catatan_pengisian':
        'Kolom yang belum bisa diisi di lapangan boleh dikosongin — '
        'lembar kerja tetap bisa dikirim.',
    'bagian': bagian,
  };
}

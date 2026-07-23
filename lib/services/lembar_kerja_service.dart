import '../models/lembar_kerja.dart';
import '../models/lembar_kerja_submission.dart';
import 'api_client.dart';

/// Lembar kerja teknisi: ambil bentuk formulirnya, kirim isiannya.
abstract class LembarKerjaService {
  /// Bentuk formulir dari `GET /api/calibrations/lembar-kerja`. Responsnya
  /// udah disaring per-role di backend, jadi hasilnya beda antara teknisi &
  /// admin — layar nggak perlu nyaring apa-apa lagi.
  Future<LembarKerja> ambilBentuk(String token);

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
  Future<LembarKerja> ambilBentuk(String token) async {
    final json = await _api.get('/calibrations/lembar-kerja', token: token);
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
  Future<LembarKerja> ambilBentuk(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    return LembarKerja.fromJson(contohBentukLembarKerja(untukAdmin: untukAdmin));
  }

  @override
  Future<int> kirim(String token, LembarKerjaSubmission isian) async =>
      _catat(isian, 999);

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
        field('equipment.model', '3. Type/Model', 'teks', sumber: 'otomatis'),
        field(
          'equipment.serial_number',
          '4. Serial Number/LPI',
          'teks',
          sumber: 'otomatis',
        ),
        field('equipment.merk', '5. Merk/Manufacture', 'teks', sumber: 'otomatis'),
        if (untukAdmin)
          field(
            'thermohygro_standard_id',
            '6. Thermohygro used',
            'pilihan',
            sumber: 'master_standar',
            hanyaAdmin: true,
          ),
      ],
    },
    {
      'kode': 'pemilik',
      'judul': 'OWNER',
      'field': [
        field('customer.nama', '1. Name', 'teks', sumber: 'otomatis'),
        field('customer.alamat', '2. Address', 'teks', sumber: 'otomatis'),
      ],
    },
    {
      'kode': 'data_kalibrasi',
      'judul': 'STANDARD CALIBRATION DATA',
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
        field('suhu_awal', 'Env. Condition — First', 'angka', satuan: '°C'),
        field('kelembaban_awal', 'Env. Condition — First', 'angka', satuan: '%RH'),
        field('suhu_akhir', 'Env. Condition — End', 'angka', satuan: '°C'),
        field('kelembaban_akhir', 'Env. Condition — End', 'angka', satuan: '%RH'),
      ],
    },
    {
      'kode': 'usage_check',
      'judul': 'Standard Name / Usage Check',
      'sumber': 'master_standar',
      'field': <Map<String, dynamic>>[],
    },
    {
      'kode': 'hasil',
      'judul': 'CALIBRATION RESULT',
      'field': <Map<String, dynamic>>[],
      'tabel': [
        tabel('sebelum_adjustment', 'Before adjustment Reading'),
        tabel('sesudah_adjustment', 'After adjustment Reading'),
      ],
    },
    {
      'kode': 'penutup',
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

import '../core/config/app_config.dart';
import '../models/certificate_snapshot.dart';
import '../models/revisi_sertifikat.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Sertifikat terbit (spesifikasi poin 9, 10 & 13).
///
/// Tiga bentuk unduhan dari sertifikat yang SAMA — PDF buat dikirim resmi ke
/// klien, Excel buat arsip/rekap, QR buat akses cepat. Isinya nggak mungkin
/// beda: ketiganya dibangun dari `snapshot` yang dibekukan waktu terbit.
abstract class CertificateService {
  Future<CertificateDetail> detail(String token, int certificateId);

  /// URL unduhan. Bukan `Future` karena cuma nyusun alamat — yang beneran
  /// ngunduh `FileDownloader`, dan semuanya butuh header Authorization
  /// (file-nya di disk privat, bukan link publik).
  String urlPdf(int certificateId);

  String urlExcel(int certificateId);

  String urlQr(int certificateId);

  /// Rekap banyak sertifikat sekaligus, mis. `bulan: '2026-07'`.
  String urlRekapExcel({String? bulan, int? customerId});

  /// Terbitkan REVISI (`POST /certificates/{id}/revisi`, admin). Jawabannya
  /// 202 berisi baris revisi BARU (`menunggu_generate`) — PDF-nya dirender di
  /// antrean. [perubahan] hanya memuat kunci yang berubah.
  ///
  /// Melempar [GalatAksi] untuk 422: `errors["perubahan.<kunci>"]` untuk
  /// isian, `{message}` saja untuk galat keadaan (sudah digantikan, dst.).
  Future<CertificateDetail> revisi(
    String token,
    int certificateId, {
    required Map<String, String> perubahan,
    required String alasan,
    String? catatanPelanggan,
  });

  /// Batalkan (`POST /certificates/{id}/batalkan`, admin). Final.
  Future<CertificateDetail> batalkan(
    String token,
    int certificateId, {
    required String alasan,
    String? catatanPelanggan,
  });
}

class ApiCertificateService implements CertificateService {
  ApiCertificateService(this._api, {String? baseUrl})
    : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final ApiClient _api;
  final String _baseUrl;

  @override
  Future<CertificateDetail> detail(String token, int certificateId) async {
    final json = await _api.get('/certificates/$certificateId', token: token);
    return CertificateDetail.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  /// 422 jadi [GalatAksi] supaya layar bisa membaca `errors` per kunci;
  /// status lain (403/404/429) dilempar apa adanya dengan pesan server.
  Future<Map<String, dynamic>> _tulis(
    Future<Map<String, dynamic>> Function() kirim,
  ) async {
    try {
      return await kirim();
    } on ApiException catch (e) {
      if (e.status == 422) throw GalatAksi.dariBody(e.message, e.body);
      rethrow;
    }
  }

  @override
  Future<CertificateDetail> revisi(
    String token,
    int certificateId, {
    required Map<String, String> perubahan,
    required String alasan,
    String? catatanPelanggan,
  }) async {
    final json = await _tulis(
      () => _api.post(
        '/certificates/$certificateId/revisi',
        token: token,
        body: {
          'perubahan': perubahan,
          'alasan': alasan.trim(),
          if (catatanPelanggan != null && catatanPelanggan.trim().isNotEmpty)
            'catatan_pelanggan': catatanPelanggan.trim(),
        },
      ),
    );
    return CertificateDetail.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  Future<CertificateDetail> batalkan(
    String token,
    int certificateId, {
    required String alasan,
    String? catatanPelanggan,
  }) async {
    final json = await _tulis(
      () => _api.post(
        '/certificates/$certificateId/batalkan',
        token: token,
        body: {
          'alasan': alasan.trim(),
          if (catatanPelanggan != null && catatanPelanggan.trim().isNotEmpty)
            'catatan_pelanggan': catatanPelanggan.trim(),
        },
      ),
    );
    return CertificateDetail.fromJson(
      (json['data'] ?? json) as Map<String, dynamic>,
    );
  }

  @override
  String urlPdf(int id) => '$_baseUrl/certificates/$id/download';

  @override
  String urlExcel(int id) => '$_baseUrl/certificates/$id/excel';

  @override
  String urlQr(int id) => '$_baseUrl/certificates/$id/qr';

  @override
  String urlRekapExcel({String? bulan, int? customerId}) {
    final q = <String>[
      if (bulan != null) 'bulan=$bulan',
      if (customerId != null) 'customer_id=$customerId',
    ];
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    return '$_baseUrl/certificates/export/excel$query';
  }
}

class MockCertificateService implements CertificateService {
  /// [khusus] menimpa jawaban `detail` per id (mis. sertifikat digantikan atau
  /// dibatalkan untuk golden); id lain memakai isi bawaan di bawah.
  /// [bolehAksi] menyalakan `bisa_direvisi` & `bisa_dibatalkan` pada bawaan.
  MockCertificateService({
    this.gagal = false,
    this.belumTerbit = false,
    this.bolehAksi = false,
    this.dampak,
    Map<int, CertificateDetail>? khusus,
  }) : _khusus = {...?khusus};

  final bool gagal;
  final bool belumTerbit;
  final bool bolehAksi;
  final DampakPembatalan? dampak;
  final Map<int, CertificateDetail> _khusus;

  /// Isi terakhir yang dikirim ke `revisi` / `batalkan`, untuk diperiksa test.
  final List<({Map<String, String> perubahan, String alasan, String? catatan})>
  direvisiDengan = [];
  final List<({String alasan, String? catatan})> dibatalkanDengan = [];

  /// Nomor seri yang dianggap bentrok (meniru 422 validasi per kunci).
  static const serialDitolak = 'SERI-DITOLAK';

  @override
  Future<CertificateDetail> revisi(
    String token,
    int certificateId, {
    required Map<String, String> perubahan,
    required String alasan,
    String? catatanPelanggan,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    final asal = await detail(token, certificateId);
    if (!asal.bisaDirevisi) {
      throw const GalatAksi('Sertifikat ini tidak bisa direvisi lagi.');
    }
    if (perubahan[KunciDataCetak.nomorSeri] == serialDitolak) {
      throw const GalatAksi(
        'Data yang dikirim nggak valid.',
        errors: {
          'perubahan.nomor_seri': ['Nomor seri ini tidak boleh dipakai.'],
        },
      );
    }
    direvisiDengan.add((
      perubahan: perubahan,
      alasan: alasan,
      catatan: catatanPelanggan,
    ));
    return CertificateDetail(
      id: certificateId + 1000,
      nomor: '${asal.nomor}-R${asal.revisiKe + 1}',
      status: 'menunggu_generate',
      statusDokumenKode: 'belum_terbit',
      revisiKe: asal.revisiKe + 1,
      revisiDari: RujukanSertifikat(id: asal.id, nomor: asal.nomor),
    );
  }

  @override
  Future<CertificateDetail> batalkan(
    String token,
    int certificateId, {
    required String alasan,
    String? catatanPelanggan,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');
    final asal = await detail(token, certificateId);
    if (!asal.bisaDibatalkan) {
      throw const GalatAksi('Sertifikat ini tidak bisa dibatalkan.');
    }
    dibatalkanDengan.add((alasan: alasan, catatan: catatanPelanggan));
    final baru = asal.salin(
      status: 'dibatalkan',
      statusDokumenKode: 'dibatalkan',
      bisaDirevisi: false,
      bisaDibatalkan: false,
      dibatalkanPada: DateTime.utc(2026, 10, 1, 3),
      dibatalkanOleh: 'Hendra Wijaya',
      alasanPembatalan: alasan,
      catatanPelanggan: catatanPelanggan,
    );
    _khusus[certificateId] = baru;
    return baru;
  }

  @override
  Future<CertificateDetail> detail(String token, int certificateId) async {
    if (gagal) throw Exception('server nggak nyaut');

    final k = _khusus[certificateId];
    if (k != null) return k;

    if (belumTerbit) {
      return CertificateDetail(
        id: certificateId,
        nomor: '012-CAL-524',
        status: 'menunggu_generate',
      );
    }

    // Isi sertifikat ASLI 012-CAL-524 (Spesifikasi poin 9).
    return CertificateDetail(
      id: certificateId,
      nomor: '012-CAL-524',
      status: 'terbit',
      pdfUrl: 'https://contoh/certificates/$certificateId/download',
      qrToken: 'abc123',
      diterbitkanPada: '2024-05-30',
      // Bawaan: sah & tanpa tombol. Tombol admin cuma nyala bila diminta
      // ([bolehAksi]) supaya layar & golden lama tidak bergeser.
      statusDokumenKode: 'berlaku',
      bisaDirevisi: bolehAksi,
      bisaDibatalkan: bolehAksi,
      dataCetak: bolehAksi ? _dataCetakContoh : null,
      dampakPembatalan: bolehAksi ? dampak : null,
      // Kontak pelanggan — backend emang ngirim ini (`CertificateResource`),
      // dipakai tombol "tinggal pilih" di layar kirim.
      pelangganNama: 'PT TIRTA CONTOH MANDIRI',
      pelangganEmail: 'pic@tirta.co.id',
      pelangganTelepon: '081234567890',
      snapshot: CertificateSnapshot.fromJson(const {
        'desimal': 2,
        'satuan': 'pH',
        'meta': {'keputusan': 'PASS'},
        'header': {
          'certificate_number': '012-CAL-524',
          'page': '1 of 1',
          'owner': 'PT TIRTA CONTOH MANDIRI',
          'order_number': '2405.13.A',
          'address': 'Jl. Contoh Primer A-10, '
              'Kec. Cicalengka, Kab. Bandung, Jawa Barat',
          'received_date': '2024-05-26',
          'equipment_name': 'pH Meter',
          'manufacturer': 'Mettler Toledo',
          'calibration_location': 'Lab. Uji A',
          'model_type': 'Five Easy',
          'calibration_date': '2024-05-26',
          'serial_number': 'B628755900',
          'calibration_method': 'SIDIK-IK-CAL-0506_Rev.6',
          'capacity_graduation': '0-14 pH / 0,01 pH',
          'env_condition': 'T: 21,0°C ± 1,7°C — %RH: 51,95% ± 5,7%',
          'technician_id': 'DR',
        },
        'hasil': [
          {
            'titik_ke': 1,
            'standard_value': 4.01,
            'unit_under_test': 4.00,
            'correction': 0.01,
            'u95': 0.02,
          },
          {
            'titik_ke': 2,
            'standard_value': 6.99,
            'unit_under_test': 7.00,
            'correction': -0.02,
            'u95': 0.02,
          },
          {
            'titik_ke': 3,
            'standard_value': 9.98,
            'unit_under_test': 10.11,
            'correction': -0.13,
            'u95': 0.03,
          },
        ],
        'catatan': [
          'The Uncertainty is taken at a Confidence Level 95% and '
              'Coverage Factor (k) = 2',
          'Calibration results are not to be announced and only apply '
              'to related tools',
        ],
        'standar_digunakan': [
          {
            'name': 'pH Buffer Solution 4',
            'merk_type': 'Supelco/Merck',
            'serial_number': 'HC32513535',
            'traceable_to': 'Merck KGaA',
          },
          {
            'name': 'pH Buffer Solution 7',
            'merk_type': 'Supelco/Merck',
            'serial_number': 'HC46341939',
            'traceable_to': 'Merck KGaA',
          },
          {
            'name': 'pH Buffer Solution 10',
            'merk_type': 'Supelco/Merck',
            'serial_number': 'HC45400338',
            'traceable_to': 'Merck KGaA',
          },
          {
            'name': 'Termometer & Sensor Std.',
            'merk_type': 'Yokogawa/CA 150 Handy Cal',
            'serial_number': '23P1005',
            'traceable_to': 'LK-285-IDN',
          },
        ],
        'footer': {
          'issuance_date': '2024-05-30',
          'penandatangan': 'Alex Misramto',
          'jabatan': 'Technical Manager',
          'kode_dokumen': 'SIDIK-FM-CAL-2403_Rev. 0',
        },
      }),
    );
  }

  /// Nilai tercetak sertifikat contoh di atas (isian awal formulir revisi).
  static const _dataCetakContoh = DataCetak({
    KunciDataCetak.pemilik: 'PT TIRTA CONTOH MANDIRI',
    KunciDataCetak.alamat: 'Jl. Contoh Primer A-10, Kec. Cicalengka',
    KunciDataCetak.merk: 'Mettler Toledo',
    KunciDataCetak.tipe: 'Five Easy',
    KunciDataCetak.nomorSeri: 'B628755900',
    KunciDataCetak.lokasiKalibrasi: 'Lab. Uji A',
    KunciDataCetak.tanggalKalibrasi: '2024-05-26',
    KunciDataCetak.berlakuSampai: '2025-05-26',
  });

  @override
  String urlPdf(int id) => 'https://contoh/certificates/$id/download';

  @override
  String urlExcel(int id) => 'https://contoh/certificates/$id/excel';

  @override
  String urlQr(int id) => 'https://contoh/certificates/$id/qr';

  @override
  String urlRekapExcel({String? bulan, int? customerId}) =>
      'https://contoh/certificates/export/excel';
}

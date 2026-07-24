import '../core/config/app_config.dart';
import '../models/certificate_snapshot.dart';
import 'api_client.dart';

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
  MockCertificateService({this.gagal = false, this.belumTerbit = false});

  final bool gagal;
  final bool belumTerbit;

  @override
  Future<CertificateDetail> detail(String token, int certificateId) async {
    if (gagal) throw Exception('server nggak nyaut');

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
      snapshot: CertificateSnapshot.fromJson(const {
        'desimal': 2,
        'satuan': 'pH',
        'meta': {'keputusan': 'PASS'},
        'header': {
          'certificate_number': '012-CAL-524',
          'page': '1 of 1',
          'owner': 'PT TIRTA GRACIA SEMESTA MANDIRI',
          'order_number': '2405.13.A',
          'address': 'Jl. Arteri Primer A-10 RT. 01 RW.12 Nyalindung '
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

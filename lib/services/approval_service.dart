import 'api_client.dart';

/// Dilempar `reject()` kalau catatan revisinya kosong — validasi lokal,
/// server juga nolak tapi lebih murah dicegah di mobile duluan.
class CatatanKosongException implements Exception {
  const CatatanKosongException();
}

/// **Nggak ada `ambilSertifikat(id)` di sini** — sengaja. Backend nggak
/// punya `GET /api/certificates/{id}` (cuma `GET /certificates` buat daftar
/// + `GET /certificates/{id}/download` yang nge-stream file PDF-nya
/// langsung). Data ringkas sertifikat (nomor/status/pdf_url) udah nempel di
/// `CalibrationDetail.sertifikat` lewat `GET /api/calibrations/{id}` —
/// itu yang dipakai `CertificateScreen`, bukan endpoint ini.
abstract class ApprovalService {
  /// Admin doang — `docs/kontrak-api.md` §5. Balikin `certificate_id` (bisa
  /// `null` sesaat, generate-nya jalan di queue).
  Future<int?> approve(String token, int calibrationId);

  Future<void> reject(String token, int calibrationId, String catatanRevisi);

  Future<void> retryGenerate(String token, int certificateId);
}

/// Nembak §5 — live, dicek langsung ke `CalibrationController.php` &
/// `CertificateController.php` di repo `sidik-calibration-api` (18 Jul).
class ApiApprovalService implements ApprovalService {
  ApiApprovalService(this._api);

  final ApiClient _api;

  @override
  Future<int?> approve(String token, int calibrationId) async {
    final json = await _api.post(
      '/calibrations/$calibrationId/approve',
      token: token,
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['certificate_id'] as num?)?.toInt();
  }

  @override
  Future<void> reject(
    String token,
    int calibrationId,
    String catatanRevisi,
  ) async {
    await _api.post(
      '/calibrations/$calibrationId/reject',
      token: token,
      body: {'catatan_revisi': catatanRevisi},
    );
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {
    await _api.post('/certificates/$certificateId/retry', token: token);
  }
}

/// Data tiruan buat test.
class MockApprovalService implements ApprovalService {
  MockApprovalService({this.gagal = false, this.jeda = Duration.zero});

  final bool gagal;
  final Duration jeda;

  Future<void> _tunda() async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (gagal) throw Exception('server nggak nyaut');
  }

  @override
  Future<int?> approve(String token, int calibrationId) async {
    await _tunda();
    return 900 + calibrationId;
  }

  @override
  Future<void> reject(
    String token,
    int calibrationId,
    String catatanRevisi,
  ) async {
    if (catatanRevisi.trim().isEmpty) throw const CatatanKosongException();
    await _tunda();
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {
    await _tunda();
  }
}

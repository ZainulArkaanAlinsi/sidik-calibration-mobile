import '../models/certificate.dart';
import 'api_client.dart';

/// Dilempar `reject()` kalau catatan revisinya kosong — validasi lokal,
/// server juga nolak tapi lebih murah dicegah di mobile duluan.
class CatatanKosongException implements Exception {
  const CatatanKosongException();
}

abstract class ApprovalService {
  /// Admin doang — `docs/kontrak-api.md` §5. Balikin `certificate_id` (bisa
  /// `null` sesaat, generate-nya jalan di queue).
  Future<int?> approve(String token, int calibrationId);

  Future<void> reject(String token, int calibrationId, String catatanRevisi);

  Future<Certificate> ambilSertifikat(String token, int certificateId);

  Future<void> retryGenerate(String token, int certificateId);
}

/// Nembak §5. Belum ditandai "Live" di kontrak (beda sama §1-4/7/8 yang udah
/// dikonfirmasi 14 Jul) — jadi [approvalServiceProvider] masih nunjuk ke
/// [MockApprovalService] sampai ada konfirmasi endpoint ini beneran jalan.
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
  Future<Certificate> ambilSertifikat(String token, int certificateId) async {
    final json = await _api.get('/certificates/$certificateId', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return Certificate.fromJson(data);
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {
    await _api.post('/certificates/$certificateId/retry', token: token);
  }
}

/// Data tiruan buat layar Approval & test — dipakai sampai §5 dikonfirmasi
/// live.
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
  Future<Certificate> ambilSertifikat(String token, int certificateId) async {
    await _tunda();
    return Certificate(
      id: certificateId,
      nomor: 'CAL/2026/07/${certificateId.toString().padLeft(4, '0')}',
      calibrationId: certificateId - 900,
      status: CertificateStatus.terbit,
      pdfUrl: 'https://contoh.sidik.co.id/certificates/CAL-2026-07-0001.pdf',
      qrToken: 'demo$certificateId',
    );
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {
    await _tunda();
  }
}

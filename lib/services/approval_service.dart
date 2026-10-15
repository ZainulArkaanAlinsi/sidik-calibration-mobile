import 'mock_store.dart';
import 'api_client.dart';

/// **Nggak ada `ambilSertifikat(id)` di sini** — sengaja. Backend nggak
/// punya `GET /api/certificates/{id}` (cuma `GET /certificates` buat daftar
/// + `GET /certificates/{id}/download` yang nge-stream file PDF-nya
/// langsung). Data ringkas sertifikat (nomor/status/pdf_url) udah nempel di
/// `CalibrationDetail.sertifikat` lewat `GET /api/calibrations/{id}` —
/// itu yang dipakai `CertificateScreen`, bukan endpoint ini.
abstract class ApprovalService {
  /// Admin doang — `docs/kontrak-api.md` §5. Balikin `certificate_id` (bisa
  /// `null` sesaat, generate-nya jalan di queue).
  /// [abaikanPeringatan] = admin udah lihat temuannya dan mutusin lanjut.
  ///
  /// Tanpa ini backend nolak sekali dengan 422 + `butuh_konfirmasi` — dan itu
  /// disengaja: peringatan kayak "kelembaban 2 %RH" harus dilewati secara
  /// SADAR, bukan diam-diam.
  /// [nomorSertifikat] wajib diketik Master Data (K-50-04), kecuali sesi yang
  /// sertifikatnya ditarik (nomor `-R<n>` dibuat server).
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
    String? nomorSertifikat,
  });

  Future<void> retryGenerate(String token, int certificateId);
}

/// Nembak §5 — live, dicek langsung ke `CalibrationController.php` &
/// `CertificateController.php` di repo `sidik-calibration-api` (18 Jul).
class ApiApprovalService implements ApprovalService {
  ApiApprovalService(this._api);

  final ApiClient _api;

  @override
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
    String? nomorSertifikat,
  }) async {
    final json = await _api.post(
      '/calibrations/$calibrationId/approve',
      token: token,
      body: {
        'nomor_sertifikat': ?nomorSertifikat,
        if (abaikanPeringatan) 'abaikan_peringatan': true,
      },
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['certificate_id'] as num?)?.toInt();
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
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
    String? nomorSertifikat,
  }) async {
    await _tunda();

    // Sesi yang lahir dari lembar kerja diurus [MockStore] biar statusnya
    // beneran pindah — kalau cuma balikin angka, sesinya balik lagi ke
    // "menunggu approval" begitu daftarnya dimuat ulang.
    return MockStore.instance.setujui(calibrationId) ?? 900 + calibrationId;
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {
    await _tunda();
  }
}

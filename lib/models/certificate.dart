/// Status generate sertifikat. `menungguGenerate` itu jendela sempit —
/// generate-nya jalan di queue backend, `certificate_id` bisa masih `null`
/// sesaat setelah approve (`docs/kontrak-api.md` §5).
enum CertificateStatus { menungguGenerate, terbit, gagal }

extension CertificateStatusJson on CertificateStatus {
  static CertificateStatus fromJson(String value) => switch (value) {
    'menunggu_generate' => CertificateStatus.menungguGenerate,
    'terbit' => CertificateStatus.terbit,
    'gagal' => CertificateStatus.gagal,
    _ => CertificateStatus.menungguGenerate,
  };
}

/// Respons `GET /api/certificates/{id}`.
class Certificate {
  const Certificate({
    required this.id,
    required this.nomor,
    required this.calibrationId,
    required this.status,
    this.pdfUrl,
    this.qrToken,
  });

  final int id;
  final String nomor;
  final int calibrationId;
  final CertificateStatus status;
  final String? pdfUrl;
  final String? qrToken;

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: (json['id'] as num).toInt(),
      nomor: json['nomor'] as String,
      calibrationId: (json['calibration_id'] as num).toInt(),
      status: CertificateStatusJson.fromJson(json['status'] as String),
      pdfUrl: json['pdf_url'] as String?,
      qrToken: json['qr_token'] as String?,
    );
  }
}

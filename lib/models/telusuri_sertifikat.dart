import 'revisi_sertifikat.dart' show StatusDokumen;

/// Satu baris `GET /sertifikat/telusuri?q=` (kontrak-api §15).
///
/// Status yang ditampilkan SELALU dari [statusDokumen] (+ [revisiKe]) dan
/// [pdfUrl], bukan dari ada-tidaknya `id`: baris placeholder `gagal` sudah
/// punya id sebelum PDF jadi.
class TelusuriSertifikat {
  const TelusuriSertifikat({
    required this.id,
    required this.nomor,
    this.perusahaan,
    this.alat,
    this.merk,
    this.model,
    this.serialNumber,
    this.status,
    required this.statusDokumen,
    this.revisiKe,
    this.diterbitkanPada,
    this.berlakuSampai,
    this.tahapPaket,
    this.pdfUrl,
  });

  final int id;
  final String nomor;
  final String? perusahaan;
  final String? alat;
  final String? merk;
  final String? model;
  final String? serialNumber;
  final String? status;
  final StatusDokumen statusDokumen;

  /// Null = terbitan pertama.
  final int? revisiKe;
  final DateTime? diterbitkanPada;
  final DateTime? berlakuSampai;

  /// Kode tahap paket; null bila alat tidak berada di paket.
  final String? tahapPaket;
  final String? pdfUrl;

  bool get bisaBukaPdf => pdfUrl != null && pdfUrl!.isNotEmpty;

  factory TelusuriSertifikat.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    return TelusuriSertifikat(
      id: (json['id'] as num).toInt(),
      nomor: json['nomor'] as String? ?? '',
      perusahaan: json['perusahaan'] as String?,
      alat: json['alat'] as String?,
      merk: json['merk'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
      status: status,
      statusDokumen:
          StatusDokumen.dariApi(json['status_dokumen'] as String?) ??
          StatusDokumen.belumTerbit,
      revisiKe: (json['revisi_ke'] as num?)?.toInt(),
      diterbitkanPada: DateTime.tryParse(
        json['diterbitkan_pada'] as String? ?? '',
      ),
      berlakuSampai: DateTime.tryParse(json['berlaku_sampai'] as String? ?? ''),
      tahapPaket: json['tahap_paket'] as String?,
      pdfUrl: json['pdf_url'] as String?,
    );
  }
}

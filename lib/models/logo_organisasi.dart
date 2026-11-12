/// Logo kop sertifikat milik lab (`logo_url` di `GET /api/organization`).
///
/// Model terpisah dari `Organization` (data PT) seperti `TandaTanganInfo`:
/// layar logo cuma butuh satu field, dan `Organization` dipakai layar lain
/// yang tidak boleh ikut berubah bentuknya.
class LogoOrganisasi {
  const LogoOrganisasi({this.url});

  /// URL absolut siap pakai. `null` = lab belum mengunggah logo — bukan
  /// berarti sertifikat tanpa logo: server jatuh ke logo bawaan.
  final String? url;

  bool get ada => url != null && url!.isNotEmpty;

  factory LogoOrganisasi.fromJson(Map<String, dynamic> json) {
    final url = json['logo_url'];
    return LogoOrganisasi(url: url is String && url.isNotEmpty ? url : null);
  }
}

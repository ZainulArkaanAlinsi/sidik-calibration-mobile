/// Kategori kalibrasi (`GET /api/categories`) — isi dropdown kategori alat.
///
/// Kode kategorinya **bukan** singkatan tebakan (`suhu-dan-kelembapan`,
/// bukan `suhu`) — makanya selalu diambil dari API/mock, jangan di-hardcode
/// di layar (lihat `docs/kontrak-api.md` §3).
class CalibrationCategory {
  const CalibrationCategory({required this.kode, required this.nama});

  final String kode;
  final String nama;

  factory CalibrationCategory.fromJson(Map<String, dynamic> json) {
    return CalibrationCategory(
      kode: json['kode'] as String,
      nama: json['nama'] as String,
    );
  }
}

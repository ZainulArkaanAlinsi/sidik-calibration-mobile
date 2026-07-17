/// Kelompok pengukuran (`GET /api/categories`, `docs/kontrak-api.md` §3).
/// `rentangUkur`/`ketidakpastianTerbaik`/`satuan` di sini cuma ringkasan
/// buat dropdown — jangan dipakai buat validasi (satu kategori bisa punya
/// banyak satuan sekaligus, lihat `GET /api/categories/{kode}`).
class Category {
  const Category({
    required this.kode,
    required this.nama,
    this.rentangUkur,
    this.ketidakpastianTerbaik,
    this.satuan,
  });

  final String kode;
  final String nama;
  final String? rentangUkur;
  final double? ketidakpastianTerbaik;
  final String? satuan;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      kode: json['kode'] as String,
      nama: json['nama'] as String,
      rentangUkur: json['rentang_ukur'] as String?,
      ketidakpastianTerbaik: (json['ketidakpastian_terbaik'] as num?)
          ?.toDouble(),
      satuan: json['satuan'] as String?,
    );
  }
}

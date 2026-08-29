/// Satu perusahaan dari hasil pencarian **direktori luar**, belum jadi pelanggan.
///
/// Sengaja tipe sendiri, bukan [CustomerLookup] dengan `id` diisi angka palsu.
/// Bedanya bukan kerapian: [CustomerLookup.id] itu `customers.id` yang dikirim
/// balik sebagai `pelanggan_id` waktu alat disimpan. Baris direktori **belum
/// punya** id itu — dia baru punya sesudah teknisi memilihnya dan servernya
/// mendaftarkannya. Dipaksa masuk ke tipe yang sama, angka palsu itu cepat atau
/// lambat kekirim sebagai `pelanggan_id` dan alatnya mendarat di PT lain.
class PerusahaanDirektori {
  const PerusahaanDirektori({
    required this.ref,
    required this.nama,
    this.alamat,
  });

  /// Id tempat menurut direktorinya. Dikirim balik waktu mendaftarkan, supaya
  /// perusahaan yang sama dipilih dua teknisi bisa dikenali PERSIS — tanpa
  /// mengadu ejaan nama, yang bisa beda antar pencarian.
  final String ref;

  final String nama;

  /// Boleh kosong: nggak semua tempat di direktori punya alamat tertulis.
  final String? alamat;

  factory PerusahaanDirektori.fromJson(Map<String, dynamic> json) =>
      PerusahaanDirektori(
        ref: json['ref'] as String? ?? '',
        nama: json['nama'] as String? ?? '',
        alamat: json['alamat'] as String?,
      );
}

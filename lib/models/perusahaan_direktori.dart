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

/// Hasil pencarian direktori luar, berikut **atribusi sumbernya**.
///
/// Amplop sendiri, bukan `atribusi` yang ditempel ke tiap [PerusahaanDirektori]:
/// atribusi itu sifat SUMBERNYA, bukan sifat satu perusahaan. Ditempel per
/// baris, dia ikut tersalin waktu satu baris dipilih dan dibawa ke layar lain —
/// dan di situ dia berhenti berarti apa-apa.
///
/// ## Kenapa [atribusi] wajib sampai ke layar
///
/// Ini kewajiban LISENSI, bukan hiasan. Sumber bawaan sekarang OpenStreetMap,
/// dan ODbL mewajibkan sumbernya disebut di tempat hasilnya dipajang. Sebelum
/// berkas ini punya [atribusi], server sudah mengirimnya di badan respons dan
/// sisi HP **membuangnya** — nol error, nol log, dan yang hilang cuma kalimat
/// yang justru diwajibkan.
///
/// Kalimatnya datang UTUH dari server dan dipajang apa adanya: dia **tidak
/// diterjemahkan** dan tidak dikarang di sini. Penyedianya bisa ditukar lewat
/// satu setelan di server (`DIREKTORI_PERUSAHAAN_DRIVER`), jadi kalimat yang
/// ditulis di sisi HP bakal memajang atribusi penyedia LAMA sesudah setelannya
/// diganti — pelanggaran lisensi yang nggak ninggalin satu pun error.
///
/// [atribusi] boleh `null`: penyedia yang nggak mensyaratkan apa-apa memulangkan
/// `null`, dan layarnya cuma nggak memajang barisnya.
typedef HasilDirektori = ({List<PerusahaanDirektori> daftar, String? atribusi});

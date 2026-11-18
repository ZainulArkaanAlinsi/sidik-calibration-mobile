/// Satu pelanggan — `docs/kontrak-api.md` §8 (`GET/POST/PUT/DELETE
/// /api/customers`). `jumlahAlat` cuma ada di response, dipakai buat
/// nampilin peringatan waktu mau hapus.
class Customer {
  const Customer({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.contactPerson,
    required this.telepon,
    required this.email,
    this.jumlahAlat = 0,
    this.alatCount,
    this.sertifikatCount,
    this.anggotaAktifCount,
    this.undanganMenungguCount,
    this.tanpaAkun = false,
    this.namaNormalKosong = false,
  });

  final int id;
  final String nama;
  final String alamat;
  final String contactPerson;
  final String telepon;
  final String email;
  final int jumlahAlat;

  /// Hitungan & penanda dari SERVER (kontrak `docs/perintah-frontend-super-admin.md`
  /// §3.6), aditif: `null` = server lama / respons yang tidak membawanya
  /// (`POST`/`PUT` tidak menghitung). Klien tidak menghitung ulang.
  ///
  /// `sertifikatCount` = terbit + dibatalkan (sama dengan yang dilihat
  /// pelanggan). `tanpaAkun` = PT punya alat/sertifikat tetapi tidak ada satu
  /// anggota aktif pun. `namaNormalKosong` = deteksi PT kembar belum bekerja
  /// untuk PT ini.
  final int? alatCount;
  final int? sertifikatCount;
  final int? anggotaAktifCount;
  final int? undanganMenungguCount;
  final bool tanpaAkun;
  final bool namaNormalKosong;

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'alamat': alamat,
    'contact_person': contactPerson,
    'telepon': telepon,
    'email': email,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

    return Customer(
      id: (json['id'] as num).toInt(),
      nama: teks('nama'),
      alamat: teks('alamat'),
      contactPerson: teks('contact_person'),
      telepon: teks('telepon'),
      email: teks('email'),
      jumlahAlat: (json['jumlah_alat'] as num?)?.toInt() ?? 0,
      alatCount: (json['alat_count'] as num?)?.toInt(),
      sertifikatCount: (json['sertifikat_count'] as num?)?.toInt(),
      anggotaAktifCount: (json['anggota_aktif_count'] as num?)?.toInt(),
      undanganMenungguCount: (json['undangan_menunggu_count'] as num?)?.toInt(),
      tanpaAkun: json['tanpa_akun'] == true,
      namaNormalKosong: json['nama_normal_kosong'] == true,
    );
  }
}

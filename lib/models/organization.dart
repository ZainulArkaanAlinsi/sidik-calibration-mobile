/// Data PT — dicetak di kop sertifikat. Satu instalasi cuma punya satu
/// baris (`GET`/`PUT /api/organization`, `docs/kontrak-api.md` §8), jadi
/// nggak ada `id`/create/delete.
class Organization {
  const Organization({
    required this.nama,
    required this.alamat,
    required this.telepon,
    required this.email,
    required this.noAkreditasi,
    this.standarAkreditasi = '',
    this.akreditasiMulai,
    this.akreditasiBerakhir,
    this.akreditasiMasihBerlaku = true,
  });

  final String nama;
  final String alamat;
  final String telepon;
  final String email;
  final String noAkreditasi;

  /// Mis. "ISO/IEC 17025:2017" — standar yang jadi acuan akreditasi
  /// [noAkreditasi] (LK-285-IDN).
  final String standarAkreditasi;
  final DateTime? akreditasiMulai;
  final DateTime? akreditasiBerakhir;

  /// Dihitung backend dari [akreditasiBerakhir] (`Organization::
  /// akreditasiMasihBerlaku()`) — **read-only**, nggak dikirim balik waktu
  /// `PUT`. Kalau ini `false`, sertifikat yang diterbitkan lab nggak lagi
  /// tercakup akreditasi — ini yang paling penting buat admin pantau.
  final bool akreditasiMasihBerlaku;

  Organization copyWith({
    String? nama,
    String? alamat,
    String? telepon,
    String? email,
    String? noAkreditasi,
    String? standarAkreditasi,
    DateTime? akreditasiMulai,
    DateTime? akreditasiBerakhir,
  }) => Organization(
    nama: nama ?? this.nama,
    alamat: alamat ?? this.alamat,
    telepon: telepon ?? this.telepon,
    email: email ?? this.email,
    noAkreditasi: noAkreditasi ?? this.noAkreditasi,
    standarAkreditasi: standarAkreditasi ?? this.standarAkreditasi,
    akreditasiMulai: akreditasiMulai ?? this.akreditasiMulai,
    akreditasiBerakhir: akreditasiBerakhir ?? this.akreditasiBerakhir,
    akreditasiMasihBerlaku: akreditasiMasihBerlaku,
  );

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'alamat': alamat,
    'telepon': telepon,
    'email': email,
    'no_akreditasi': noAkreditasi,
    'standar_akreditasi': standarAkreditasi,
    if (akreditasiMulai != null)
      'akreditasi_mulai': akreditasiMulai!.toUtc().toIso8601String(),
    if (akreditasiBerakhir != null)
      'akreditasi_berakhir': akreditasiBerakhir!.toUtc().toIso8601String(),
  };

  factory Organization.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

    DateTime? tanggal(String key) => switch (json[key]) {
      String s => DateTime.tryParse(s),
      _ => null,
    };

    return Organization(
      nama: teks('nama'),
      alamat: teks('alamat'),
      telepon: teks('telepon'),
      email: teks('email'),
      noAkreditasi: teks('no_akreditasi'),
      standarAkreditasi: teks('standar_akreditasi'),
      akreditasiMulai: tanggal('akreditasi_mulai'),
      akreditasiBerakhir: tanggal('akreditasi_berakhir'),
      akreditasiMasihBerlaku: json['akreditasi_masih_berlaku'] as bool? ?? true,
    );
  }
}

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
  });

  final String nama;
  final String alamat;
  final String telepon;
  final String email;
  final String noAkreditasi;

  Organization copyWith({
    String? nama,
    String? alamat,
    String? telepon,
    String? email,
    String? noAkreditasi,
  }) => Organization(
    nama: nama ?? this.nama,
    alamat: alamat ?? this.alamat,
    telepon: telepon ?? this.telepon,
    email: email ?? this.email,
    noAkreditasi: noAkreditasi ?? this.noAkreditasi,
  );

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'alamat': alamat,
    'telepon': telepon,
    'email': email,
    'no_akreditasi': noAkreditasi,
  };

  factory Organization.fromJson(Map<String, dynamic> json) {
    String teks(String key) => json[key] as String? ?? '';

    return Organization(
      nama: teks('nama'),
      alamat: teks('alamat'),
      telepon: teks('telepon'),
      email: teks('email'),
      noAkreditasi: teks('no_akreditasi'),
    );
  }
}

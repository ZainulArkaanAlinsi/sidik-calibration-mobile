/// Peran yang ditawarkan lewat undangan — nilai [kirim] persis seperti yang
/// diterima `POST /api/customers/{customer}/undangan`.
enum PeranUndangan {
  picUtama('pic_utama'),
  staf('staf');

  const PeranUndangan(this.kirim);

  final String kirim;
}

/// Jawaban `POST /api/customers/{customer}/undangan` (kontrak 10 Nov 2026).
///
/// [kode] SENGAJA nullable: sampai API baru live, server lama bisa menjawab
/// 201 tanpa kode. Layar harus bisa menjelaskan itu, bukan crash atau
/// menampilkan kode kosong. Kode hanya dikirim server SEKALI (di respons
/// pembuatan) dan tidak pernah bisa dibaca lagi — jangan disimpan.
class UndanganPelanggan {
  const UndanganPelanggan({
    required this.id,
    required this.email,
    this.peran,
    this.berlakuSampai,
    this.kode,
  });

  final int id;
  final String email;
  final String? peran;
  final DateTime? berlakuSampai;
  final String? kode;

  bool get punyaKode => kode != null && kode!.isNotEmpty;

  factory UndanganPelanggan.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final berlaku = data['berlaku_sampai'];
    final kode = data['kode'];

    return UndanganPelanggan(
      id: (data['id'] as num?)?.toInt() ?? 0,
      email: data['email'] is String ? data['email'] as String : '',
      peran: data['peran'] is String ? data['peran'] as String : null,
      berlakuSampai: berlaku is String
          ? DateTime.tryParse(berlaku)?.toLocal()
          : null,
      kode: kode is String && kode.trim().isNotEmpty ? kode.trim() : null,
    );
  }
}

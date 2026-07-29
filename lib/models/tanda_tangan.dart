/// Posisi & ukuran cetak tanda tangan di sertifikat.
///
/// Disimpan **sekali di tingkat template**, berlaku buat semua sertifikat —
/// bukan per sertifikat. Sertifikat yang udah terbit itu dokumen terkendali;
/// kalau posisinya bisa diedit per lembar, isinya berubah sesudah diserahkan
/// ke pelanggan. Jadi di UI ini satu layar pengaturan, bukan editor per
/// sertifikat.
///
/// Satuannya milimeter, bukan piksel: yang diatur ini penempatan di kertas
/// cetak, bukan di layar.
class TandaTanganPosisi {
  const TandaTanganPosisi({
    this.geserXMm = 0,
    this.geserYMm = 0,
    this.lebarMm = 35,
  });

  /// Batas yang diterima backend. Dipakai buat nyetel slider — nilai di luar
  /// ini ditolak `422`, jadi lebih baik nggak bisa dipilih sejak awal.
  static const double minGeser = -40;
  static const double maksGeser = 40;
  static const double minLebar = 10;
  static const double maksLebar = 80;

  /// Negatif = ke kiri.
  final double geserXMm;

  /// **POSITIF = NAIK.** Kebalikan koordinat layar, dan ini yang paling
  /// gampang bikin salah: kalau UI-nya bikin drag ke atas lalu ngirim nilai
  /// negatif, tanda tangannya malah turun di hasil cetak. Backend udah dites
  /// buat arah ini — yang harus nyesuaikan sisi UI.
  final double geserYMm;

  /// Lebar cetak. Tingginya ngikut rasio gambar, jadi nggak diatur terpisah.
  final double lebarMm;

  factory TandaTanganPosisi.fromJson(Map<String, dynamic> json) {
    double angka(String kunci, double bawaan) =>
        (json[kunci] as num?)?.toDouble() ?? bawaan;

    return TandaTanganPosisi(
      geserXMm: angka('geser_x_mm', 0),
      geserYMm: angka('geser_y_mm', 0),
      lebarMm: angka('lebar_mm', 35),
    );
  }

  Map<String, dynamic> toJson() => {
    'geser_x_mm': geserXMm,
    'geser_y_mm': geserYMm,
    'lebar_mm': lebarMm,
  };

  TandaTanganPosisi salin({
    double? geserXMm,
    double? geserYMm,
    double? lebarMm,
  }) {
    return TandaTanganPosisi(
      geserXMm: geserXMm ?? this.geserXMm,
      geserYMm: geserYMm ?? this.geserYMm,
      lebarMm: lebarMm ?? this.lebarMm,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TandaTanganPosisi &&
      other.geserXMm == geserXMm &&
      other.geserYMm == geserYMm &&
      other.lebarMm == lebarMm;

  @override
  int get hashCode => Object.hash(geserXMm, geserYMm, lebarMm);
}

/// Keadaan tanda tangan di organisasi.
///
/// **Nggak ada `ttd_url`, dan nggak akan pernah ada.** Gambarnya ditaruh di
/// disk privat — URL tanda tangan yang bisa dibuka siapa saja berarti siapa
/// saja bisa nempelin ke dokumen palsu. Yang dikirim backend cuma penanda
/// [punyaTandaTangan]; gambarnya ditarik terpisah lewat endpoint ber-auth.
class TandaTanganInfo {
  const TandaTanganInfo({
    required this.punyaTandaTangan,
    required this.posisi,
  });

  final bool punyaTandaTangan;
  final TandaTanganPosisi posisi;

  factory TandaTanganInfo.fromJson(Map<String, dynamic> json) {
    final posisi = json['tanda_tangan'] as Map<String, dynamic>?;

    return TandaTanganInfo(
      punyaTandaTangan: json['punya_tanda_tangan'] as bool? ?? false,
      posisi: posisi == null
          ? const TandaTanganPosisi()
          : TandaTanganPosisi.fromJson(posisi),
    );
  }
}

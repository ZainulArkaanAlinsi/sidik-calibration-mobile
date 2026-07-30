/// Ruangan lab tempat kalibrasi dikerjakan.
///
/// Rentang suhu & kelembabannya bukan hiasan: itu syarat kondisi lingkungan
/// yang dipakai buat menilai apakah sesi dikerjakan di kondisi yang sah.
class Ruangan {
  const Ruangan({
    required this.id,
    required this.kode,
    required this.nama,
    this.lokasi,
    this.suhuMin,
    this.suhuMaks,
    this.kelembabanMin,
    this.kelembabanMaks,
    this.keterangan,
    this.aktif = true,
  });

  final int id;

  /// Unik per organisasi — backend nolak kembar dengan 422.
  final String kode;

  final String nama;
  final String? lokasi;

  final double? suhuMin;
  final double? suhuMaks;
  final double? kelembabanMin;
  final double? kelembabanMaks;

  final String? keterangan;

  /// Ruangan nonaktif tetap ada di daftar, nggak dihapus: sesi lama nunjuk ke
  /// sini, dan menghapusnya bikin riwayat kalibrasi kehilangan tempat kerjanya.
  final bool aktif;

  /// `null` kalau salah satu batasnya kosong — rentang setengah itu bukan
  /// rentang, dan nampilin "20 – " lebih membingungkan daripada nggak
  /// nampilin apa-apa.
  String? get rentangSuhu => (suhuMin != null && suhuMaks != null)
      ? '$suhuMin – $suhuMaks °C'
      : null;

  String? get rentangKelembaban =>
      (kelembabanMin != null && kelembabanMaks != null)
      ? '$kelembabanMin – $kelembabanMaks %RH'
      : null;

  factory Ruangan.fromJson(Map<String, dynamic> json) => Ruangan(
    id: (json['id'] as num?)?.toInt() ?? 0,
    kode: '${json['kode'] ?? ''}',
    nama: '${json['nama'] ?? ''}',
    lokasi: json['lokasi'] as String?,
    suhuMin: (json['suhu_min'] as num?)?.toDouble(),
    suhuMaks: (json['suhu_max'] as num?)?.toDouble(),
    kelembabanMin: (json['kelembaban_min'] as num?)?.toDouble(),
    kelembabanMaks: (json['kelembaban_max'] as num?)?.toDouble(),
    keterangan: json['keterangan'] as String?,
    aktif: json['aktif'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'kode': kode,
    'nama': nama,
    'lokasi': ?lokasi,
    'suhu_min': ?suhuMin,
    'suhu_max': ?suhuMaks,
    'kelembaban_min': ?kelembabanMin,
    'kelembaban_max': ?kelembabanMaks,
    'keterangan': ?keterangan,
    'aktif': aktif,
  };

  Ruangan salin({
    String? kode,
    String? nama,
    String? lokasi,
    double? suhuMin,
    double? suhuMaks,
    double? kelembabanMin,
    double? kelembabanMaks,
    String? keterangan,
    bool? aktif,
  }) => Ruangan(
    id: id,
    kode: kode ?? this.kode,
    nama: nama ?? this.nama,
    lokasi: lokasi ?? this.lokasi,
    suhuMin: suhuMin ?? this.suhuMin,
    suhuMaks: suhuMaks ?? this.suhuMaks,
    kelembabanMin: kelembabanMin ?? this.kelembabanMin,
    kelembabanMaks: kelembabanMaks ?? this.kelembabanMaks,
    keterangan: keterangan ?? this.keterangan,
    aktif: aktif ?? this.aktif,
  );
}

/// Instruksi Kerja (IK) — metode kalibrasi yang dipakai satu sesi.
///
/// `kode` + `revisi` dipisah karena dokumen mutu memang gitu: IK yang sama
/// bisa punya beberapa revisi, dan sertifikat harus nyebut revisi yang berlaku
/// **waktu kalibrasinya dikerjakan**, bukan yang terbaru.
class MetodeKalibrasi {
  const MetodeKalibrasi({
    required this.id,
    required this.kode,
    required this.nama,
    this.revisi,
    this.berlakuMulai,
    this.equipmentCategoryId,
    this.keterangan,
    this.aktif = true,
    this.kodeLengkapServer,
  });

  final int id;
  final String kode;
  final String nama;

  /// Nomor revisi dokumennya (mis. `4`). Ikut kecetak di sertifikat.
  final String? revisi;

  final DateTime? berlakuMulai;
  final int? equipmentCategoryId;
  final String? keterangan;
  final bool aktif;

  /// Kode + revisi seperti yang **dicetak di sertifikat**
  /// (`SIDIK-IK-CAL-0506_Rev.4`).
  ///
  /// Diambil dari backend, bukan dirakit di sini. Sempat dirakit sendiri jadi
  /// `$kode Rev. $revisi` — dan itu keluar `SIDIK-IK-CAL-0506 Rev. 4`, beda
  /// spasi & titik dari yang kecetak. Untuk layar yang gunanya nyocokin sama
  /// lembar di tangan, beda satu karakter aja udah bikin ragu.
  ///
  /// Fallback dirakit lokal cuma buat baris yang belum pernah balik dari
  /// server (mis. hasil isian form sebelum disimpan).
  final String? kodeLengkapServer;

  String get kodeLengkap =>
      kodeLengkapServer ??
      (revisi == null || revisi!.isEmpty ? kode : '${kode}_Rev.$revisi');

  factory MetodeKalibrasi.fromJson(Map<String, dynamic> json) =>
      MetodeKalibrasi(
        id: (json['id'] as num?)?.toInt() ?? 0,
        kode: '${json['kode'] ?? ''}',
        nama: '${json['nama'] ?? ''}',
        revisi: json['revisi']?.toString(),
        berlakuMulai: DateTime.tryParse('${json['berlaku_mulai'] ?? ''}'),
        equipmentCategoryId: (json['equipment_category_id'] as num?)?.toInt(),
        keterangan: json['keterangan'] as String?,
        aktif: json['aktif'] as bool? ?? true,
        kodeLengkapServer: json['kode_lengkap'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'kode': kode,
    'nama': nama,
    'revisi': ?revisi,
    'berlaku_mulai': ?berlakuMulai?.toIso8601String().split('T').first,
    'equipment_category_id': ?equipmentCategoryId,
    'keterangan': ?keterangan,
    'aktif': aktif,
  };

  MetodeKalibrasi salin({
    String? kode,
    String? nama,
    String? revisi,
    DateTime? berlakuMulai,
    int? equipmentCategoryId,
    String? keterangan,
    bool? aktif,
  }) => MetodeKalibrasi(
    id: id,
    kode: kode ?? this.kode,
    nama: nama ?? this.nama,
    revisi: revisi ?? this.revisi,
    berlakuMulai: berlakuMulai ?? this.berlakuMulai,
    equipmentCategoryId: equipmentCategoryId ?? this.equipmentCategoryId,
    keterangan: keterangan ?? this.keterangan,
    aktif: aktif ?? this.aktif,
  );
}

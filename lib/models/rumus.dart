/// Dari mana angka satu versi rumus dihitung.
enum SumberRumus {
  /// Dihitung program (`GumCalculator` di backend). Versi 1 SELALU ini —
  /// rumus yang sekarang jalan memang ada di kode.
  kode('kode'),

  /// Dihitung dari `ekspresi` di baris versinya.
  ///
  /// **Backend masih NOLAK ini** (422): evaluator ekspresinya belum ada.
  /// Sengaja tetap dimodelin biar riwayat lama yang kebetulan bawa nilai ini
  /// nggak bikin parsing meledak — bukan tanda fiturnya udah bisa dipakai.
  database('database');

  const SumberRumus(this.nilai);

  /// Dinamai `nilai`, bukan `kode`: salah satu anggota enum ini SENDIRI
  /// namanya `kode`, jadi field bernama sama bikin `SumberRumus.kode.kode`
  /// nggak bisa dikompilasi.
  final String nilai;

  static SumberRumus dariKode(Object? v) => SumberRumus.values.firstWhere(
    (s) => s.nilai == '$v'.trim().toLowerCase(),
    orElse: () => SumberRumus.kode,
  );
}

/// Tahap hidup satu versi rumus.
enum StatusVersiRumus {
  /// Belum masuk garis waktu. Tempat paling aman buat nyoba sebelum dipakai.
  draft('draft'),

  /// Yang dipakai buat ngitung di rentang tanggalnya.
  aktif('aktif'),

  /// Pernah berlaku, sekarang nggak. **Versi yang udah kepakai di hasil hitung
  /// nggak bisa diarsipin** — backend nolak 422, karena angka yang udah terbit
  /// jadi nggak bisa dijelasin lagi.
  arsip('arsip');

  const StatusVersiRumus(this.kode);

  final String kode;

  static StatusVersiRumus dariKode(Object? nilai) =>
      StatusVersiRumus.values.firstWhere(
        (s) => s.kode == '$nilai'.trim().toLowerCase(),
        orElse: () => StatusVersiRumus.draft,
      );
}

/// Satu versi rumus kalibrasi.
///
/// Yang bikin ini ada bukan "biar rumusnya bisa diubah", tapi biar pertanyaan
/// **"sesi tanggal 26 Mei dihitung pakai aturan yang mana?"** punya jawaban.
/// Itu beda dari "aturan apa yang dipakai sekarang", dan yang ditanya auditor
/// justru yang pertama.
class VersiRumus {
  const VersiRumus({
    required this.id,
    required this.formulaId,
    required this.nomorVersi,
    required this.sumber,
    required this.status,
    this.berlakuDari,
    this.berlakuSampai,
    this.parameter = const {},
    this.ekspresi = const {},
    this.catatan,
    this.pembuat,
    this.olehSistem = false,
    this.dibuatPada,
  });

  final int id;
  final int formulaId;
  final int nomorVersi;
  final SumberRumus sumber;
  final StatusVersiRumus status;

  final DateTime? berlakuDari;

  /// `null` = masih berlaku sampai sekarang.
  final DateTime? berlakuSampai;

  final Map<String, dynamic> parameter;
  final Map<String, dynamic> ekspresi;
  final String? catatan;

  /// Siapa yang nerbitin. `null` kalau dibikin sistem.
  final String? pembuat;

  /// Versi 1 lahir waktu organisasinya pertama nyimpen kalibrasi, bukan dari
  /// orang. Jadi pembuat `null` di situ **bukan data hilang** — dan layarnya
  /// harus bilang "dibuat sistem", bukan ngosongin kolomnya.
  final bool olehSistem;

  final DateTime? dibuatPada;

  bool get masihBerlaku =>
      status == StatusVersiRumus.aktif && berlakuSampai == null;

  static Map<String, dynamic> _peta(Object? nilai) =>
      nilai is Map<String, dynamic> ? nilai : const {};

  factory VersiRumus.fromJson(Map<String, dynamic> json) => VersiRumus(
    id: (json['id'] as num?)?.toInt() ?? 0,
    formulaId: (json['formula_id'] as num?)?.toInt() ?? 0,
    nomorVersi: (json['nomor_versi'] as num?)?.toInt() ?? 0,
    sumber: SumberRumus.dariKode(json['sumber']),
    status: StatusVersiRumus.dariKode(json['status']),
    berlakuDari: DateTime.tryParse('${json['berlaku_dari'] ?? ''}'),
    berlakuSampai: DateTime.tryParse('${json['berlaku_sampai'] ?? ''}'),
    parameter: _peta(json['parameter']),
    ekspresi: _peta(json['ekspresi']),
    catatan: json['catatan'] as String?,
    pembuat: switch (json['pembuat']) {
      final Map<String, dynamic> m => m['nama'] as String?,
      final String s => s,
      _ => null,
    },
    olehSistem: json['oleh_sistem'] as bool? ?? false,
    dibuatPada: DateTime.tryParse('${json['dibuat_pada'] ?? ''}'),
  );
}

/// Satu rumus kalibrasi beserta versi yang lagi berlaku.
class Rumus {
  const Rumus({
    required this.id,
    required this.kode,
    required this.nama,
    this.besaran,
    this.deskripsi,
    this.jumlahVersi = 0,
    this.versiBerlaku,
  });

  final int id;
  final String kode;
  final String nama;
  final String? besaran;
  final String? deskripsi;
  final int jumlahVersi;

  /// `null` = semua versinya draft/arsip, jadi nggak ada yang berlaku hari ini.
  final VersiRumus? versiBerlaku;

  factory Rumus.fromJson(Map<String, dynamic> json) => Rumus(
    id: (json['id'] as num?)?.toInt() ?? 0,
    kode: '${json['kode'] ?? ''}',
    nama: '${json['nama'] ?? ''}',
    besaran: json['besaran'] as String?,
    deskripsi: json['deskripsi'] as String?,
    jumlahVersi: (json['jumlah_versi'] as num?)?.toInt() ?? 0,
    versiBerlaku: json['versi_berlaku'] is Map<String, dynamic>
        ? VersiRumus.fromJson(json['versi_berlaku'] as Map<String, dynamic>)
        : null,
  );
}

/// Isi form "terbitkan versi baru".
class VersiRumusBaru {
  const VersiRumusBaru({
    required this.berlakuDari,
    this.parameter = const {},
    this.catatan,
    this.langsungAktif = false,
  });

  final DateTime berlakuDari;
  final Map<String, dynamic> parameter;
  final String? catatan;

  /// Default **false** — bikin draft dulu itu yang disaranin backend: draft
  /// belum masuk garis waktu, jadi itu tempat paling aman buat nyoba.
  final bool langsungAktif;

  Map<String, dynamic> toJson() => {
    // `kode` dipatok: backend nolak `database` dengan 422 karena evaluator
    // ekspresinya belum ada. Ngirim pilihan yang pasti ditolak cuma bikin
    // admin ketemu error yang nggak bisa dia benerin.
    'sumber': SumberRumus.kode.nilai,
    'berlaku_dari': berlakuDari.toIso8601String().split('T').first,
    if (parameter.isNotEmpty) 'parameter': parameter,
    if (catatan != null && catatan!.trim().isNotEmpty) 'catatan': catatan!.trim(),
    'langsung_aktif': langsungAktif,
  };
}

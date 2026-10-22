/// Titik ukur SESI — set titik yang disimpan server per sesi kalibrasi
/// (`docs/perintah-frontend-titik-ukur-sesi.md` di repo API, PRD §55).
///
/// Semua parser di sini tahan bentuk: kunci yang tidak dikenal dilewat, angka
/// boleh datang sebagai `num` atau teks berkoma (`"0,5"`), dan bentuk yang
/// rusak menghasilkan `null`/kosong — bukan exception yang mematikan layar.
library;

/// Angka dari JSON: `num`, atau teks (koma desimal diterima). `null` kalau
/// bukan angka sama sekali.
double? angkaTitikSesi(Object? nilai) => switch (nilai) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s.trim().replaceAll(',', '.')),
  _ => null,
};

int? _bulat(Object? nilai) => switch (nilai) {
  final int n => n,
  final num n => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

String? _teks(Object? nilai) =>
    nilai is String && nilai.trim().isNotEmpty ? nilai : null;

List<String> _daftarTeks(Object? nilai) => [
  if (nilai is List)
    for (final v in nilai)
      if (v is String && v.isNotEmpty) v,
];

/// Dua nominal dianggap SAMA dengan toleransi yang persis sama dengan server
/// (`TitikUkurSesi::cocok`) — nominal adalah penghubung titik ↔ pembacaan.
bool nominalCocok(double a, double b) {
  final skala = [1.0, a.abs(), b.abs()].reduce((x, y) => x > y ? x : y);
  return (a - b).abs() <= 1e-9 * skala;
}

/// Jenis nominal satu tabel titik.
enum JenisNominal {
  /// Nominal tercetak di kertas; titik profil tidak bisa diubah nominalnya.
  dipatok,

  /// Nominal bawaan cuma saran.
  saran,

  /// Nominal diketik teknisi (Tekanan).
  bebas;

  static JenisNominal dariApi(Object? nilai) => switch (nilai) {
    'dipatok' => JenisNominal.dipatok,
    'bebas' => JenisNominal.bebas,
    _ => JenisNominal.saran,
  };

  String get api => name;
}

/// Asal satu titik.
enum AsalTitik {
  profil,
  teknisi,
  pelanggan;

  static AsalTitik dariApi(Object? nilai) => switch (nilai) {
    'profil' => AsalTitik.profil,
    'pelanggan' => AsalTitik.pelanggan,
    _ => AsalTitik.teknisi,
  };

  String get api => name;
}

/// Batas jumlah pengulangan satu tabel. `null` di [TabelBatasTitik] = dipatok
/// lembarnya.
class BatasPengulangan {
  const BatasPengulangan({
    required this.min,
    required this.maks,
    required this.bawaan,
  });

  final int min;
  final int maks;
  final int bawaan;

  /// Server memaku min = maks (Tekanan: 3) — tidak ada yang bisa dipilih.
  bool get dipatok => min == maks;

  static BatasPengulangan? dariJson(Object? json) {
    if (json is! Map) return null;
    final min = _bulat(json['min']);
    final maks = _bulat(json['maks']);
    if (min == null || maks == null) return null;

    return BatasPengulangan(
      min: min,
      maks: maks,
      bawaan: _bulat(json['bawaan']) ?? min,
    );
  }
}

/// Satu tabel titik di `batas_titik.tabel[]`.
class TabelBatasTitik {
  const TabelBatasTitik({
    required this.kode,
    required this.judul,
    required this.min,
    required this.maks,
    required this.bolehTambah,
    required this.bolehNonaktif,
    required this.nominal,
    this.alasanTambah,
    this.alasanNonaktif,
    this.bawaan = const [],
    this.fase = const ['sesudah'],
    this.satuan,
    this.pengulangan,
    this.pertamaWajibAktif = false,
    this.alasanPertama,
  });

  final String kode;
  final String judul;
  final int min;
  final int maks;
  final bool bolehTambah;
  final bool bolehNonaktif;
  final String? alasanTambah;
  final String? alasanNonaktif;
  final JenisNominal nominal;
  final List<double> bawaan;

  /// Fase yang BOLEH dipilih (`sebelum`/`sesudah`).
  final List<String> fase;
  final String? satuan;
  final BatasPengulangan? pengulangan;

  /// Tekanan: titik pertama tabel tidak boleh dinonaktifkan dan wajib jadi
  /// baris pertama `measurements`.
  final bool pertamaWajibAktif;
  final String? alasanPertama;

  bool get bolehFaseSebelum => fase.contains('sebelum');

  static TabelBatasTitik? dariJson(Object? json) {
    if (json is! Map) return null;
    final kode = _teks(json['kode']);
    if (kode == null) return null;

    final fase = _daftarTeks(json['fase']);

    return TabelBatasTitik(
      kode: kode,
      judul: _teks(json['judul']) ?? kode,
      min: _bulat(json['min']) ?? 1,
      maks: _bulat(json['maks']) ?? 60,
      bolehTambah: json['boleh_tambah'] == true,
      bolehNonaktif: json['boleh_nonaktif'] != false,
      alasanTambah: _teks(json['alasan_tambah']),
      alasanNonaktif: _teks(json['alasan_nonaktif']),
      nominal: JenisNominal.dariApi(json['nominal']),
      bawaan: [
        if (json['bawaan'] is List)
          for (final n in json['bawaan'] as List) ?angkaTitikSesi(n),
      ],
      fase: fase.isEmpty ? const ['sesudah'] : fase,
      satuan: _teks(json['satuan']),
      pengulangan: BatasPengulangan.dariJson(json['pengulangan']),
      pertamaWajibAktif: json['pertama_wajib_aktif'] == true,
      alasanPertama: _teks(json['alasan_pertama']),
    );
  }
}

/// `batas_titik` (lembar kosong) / `meta.titik_sesi.batas` (sesi).
class BatasTitik {
  const BatasTitik({
    required this.didukung,
    this.alasan,
    this.tabel = const [],
  });

  /// `false` = lembar ini belum mendukung titik sesi; perilaku lama dipakai.
  final bool didukung;
  final String? alasan;
  final List<TabelBatasTitik> tabel;

  TabelBatasTitik? tabelUntuk(String? kode) {
    if (kode == null) return tabel.length == 1 ? tabel.first : null;
    for (final t in tabel) {
      if (t.kode == kode) return t;
    }
    return null;
  }

  static BatasTitik? dariJson(Object? json) {
    if (json is! Map) return null;
    final tabel = <TabelBatasTitik>[
      if (json['tabel'] is List)
        for (final t in json['tabel'] as List) ?TabelBatasTitik.dariJson(t),
    ];

    return BatasTitik(
      // Server yang mengirim `didukung: true` tanpa satu tabel pun tidak bisa
      // dipakai — diperlakukan sebagai tidak didukung, bukan editor kosong.
      didukung: json['didukung'] == true && tabel.isNotEmpty,
      alasan: _teks(json['alasan']),
      tabel: tabel,
    );
  }
}

/// Satu titik ukur sesi.
class TitikSesi {
  const TitikSesi({
    required this.id,
    required this.tabel,
    required this.nominal,
    this.satuan,
    this.fase = const ['sesudah'],
    this.aktif = true,
    this.asal = AsalTitik.teknisi,
    this.alasan,
    this.justifikasiCmc,
  });

  /// Stabil sepanjang umur titik (bawaan: `profil-<tabel>-<n>`, baru: UUID).
  final String id;
  final String tabel;
  final double nominal;
  final String? satuan;
  final List<String> fase;
  final bool aktif;
  final AsalTitik asal;

  /// Alasan nonaktif ATAU dasar titik pelanggan (≥ 5 huruf, server).
  final String? alasan;
  final String? justifikasiCmc;

  bool get denganSebelum => fase.contains('sebelum');

  TitikSesi salin({
    double? nominal,
    List<String>? fase,
    bool? aktif,
    String? alasan,
    bool hapusAlasan = false,
    String? justifikasiCmc,
    bool hapusJustifikasi = false,
  }) => TitikSesi(
    id: id,
    tabel: tabel,
    nominal: nominal ?? this.nominal,
    satuan: satuan,
    fase: fase ?? this.fase,
    aktif: aktif ?? this.aktif,
    asal: asal,
    alasan: hapusAlasan ? null : (alasan ?? this.alasan),
    justifikasiCmc: hapusJustifikasi
        ? null
        : (justifikasiCmc ?? this.justifikasiCmc),
  );

  /// `null` kalau `id` atau `nominal` tidak terbaca — titik tanpa dua itu
  /// tidak bisa dihubungkan ke pembacaan mana pun.
  static TitikSesi? dariJson(Object? json, {String? tabelBawaan}) {
    if (json is! Map) return null;
    final id = _teks(json['id']);
    final nominal = angkaTitikSesi(json['nominal']);
    final tabel = _teks(json['tabel']) ?? tabelBawaan;
    if (id == null || nominal == null || tabel == null) return null;

    final fase = _daftarTeks(json['fase']);

    return TitikSesi(
      id: id,
      tabel: tabel,
      nominal: nominal,
      satuan: _teks(json['satuan']),
      fase: fase.isEmpty ? const ['sesudah'] : fase,
      aktif: json['aktif'] != false,
      asal: AsalTitik.dariApi(json['asal']),
      alasan: _teks(json['alasan']),
      justifikasiCmc: _teks(json['justifikasi_cmc']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tabel': tabel,
    'nominal': nominal,
    if (satuan != null) 'satuan': satuan,
    'fase': fase,
    'aktif': aktif,
    'asal': asal.api,
    if (alasan != null && alasan!.trim().isNotEmpty) 'alasan': alasan!.trim(),
    if (justifikasiCmc != null && justifikasiCmc!.trim().isNotEmpty)
      'justifikasi_cmc': justifikasiCmc!.trim(),
  };
}

/// Set titik yang tersimpan di server (`meta.titik_sesi.set`, atau
/// `titik_sesi` di badan 409).
class SetTitikSesi {
  const SetTitikSesi({
    required this.revisi,
    required this.titik,
    this.pengulangan = const {},
    this.diubahPada,
  });

  final int revisi;
  final List<TitikSesi> titik;
  final Map<String, int> pengulangan;
  final DateTime? diubahPada;

  static SetTitikSesi? dariJson(Object? json, {String? tabelBawaan}) {
    if (json is! Map || json['titik'] is! List) return null;

    return SetTitikSesi(
      revisi: _bulat(json['revisi']) ?? 0,
      titik: [
        for (final t in json['titik'] as List)
          ?TitikSesi.dariJson(t, tabelBawaan: tabelBawaan),
      ],
      pengulangan: {
        if (json['pengulangan'] is Map)
          for (final e in (json['pengulangan'] as Map).entries)
            '${e.key}': ?_bulat(e.value),
      },
      diubahPada: switch (json['diubah_pada']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}

/// `meta.titik_sesi` di `GET /calibrations/{id}` dan respons simpan.
class MetaTitikSesi {
  const MetaTitikSesi({
    required this.batas,
    this.set,
    this.bawaan,
    this.diLuarCmc = const [],
  });

  final BatasTitik batas;

  /// `null` = sesi belum punya set (pakai [bawaan]).
  final SetTitikSesi? set;
  final List<TitikSesi>? bawaan;

  /// Id titik AKTIF yang di luar cakupan CMC akreditasi.
  final List<String> diLuarCmc;

  static MetaTitikSesi? dariJson(Object? json) {
    if (json is! Map) return null;
    final batas = BatasTitik.dariJson(json['batas']);
    if (batas == null) return null;

    final tabelTunggal = batas.tabel.length == 1
        ? batas.tabel.first.kode
        : null;

    return MetaTitikSesi(
      batas: batas,
      set: SetTitikSesi.dariJson(json['set'], tabelBawaan: tabelTunggal),
      bawaan: json['bawaan'] is List
          ? parseTitikSesi(json['bawaan'], tabelBawaan: tabelTunggal)
          : null,
      diLuarCmc: _daftarTeks(json['di_luar_cmc']),
    );
  }
}

/// Daftar titik dari JSON (`titik_sesi_bawaan`), titik cacat dilewat.
List<TitikSesi> parseTitikSesi(Object? json, {String? tabelBawaan}) => [
  if (json is List)
    for (final t in json) ?TitikSesi.dariJson(t, tabelBawaan: tabelBawaan),
];

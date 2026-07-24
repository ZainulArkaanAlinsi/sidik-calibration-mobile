/// Bentuk baku Lembar Kerja (SIDIK-FM-CAL-0509_Rev.4), hasil
/// `GET /api/calibrations/lembar-kerja`.
///
/// **Kolomnya sengaja NGGAK di-hardcode di sini.** Backend yang punya definisi
/// formulirnya, dan responsnya udah beda sendiri per role — teknisi nggak
/// pernah nerima kolom administratif (Order Number, Calibration Methode,
/// Thermohygro used) sama sekali, bukan cuma disembunyiin. Jadi kalau
/// formulirnya direvisi (Rev.5, dst), layar input ikut berubah tanpa rilis
/// mobile baru.
library;

import '../core/utils/parse_list.dart';

/// Tipe kolom yang dikenali layar input. Tipe asing dari backend dianggap
/// [teks] — kolom baru tetap kelihatan & bisa diisi, nggak bikin layar kosong.
enum TipeField {
  teks,
  teksPanjang,
  angka,
  tanggal,
  pilihan,
  centang;

  static TipeField fromApi(String value) => switch (value) {
    'teks' => TipeField.teks,
    'teks_panjang' => TipeField.teksPanjang,
    'angka' => TipeField.angka,
    'tanggal' => TipeField.tanggal,
    'pilihan' => TipeField.pilihan,
    'centang' => TipeField.centang,
    _ => TipeField.teks,
  };
}

/// Dari mana isi kolom datang. `otomatis` = ketarik dari data lain (alat,
/// pelanggan, akun yang login) dan **read-only** di layar.
enum SumberField {
  manual,
  otomatis,
  masterAlat,
  masterStandar,
  masterRuangan,
  masterMetode;

  static SumberField fromApi(String? value) => switch (value) {
    'otomatis' => SumberField.otomatis,
    'master_alat' => SumberField.masterAlat,
    'master_standar' => SumberField.masterStandar,
    'master_ruangan' => SumberField.masterRuangan,
    'master_metode' => SumberField.masterMetode,
    _ => SumberField.manual,
  };

  /// Kolom yang isinya ketarik sistem — teknisi lihat, nggak ngetik.
  bool get readOnly => this == SumberField.otomatis;
}

/// Satu pilihan di kolom bertipe [TipeField.pilihan] yang daftarnya udah
/// dipatok backend (mis. Location: In lab / Insitu).
class PilihanField {
  const PilihanField({required this.nilai, required this.label});

  final String nilai;
  final String label;

  factory PilihanField.fromJson(Map<String, dynamic> json) => PilihanField(
    nilai: json['nilai'] as String,
    label: json['label'] as String? ?? json['nilai'] as String,
  );
}

/// Satu kolom di lembar kerja.
class FieldLembarKerja {
  const FieldLembarKerja({
    required this.kode,
    required this.label,
    required this.tipe,
    required this.sumber,
    required this.wajib,
    this.satuan,
    this.pilihan = const [],
  });

  /// Kode yang dipakai di payload, mis. `suhu_awal` atau `equipment.merk`.
  /// Yang bertitik = kolom turunan (read-only), bukan kunci payload.
  final String kode;

  final String label;
  final TipeField tipe;
  final SumberField sumber;
  final String? satuan;
  final List<PilihanField> pilihan;

  /// **Backend selalu ngirim `false`.** Disimpen apa adanya, bukan diabaikan,
  /// biar kalau suatu saat ada kolom yang beneran wajib, layarnya udah siap —
  /// tapi tombol kirim tetap nggak pernah dikunci sama field ini (lihat
  /// docblock `LembarKerjaTemplate` di backend).
  final bool wajib;

  /// Kolom turunan kayak `equipment.merk` — diisi sistem dari alat yang
  /// dipilih, bukan dikirim balik sebagai kunci payload sendiri.
  bool get turunan => kode.contains('.');

  factory FieldLembarKerja.fromJson(Map<String, dynamic> json) {
    return FieldLembarKerja(
      kode: json['kode'] as String,
      label: json['label'] as String? ?? json['kode'] as String,
      tipe: TipeField.fromApi(json['tipe'] as String? ?? 'teks'),
      sumber: SumberField.fromApi(json['sumber'] as String?),
      wajib: json['wajib'] as bool? ?? false,
      satuan: json['satuan'] as String?,
      pilihan: parseListAman(json['pilihan'], PilihanField.fromJson),
    );
  }
}

/// Satu baris di tabel hasil — larutan standar yang tercetak di lembar kerja.
class BarisTabelHasil {
  const BarisTabelHasil({required this.titikUkur, required this.label});

  final double titikUkur;
  final String label;

  factory BarisTabelHasil.fromJson(Map<String, dynamic> json) =>
      BarisTabelHasil(
        titikUkur: (json['titik_ukur'] as num).toDouble(),
        label: json['label'] as String? ?? '${json['titik_ukur']}',
      );
}

/// Satu kolom di dalam sel tabel hasil. Tiap sel isinya DUA angka (pH & °C),
/// jadi ini yang nentuin ada berapa kotak per pengulangan.
class KolomTabelHasil {
  const KolomTabelHasil({
    required this.kode,
    required this.label,
    this.satuan,
  });

  /// `pembacaan` atau `suhu` — dipetakan ke kunci payload per tahap.
  final String kode;
  final String label;
  final String? satuan;

  factory KolomTabelHasil.fromJson(Map<String, dynamic> json) =>
      KolomTabelHasil(
        kode: json['kode'] as String,
        label: json['label'] as String? ?? json['kode'] as String,
        satuan: json['satuan'] as String?,
      );
}

/// Satu tabel hasil: Before atau After adjustment.
class TabelHasil {
  const TabelHasil({
    required this.tahap,
    required this.judul,
    required this.baris,
    required this.kolom,
    required this.pengulangan,
  });

  /// `sebelum_adjustment` / `sesudah_adjustment`.
  final String tahap;
  final String judul;
  final List<BarisTabelHasil> baris;
  final List<KolomTabelHasil> kolom;

  /// Nomor Repeat yang tercetak di lembar kerja, biasanya 1..5.
  final List<int> pengulangan;

  bool get sebelumAdjustment => tahap == 'sebelum_adjustment';

  factory TabelHasil.fromJson(Map<String, dynamic> json) => TabelHasil(
    tahap: json['tahap'] as String,
    judul: json['judul'] as String? ?? '',
    baris: parseListAman(json['baris'], BarisTabelHasil.fromJson),
    kolom: parseListAman(json['kolom'], KolomTabelHasil.fromJson),
    pengulangan: (json['pengulangan'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
  );
}

/// Satu bagian (section) lembar kerja, mis. "EQUIPMENT IDENTITY AND CUSTOMER
/// DATA". Bagian hasil punya [tabel] bukan [field].
class BagianLembarKerja {
  const BagianLembarKerja({
    required this.kode,
    required this.judul,
    required this.field,
    required this.tabel,
    this.sumber,
  });

  final String kode;
  final String judul;
  final List<FieldLembarKerja> field;
  final List<TabelHasil> tabel;

  /// Mis. `master_standar` di bagian Usage Check — daftarnya diambil dari
  /// master data lab, bukan dipatok di formulirnya.
  final String? sumber;

  factory BagianLembarKerja.fromJson(Map<String, dynamic> json) =>
      BagianLembarKerja(
        kode: json['kode'] as String,
        judul: json['judul'] as String? ?? '',
        sumber: json['sumber'] as String?,
        field: parseListAman(json['field'], FieldLembarKerja.fromJson),
        tabel: parseListAman(json['tabel'], TabelHasil.fromJson),
      );
}

/// Formulir lembar kerja utuh.
class LembarKerja {
  const LembarKerja({
    required this.kodeDokumen,
    required this.judul,
    required this.untuk,
    required this.jumlahPengulangan,
    required this.larutanStandar,
    required this.satuan,
    required this.satuanSuhu,
    required this.semuaKolomOpsional,
    required this.catatanPengisian,
    required this.bagian,
  });

  final String kodeDokumen;
  final String judul;

  /// `teknisi` atau `admin` — backend yang mutusin dari role token.
  final String untuk;

  final int jumlahPengulangan;
  final List<double> larutanStandar;
  final String satuan;
  final String satuanSuhu;

  /// Selalu true dari backend. Dipakai layar buat mastiin tombol kirim nggak
  /// pernah dikunci — bukan buat dibalik jadi validasi.
  final bool semuaKolomOpsional;

  final String catatanPengisian;
  final List<BagianLembarKerja> bagian;

  bool get untukAdmin => untuk == 'admin';

  /// Bagian yang isinya tabel hasil (Before/After adjustment).
  BagianLembarKerja? get bagianHasil {
    for (final b in bagian) {
      if (b.tabel.isNotEmpty) return b;
    }
    return null;
  }

  factory LembarKerja.fromJson(Map<String, dynamic> json) => LembarKerja(
    kodeDokumen: json['kode_dokumen'] as String? ?? '',
    judul: json['judul'] as String? ?? '',
    untuk: json['untuk'] as String? ?? 'teknisi',
    jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 5,
    larutanStandar: (json['larutan_standar'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList(),
    satuan: json['satuan'] as String? ?? '',
    satuanSuhu: json['satuan_suhu'] as String? ?? '°C',
    semuaKolomOpsional: json['semua_kolom_opsional'] as bool? ?? true,
    catatanPengisian: json['catatan_pengisian'] as String? ?? '',
    bagian: parseListAman(json['bagian'], BagianLembarKerja.fromJson),
  );
}

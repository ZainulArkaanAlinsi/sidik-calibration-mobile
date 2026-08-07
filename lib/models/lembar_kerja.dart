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
  masterMetode,

  /// Unit thermohygro yang tercetak di formulir. Pilihannya ikut di respons
  /// (`pilihan`, berkelompok Insitu/Inlab) — jadi layar nggak perlu narik
  /// `GET /standards` lalu nyaring sendiri mana yang thermohygro.
  masterThermohygro;

  static SumberField fromApi(String? value) => switch (value) {
    'otomatis' => SumberField.otomatis,
    'master_alat' => SumberField.masterAlat,
    'master_standar' => SumberField.masterStandar,
    'master_ruangan' => SumberField.masterRuangan,
    'master_metode' => SumberField.masterMetode,
    'master_thermohygro' => SumberField.masterThermohygro,
    _ => SumberField.manual,
  };

  /// Kolom yang isinya ketarik sistem — teknisi lihat, nggak ngetik.
  bool get readOnly => this == SumberField.otomatis;
}

/// Satu pilihan di kolom bertipe [TipeField.pilihan] yang daftarnya udah
/// dipatok backend (mis. Location: In lab / Insitu).
class PilihanField {
  const PilihanField({
    required this.nilai,
    required this.label,
    this.grup,
  });

  final String nilai;
  final String label;

  /// Kepala kelompok, mis. `Insitu` / `Inlab` di "6. Thermohygro used".
  /// Null = pilihan datar tanpa pengelompokan.
  ///
  /// Di kertas keempat unit thermohygro itu dipisah dua baris berlabel, dan
  /// pemisahan itu bukan hiasan: Insitu berarti unit yang dibawa ke lokasi
  /// pelanggan, Inlab yang tinggal di lab. Teknisi milih berdasarkan itu.
  final String? grup;

  factory PilihanField.fromJson(Map<String, dynamic> json) => PilihanField(
    nilai: '${json['nilai']}',
    label: json['label'] as String? ?? '${json['nilai']}',
    grup: json['grup'] as String?,
  );
}

/// Satu baris tabel "STANDARD" yang TERCETAK di lembar kerja.
///
/// Bukan hasil pilih dari katalog: kelima barisnya udah ada di formulirnya,
/// teknisi cuma nyentang Usage Check. [standardId] null berarti standar itu
/// belum kedaftar di master lab — barisnya tetap tampil (biar nggak ada
/// standar yang diam-diam hilang dari lembar resmi), tapi centangnya nggak
/// bisa ditautkan ke data master.
class BarisStandar {
  const BarisStandar({
    required this.label,
    required this.standardId,
    required this.terdaftar,
    this.serialNumber,
    this.noSertifikat,
    this.tertelusurKe,
  });

  final String label;
  final int? standardId;
  final bool terdaftar;
  final String? serialNumber;
  final String? noSertifikat;
  final String? tertelusurKe;

  factory BarisStandar.fromJson(Map<String, dynamic> json) => BarisStandar(
    label: json['label'] as String? ?? '—',
    standardId: (json['standard_id'] as num?)?.toInt(),
    terdaftar: json['terdaftar'] as bool? ?? (json['standard_id'] != null),
    serialNumber: json['serial_number'] as String?,
    noSertifikat: json['no_sertifikat'] as String?,
    tertelusurKe: json['tertelusur_ke'] as String?,
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
  const BarisTabelHasil({
    required this.titikUkur,
    required this.label,
    this.desimal,
    this.resolusi,
  });

  final double titikUkur;
  final String label;

  /// Jumlah desimal resolusi titik ini (Turbidimeter: 2/1/0 buat 1/100/1000
  /// NTU). Dipakai [formatNilai] buat mad pembacaan ke resolusi tanpa buang nol
  /// belakang — `4,60` tetap `4,60`. `null` = alat resolusi seragam (mis. pH),
  /// layar jatuh ke perilaku lama.
  final int? desimal;
  final double? resolusi;

  factory BarisTabelHasil.fromJson(Map<String, dynamic> json) =>
      BarisTabelHasil(
        titikUkur: (json['titik_ukur'] as num).toDouble(),
        label: json['label'] as String? ?? '${json['titik_ukur']}',
        desimal: (json['desimal'] as num?)?.toInt(),
        resolusi: (json['resolusi'] as num?)?.toDouble(),
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
    this.barisPerSatuan = const {},
  });

  /// `sebelum_adjustment` / `sesudah_adjustment`.
  final String tahap;
  final String judul;
  final List<BarisTabelHasil> baris;
  final List<KolomTabelHasil> kolom;

  /// Baris tabel per satuan alat — cuma Refractometer yang ngirim ini.
  ///
  /// Satuan alat nentuin titik standarnya, bukan cuma koefisien suhunya:
  /// larutan fisik yang sama dibaca **2,5 °Brix** atau **1,33659 n20D**
  /// (`BSAG2.5-0034`). Tanpa ini, sesi °Brix ngirim `titik_ukur: 1,33659`
  /// bareng `satuan: "°Brix"` — nilai standar satu skala, pembacaan skala lain.
  ///
  /// Backend ngirim SEMUA set sekaligus, bukan lembar kerjanya diambil ulang
  /// tiap satuan diganti: satuannya dipilih di dalam formulir ini, jadi waktu
  /// bentuknya diambil backend belum tahu mana yang bakal dipakai — dan ngambil
  /// ulang bakal ngereset semua yang udah diketik teknisi di lapangan.
  ///
  /// Kosong = alat satu satuan; [baris] yang dipakai, persis kayak dulu.
  final Map<String, List<BarisTabelHasil>> barisPerSatuan;

  /// Baris buat [satuan], jatuh ke [baris] kalau satuannya nggak dikenal —
  /// bukan bikin tabel kosong. Alat satu satuan lewat sini juga.
  List<BarisTabelHasil> barisUntuk(String satuan) =>
      barisPerSatuan[satuan] ?? baris;

  /// Nomor Repeat yang tercetak di lembar kerja, biasanya 1..5.
  final List<int> pengulangan;

  bool get sebelumAdjustment => tahap == 'sebelum_adjustment';

  factory TabelHasil.fromJson(Map<String, dynamic> json) => TabelHasil(
    tahap: json['tahap'] as String,
    judul: json['judul'] as String? ?? '',
    baris: parseListAman(json['baris'], BarisTabelHasil.fromJson),
    barisPerSatuan: {
      for (final e in (json['baris_per_satuan'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .entries)
        e.key: parseListAman(e.value, BarisTabelHasil.fromJson),
    },
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
    required this.halaman,
    required this.field,
    required this.tabel,
    required this.baris,
    this.sumber,
  });

  final String kode;
  final String judul;

  /// Halaman lembar kerja tempat bagian ini dicetak: 1 atau 2.
  ///
  /// Ikut backend, bukan dihitung di sini — kalau formulirnya direvisi
  /// (Rev.5, dst) susunan halamannya berubah di satu tempat.
  final int halaman;

  final List<FieldLembarKerja> field;
  final List<TabelHasil> tabel;

  /// Baris tercetak tabel STANDARD. Kosong di bagian lain.
  final List<BarisStandar> baris;

  /// Mis. `master_standar` — daftarnya diambil dari master data lab, bukan
  /// dipatok di formulirnya. Null di bagian yang barisnya udah tercetak.
  final String? sumber;

  factory BagianLembarKerja.fromJson(Map<String, dynamic> json) =>
      BagianLembarKerja(
        kode: json['kode'] as String,
        judul: json['judul'] as String? ?? '',
        // Default 1: lembar kerja versi backend lama nggak ngirim `halaman`,
        // dan satu halaman penuh lebih baik daripada layar kosong.
        halaman: (json['halaman'] as num?)?.toInt() ?? 1,
        sumber: json['sumber'] as String?,
        field: parseListAman(json['field'], FieldLembarKerja.fromJson),
        tabel: parseListAman(json['tabel'], TabelHasil.fromJson),
        baris: parseListAman(json['baris'], BarisStandar.fromJson),
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

  /// Nomor halaman yang beneran ada, urut. Dihitung dari isi — bukan dipatok
  /// `[1, 2]` — supaya lembar kerja alat lain yang halamannya lebih banyak
  /// (atau cuma satu) nggak perlu nyentuh layar ini.
  List<int> get halaman {
    final nomor = bagian.map((b) => b.halaman).toSet().toList()..sort();
    return nomor.isEmpty ? const [1] : nomor;
  }

  /// Bagian di satu halaman, urutannya ngikut backend.
  List<BagianLembarKerja> bagianDiHalaman(int nomor) =>
      bagian.where((b) => b.halaman == nomor).toList();

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

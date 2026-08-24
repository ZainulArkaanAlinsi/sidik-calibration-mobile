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
    this.labelCetak,
    this.serialNumber,
    this.noSertifikat,
    this.tertelusurKe,
  });

  final String label;

  /// Tulisan baris ini di lembar CETAK, kalau beda dari [label].
  ///
  /// Lembar Conductivity `Rev.5` masih menulis nominal botol lama
  /// (`Std Solution 84 µS`) dan readout lama (`Victor 14+`), sementara master
  /// sudah pindah ke larutan & alat yang sekarang. Yang dicentang tetap alat
  /// yang benar; yang dibaca teknisi tetap tulisan yang ada di kertas.
  final String? labelCetak;
  final int? standardId;
  final bool terdaftar;
  final String? serialNumber;
  final String? noSertifikat;
  final String? tertelusurKe;

  factory BarisStandar.fromJson(Map<String, dynamic> json) => BarisStandar(
    label: json['label'] as String? ?? '—',
    labelCetak: json['label_cetak'] as String?,
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
    this.catatan,
  });

  /// Kode yang dipakai di payload, mis. `suhu_awal` atau `equipment.merk`.
  /// Yang bertitik = kolom turunan (read-only), bukan kunci payload.
  final String kode;

  final String label;
  final TipeField tipe;
  final SumberField sumber;
  final String? satuan;
  final List<PilihanField> pilihan;

  /// Kalimat penjelas dari backend, ditampilin apa adanya di bawah kolomnya.
  /// Dipakai kolom yang butuh alasan kenapa dia ada — mis. kolom di luar
  /// kertas, yang teknisi nggak akan nemu waktu nyocokin layar ke lembarnya.
  final String? catatan;

  /// **Backend selalu ngirim `false`.** Disimpen apa adanya, bukan diabaikan,
  /// biar kalau suatu saat ada kolom yang beneran wajib, layarnya udah siap —
  /// tapi tombol kirim tetap nggak pernah dikunci sama field ini (lihat
  /// docblock `LembarKerjaTemplate` di backend).
  final bool wajib;

  /// Kolom turunan kayak `equipment.merk` — diisi sistem dari alat yang
  /// dipilih, bukan dikirim balik sebagai kunci payload sendiri.
  ///
  /// `spesifikasi_alat.*` DIKECUALIKAN: titiknya di situ artinya
  /// PENGELOMPOKAN, bukan turunan. Rentang ukur, kapasitas, dan resolusi
  /// diketik teknisi dari badan alatnya — dulu ditarik otomatis dari master
  /// (`equipment.range_resolusi`), dan buat alat berskala dua (`%T` dan `nm`)
  /// master cuma bisa jawab separuh.
  bool get turunan => kode.contains('.') && !spesifikasiAlat;

  /// Kolom yang masuk ke `spesifikasi_alat` di payload, dikelompokkan lewat
  /// awalan kodenya. Kuncinya bagian sesudah titik.
  bool get spesifikasiAlat => kode.startsWith('spesifikasi_alat.');

  /// Kunci kolom ini di dalam `spesifikasi_alat`.
  String get kunciSpesifikasi => kode.substring('spesifikasi_alat.'.length);

  factory FieldLembarKerja.fromJson(Map<String, dynamic> json) {
    return FieldLembarKerja(
      kode: json['kode'] as String,
      label: json['label'] as String? ?? json['kode'] as String,
      tipe: TipeField.fromApi(json['tipe'] as String? ?? 'teks'),
      sumber: SumberField.fromApi(json['sumber'] as String?),
      wajib: json['wajib'] as bool? ?? false,
      satuan: json['satuan'] as String?,
      pilihan: parseListAman(json['pilihan'], PilihanField.fromJson),
      catatan: json['catatan'] as String?,
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
    this.standardId,
    this.standardNama,
    this.satuan,
    this.eksklusifDengan,
    this.tipe,
  });

  final double titikUkur;
  final String label;

  /// Salinan baris ini dengan titik & label baru, sisanya diwarisi.
  ///
  /// Dipakai lembar yang titiknya boleh diatur teknisi (`titik_bisa_diubah`):
  /// yang berubah cuma NILAI titiknya — satuan, resolusi, desimal, dan standar
  /// acuannya tetap milik bentuk dari backend, karena tiga hal itu properti
  /// alat & kalibratornya, bukan pilihan teknisi.
  ///
  /// [eksklusifDengan] sengaja TIDAK ikut: pasangan eksklusif nunjuk titik lain
  /// yang mungkin sudah nggak ada di daftar baru, dan pasangan yang nunjuk
  /// titik hantu bikin barisnya terkunci selamanya tanpa alasan yang kelihatan.
  BarisTabelHasil salinDenganTitik(double titik, String labelBaru) =>
      BarisTabelHasil(
        titikUkur: titik,
        label: labelBaru,
        desimal: desimal,
        resolusi: resolusi,
        standardId: standardId,
        standardNama: standardNama,
        satuan: satuan,
        tipe: tipe,
      );

  /// Jenis isian baris ini kalau BUKAN angka biasa.
  ///
  /// Sejauh ini cuma `jam` yang dipakai — baris `Time` di lembar Autoklaf,
  /// yang tiap kolomnya diisi jam sterilisasi (`HH:mm`), bukan hasil ukur.
  ///
  /// `null` = baris angka seperti delapan alat lain, dan seluruh perilaku lama
  /// jalan persis kayak sebelumnya.
  ///
  /// Ditaruh di BARIS, bukan di tabel: satu tabel Autoklaf memuat baris jam DAN
  /// baris angka sekaligus, jadi jenisnya properti baris.
  final String? tipe;

  /// Satuan baris INI, buat alat yang nyampur satuan dalam satu lembar.
  ///
  /// Conductivity baca 25 & 1412 dalam µS/cm tapi 111 dalam mS/cm — lembarnya
  /// ngirim `satuan: null` di level atas plus `satuan_campuran: true`, dan
  /// satuan yang bener nempel di tiap baris. Ambil dari level lembar = seluruh
  /// kolom salah label.
  ///
  /// `null` = alat bersatuan seragam (pH, Turbidimeter, Chlorine,
  /// Refractometer); layar jatuh ke satuan lembar seperti biasa.
  final String? satuan;

  /// Titik ukur baris pasangan yang **meniadakan** baris ini, atau `null`.
  ///
  /// Titik tengah Conductivity punya dua bentuk buat botol larutan yang SAMA:
  /// `1412 µS/cm` dan `1,412 mS/cm`. Teknisi ngisi salah satu, nggak pernah
  /// dua-duanya — kalau dua-duanya keisi, sistem nerima dua nilai buat satu
  /// botol dan sertifikatnya jadi ambigu.
  ///
  /// Nilainya `titik_ukur` pasangannya, jadi layar bisa nyari barisnya tanpa
  /// perlu id tambahan.
  final double? eksklusifDengan;

  /// Larutan standar yang TERCETAK berpasangan sama titik ini di formulir —
  /// titik 7,00 pakai pH Buffer Solution 7, titik 100 NTU pakai botol 100 NTU.
  ///
  /// Dulu nggak ada, dan teknisi milih sendiri per titik dari dropdown berisi
  /// seluruh master standar. Salah pilih nggak kelihatan salah di layar: sesi
  /// pH 7 Agt 2026 kepilih Buffer 4 di titik 7,00, dan baru ketahuan di
  /// sertifikat sebagai Correction `-2,99` (= 4,0092 − 7,00).
  ///
  /// Null = backend nggak nemu standarnya di master (belum didaftarin, atau
  /// alatnya emang nggak punya pasangan tetap). Layar jatuh ke pilihan manual
  /// buat titik itu doang.
  final int? standardId;

  /// Nama standar pasangannya, buat ditampilin tanpa nunggu `GET /standards`.
  final String? standardNama;

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
        standardId: (json['standard_id'] as num?)?.toInt(),
        standardNama: json['standard_nama'] as String?,
        satuan: json['satuan'] as String?,
        eksklusifDengan: (json['eksklusif_dengan'] as num?)?.toDouble(),
        tipe: json['tipe'] as String?,
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

/// Kolom kiri yang nilainya SAMA buat seluruh tabel, dan di lembar cetak
/// digambar sebagai satu sel yang kegabung ke bawah.
///
/// Blok %T yang pertama punya: `λ (nm)` = `560`. Itu bukan data per baris —
/// seluruh titik %T diukur di panjang gelombang yang sama, dan angkanya bagian
/// dari identitas tabelnya.
class KolomTetap {
  const KolomTetap({required this.label, required this.nilai});

  final String label;
  final String nilai;

  factory KolomTetap.fromJson(Map<String, dynamic> json) => KolomTetap(
    label: json['label'] as String? ?? '',
    nilai: '${json['nilai'] ?? ''}',
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
    this.nomorBaris = false,
    this.judulNilai,
    this.judulPengulangan,
    this.prefiksPengulangan,
    this.pengulanganPerBaris,
    this.kolomTetap,
    this.catatan,
    this.sumbuPengulangan = 'kolom',
    this.slotCetak = const [],
    this.judulNilaiPerMode = const {},
    this.judulPengulanganPerMode = const {},
    this.pengulanganArah = const {},
    this.titikBisaDiubah = false,
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

  /// Kolom "No." di kiri tabel — nomor urut baris seperti di lembar cetak.
  final bool nomorBaris;

  /// Kepala kolom nilai standar, mis. `Std Value (λ1)`. Null = pakai label
  /// bawaan layar (`Standard`).
  final String? judulNilai;

  /// Kepala yang memayungi seluruh kolom pengulangan, mis.
  /// `Measurement Result`. Null = nggak ada baris kepala gabungan.
  final String? judulPengulangan;

  /// Awalan nomor pengulangan yang TERCETAK di kertas — `X` bikin `X1 X2 X3`.
  /// Null = pakai `Repeat n` seperti alat lain.
  final String? prefiksPengulangan;

  /// Judul kolom nilai per MODE kalibrasi — cuma TITS yang ngirim.
  ///
  /// Alat itu punya dua mode yang kolomnya BERTUKAR sisi: mode `measure` kolom
  /// kirinya setpoint kalibrator (`Standard Indication`) dan kolom pengulangan
  /// bacaan alat pelanggan; mode `source` kebalikannya. Judul yang salah bikin
  /// teknisi ngisi kolom yang keliru, dan angkanya tetap masuk tanpa error.
  ///
  /// Kosong = alat satu judul; [judulNilai] yang dipakai, persis kayak dulu.
  final Map<String, String> judulNilaiPerMode;

  /// Pasangan [judulNilaiPerMode] buat kepala kolom pengulangan.
  final Map<String, String> judulPengulanganPerMode;

  /// Label kepala tiap nomor pengulangan — `{1: "UP X1", 4: "DOWN X1"}`.
  ///
  /// TITS membaca tiap titik naik tiga kali lalu turun tiga kali, dan arah itu
  /// yang tercetak di kertasnya. Datang dari backend, bukan dihitung layar dari
  /// indeks: kalau lab suatu saat baca empat kali per arah, yang berubah cukup
  /// di sana.
  ///
  /// Kosong = kepala kolom pakai `Repeat n` / prefiks seperti alat lain.
  final Map<int, String> pengulanganArah;

  /// Teknisi boleh menambah, menghapus, dan mengubah titik ukurnya.
  ///
  /// Cuma TITS. Sepuluh alat lain titiknya konstanta (pH 4/7/10, gas
  /// 101/25/50/17,9); di TITS rentang alat pelanggan beda-beda dan [baris] yang
  /// datang cuma SARAN.
  final bool titikBisaDiubah;

  /// Judul kolom nilai buat [mode] yang lagi kepilih, jatuh ke [judulNilai]
  /// kalau modenya belum dipilih atau alatnya nggak bermode.
  String? judulNilaiUntuk(String? mode) =>
      (mode == null ? null : judulNilaiPerMode[mode]) ?? judulNilai;

  /// Pasangan [judulNilaiUntuk] buat kepala kolom pengulangan.
  String? judulPengulanganUntuk(String? mode) =>
      (mode == null ? null : judulPengulanganPerMode[mode]) ?? judulPengulangan;

  /// Berapa kolom pengulangan yang digambar PER BARIS.
  ///
  /// Bedanya sama [pengulangan]: yang itu bentuk DATA-nya, yang ini bentuk
  /// KERTASNYA. Blok %T Spectrophotometer punya enam pengulangan, tapi di
  /// lembar cetak digambar **dua baris X1..X3** per nilai standar — dan dua
  /// baris itu yang dilihat teknisi waktu nyalin angka.
  ///
  /// Datang dari backend, bukan dihitung di layar: motong tiap 3 kolom itu
  /// tebakan yang kebetulan bener buat satu alat, dan bakal salah di alat
  /// berikutnya yang polanya beda. Null = satu baris, seperti biasa.
  final int? pengulanganPerBaris;

  /// Kolom kiri yang di kertas KEGABUNG buat seluruh tabel — di blok %T isinya
  /// `λ (nm)` = `560`, panjang gelombang tempat seluruh titik diukur.
  final KolomTetap? kolomTetap;

  /// Catatan yang tercetak di bawah tabel, mis. `*) Measured at 25°C…`.
  /// Ditampilin apa adanya; ini bagian dari dokumen, bukan tulisan layar.
  final String? catatan;

  /// Arah nomor Repeat di lembar CETAK: `kolom` = berjajar ke kanan (bentuk
  /// pH, `SIDIK-FM-CAL-0509`), `baris` = turun ke bawah (bentuk Conductivity,
  /// `SIDIK-FM-CAL-0510`).
  ///
  /// Datang dari backend, bukan disimpulin layar dari nama alat: dua bentuk itu
  /// sama-sama sah, dan yang tahu bentuk kertasnya cuma profil alatnya.
  /// Bawaannya `kolom` supaya empat alat yang sudah jalan nggak berubah.
  final String sumbuPengulangan;

  /// Kepala kolom "Solution Standard" seperti TERCETAK, dipakai kalau
  /// [pengulanganKeBawah]. Kosong = pakai [baris] seperti biasa.
  final List<SlotCetak> slotCetak;

  bool get pengulanganKeBawah => sumbuPengulangan == 'baris';

  bool get sebelumAdjustment => tahap == 'sebelum_adjustment';

  /// Nomor pengulangan dipotong jadi baris-baris sesuai [pengulanganPerBaris].
  /// Satu baris utuh kalau backend nggak nyebut apa-apa.
  List<List<int>> get pengulanganPerBarisnya {
    final n = pengulanganPerBaris;
    if (n == null || n <= 0 || n >= pengulangan.length) return [pengulangan];

    return [
      for (var i = 0; i < pengulangan.length; i += n)
        pengulangan.sublist(i, (i + n).clamp(0, pengulangan.length)),
    ];
  }

  factory TabelHasil.fromJson(Map<String, dynamic> json) => TabelHasil(
    tahap: json['tahap'] as String,
    judul: json['judul'] as String? ?? '',
    nomorBaris: json['nomor_baris'] as bool? ?? false,
    judulNilai: json['judul_nilai'] as String?,
    judulPengulangan: json['judul_pengulangan'] as String?,
    prefiksPengulangan: json['prefiks_pengulangan'] as String?,
    pengulanganPerBaris: (json['pengulangan_per_baris'] as num?)?.toInt(),
    kolomTetap: json['kolom_tetap'] == null
        ? null
        : KolomTetap.fromJson(json['kolom_tetap'] as Map<String, dynamic>),
    catatan: json['catatan'] as String?,
    sumbuPengulangan: json['sumbu_pengulangan'] as String? ?? 'kolom',
    slotCetak: parseListAman(json['slot_cetak'], SlotCetak.fromJson),
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
    judulNilaiPerMode: _petaTeks(json['judul_nilai_per_mode']),
    judulPengulanganPerMode: _petaTeks(json['judul_pengulangan_per_mode']),
    pengulanganArah: _arahPengulangan(json['pengulangan_arah']),
    titikBisaDiubah: json['titik_bisa_diubah'] as bool? ?? false,
  );
}

/// Peta `{mode: judul}` yang tahan isi aneh.
///
/// Nilai yang bukan teks DIBUANG, bukan bikin seluruh lembar gagal: kunci ini
/// baru dipakai satu alat, dan lembar yang kebuka dengan satu judul salah jauh
/// lebih baik daripada layar kalibrasi yang kosong.
Map<String, String> _petaTeks(dynamic nilai) {
  if (nilai is! Map) return const {};

  return {
    for (final e in nilai.entries)
      if (e.key is String && e.value is String) e.key as String: e.value as String,
  };
}

/// `pengulangan_arah` → `{nomor: label}`.
///
/// Baris tanpa `ke` atau tanpa `label` dilewat. Label kosong juga dilewat —
/// kepala kolom kosong lebih membingungkan daripada `Repeat n` bawaan.
Map<int, String> _arahPengulangan(dynamic nilai) {
  if (nilai is! List) return const {};

  final hasil = <int, String>{};

  for (final baris in nilai) {
    if (baris is! Map) continue;

    final ke = baris['ke'];
    final label = baris['label'];

    if (ke is num && label is String && label.trim().isNotEmpty) {
      hasil[ke.toInt()] = label.trim();
    }
  }

  return hasil;
}

/// Satu kepala kolom "Solution Standard" seperti TERCETAK di lembar kerja.
///
/// Ada karena tulisan di kertas nggak sama dengan titik yang dihitung. Formulir
/// Conductivity `Rev.5` (Des 2023) masih menulis nominal botol lama —
/// `84 / 1413 / 5000 / 80000` — sementara master pindah ke tiga titik
/// (`25 / 1412 / 111`) pada April 2024. Layar mencetak [label] supaya cocok
/// sama kertas di tangan teknisi, dan [titikUkur] yang nentuin angkanya masuk
/// ke titik yang mana.
class SlotCetak {
  const SlotCetak({
    required this.label,
    required this.titikUkur,
    this.varian,
    this.satuan,
    this.resolusi,
    this.desimal,
  });

  /// Tulisan di kertas, mis. `1413 µS`.
  final String label;

  /// Pasangan satuan yang di kertas punya kotak "ceklis salah satu", mis.
  /// `1.413 mS`. Null = slot ini cuma satu satuan (`84`).
  final String? varian;

  /// Titik yang beneran dihitung buat slot ini. **Kosong = slot mati** —
  /// kotaknya tetap digambar karena ada di kertas, tapi nggak bisa diisi.
  ///
  /// Bisa berisi DUA nilai kalau backend ngirim dua varian satuan buat botol
  /// yang sama (`1412` µS/cm dan `1,412` mS/cm); yang saling mengunci tetap
  /// `eksklusif_dengan` di barisnya.
  final List<double> titikUkur;

  final String? satuan;
  final double? resolusi;
  final int? desimal;

  bool get mati => titikUkur.isEmpty;

  factory SlotCetak.fromJson(Map<String, dynamic> json) => SlotCetak(
    label: json['label'] as String? ?? '',
    varian: json['varian'] as String?,
    titikUkur: (json['titik_ukur'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList(),
    satuan: json['satuan'] as String?,
    resolusi: (json['resolusi'] as num?)?.toDouble(),
    desimal: (json['desimal'] as num?)?.toInt(),
  );
}

/// Satu bagian (section) lembar kerja, mis. "EQUIPMENT IDENTITY AND CUSTOMER
/// DATA". Bagian hasil punya [tabel] bukan [field].
/// Satu baris di tabel matriks Autoklaf.
///
/// Bedanya dari [BarisTabelHasil]: baris di sini bukan "titik ukur" melainkan
/// **besaran tersendiri** (`Temp. Disk 1`, `Indikator Pressure`, `Suhu Ruang`),
/// dan yang berjajar ke kanan bukan pengulangan pembacaan melainkan **titik
/// waktu** selama proses sterilisasi.
///
/// [kodeData] itu yang bikin layar nggak perlu tahu apa-apa soal Autoklaf:
/// jalur bertitik ke tempat angkanya di payload (`suhu.disk.0`,
/// `tekanan.indikator_pressure`), ditentukan backend. Sebelum ini pemetaan
/// baris → payload ditulis ulang di layar, dan urutan barisnya jadi memikul
/// arti — satu baris kegeser berarti bacaan manometer masuk ke kolom suhu, dan
/// angka itu jalan terus sampai sertifikat.
class BarisMatriks {
  const BarisMatriks({
    required this.kode,
    required this.label,
    required this.kodeData,
    this.tipe,
    this.satuan,
    this.satuanDari,
    this.kurungSatuan = false,
    this.format,
  });

  final String kode;
  final String label;

  /// Jalur bertitik ke tempat nilainya di payload, mis. `suhu.disk.0`.
  final String kodeData;

  final String? tipe;
  final String? satuan;

  /// Satuannya nggak tetap — ikut kolom lain di lembar yang sama
  /// (`satuan_tekanan`). Baris tekanan begini: angkanya sama, artinya beda
  /// tergantung Bar/Psi/kPa yang dipilih teknisi.
  final String? satuanDari;

  final bool kurungSatuan;

  /// Format isian buat baris bertipe `jam`, mis. `HH:mm:ss`.
  final String? format;

  bool get jam => tipe == 'jam';

  factory BarisMatriks.fromJson(Map<String, dynamic> json) => BarisMatriks(
    kode: json['kode'] as String? ?? '',
    label: json['label'] as String? ?? '',
    kodeData: json['kode_data'] as String? ?? '',
    tipe: json['tipe'] as String?,
    satuan: json['satuan'] as String?,
    satuanDari: json['satuan_dari'] as String?,
    kurungSatuan: json['kurung_satuan'] as bool? ?? false,
    format: json['format'] as String?,
  );
}

/// Tabel tambahan yang isinya SATU baris berulang, di luar matriks utama.
///
/// Autoklaf: `Pressure Disk Logger — hasil unduh`. Nggak ada di kertas —
/// angkanya diunduh dari alat, bukan ditulis teknisi — tapi tanpa baris ini
/// olah data tekanannya nggak jalan sama sekali.
class TabelSatuBaris {
  const TabelSatuBaris({
    required this.label,
    required this.kodeData,
    required this.pengulangan,
    this.satuan,
    this.diLuarKertas = false,
    this.catatan,
  });

  final String label;
  final String kodeData;
  final List<int> pengulangan;
  final String? satuan;
  final bool diLuarKertas;
  final String? catatan;

  static TabelSatuBaris? fromJson(Map<String, dynamic> json) {
    final kolom = json['kolom'];
    if (kolom is! Map<String, dynamic>) return null;

    final kode = kolom['kode'] as String?;
    if (kode == null || kode.isEmpty) return null;

    return TabelSatuBaris(
      label: json['label'] as String? ?? kolom['label'] as String? ?? '',
      kodeData: kode,
      satuan: kolom['satuan'] as String?,
      diLuarKertas: json['di_luar_kertas'] as bool? ?? false,
      catatan: json['catatan'] as String?,
      pengulangan: [
        for (final n in (json['pengulangan'] as List<dynamic>? ?? []))
          if (n is num) n.toInt(),
      ],
    );
  }
}

/// Tabel matriks: satu baris = satu besaran, satu kolom = satu titik waktu.
///
/// Dipakai Autoklaf, dan sengaja dibaca sebagai BENTUK UMUM — bukan dicocokin
/// ke kode profil `autoclave`. Alat berikutnya yang satu sesinya mengukur dua
/// besaran sekaligus dapat layar yang sama tanpa nambah cabang di sini.
class MatriksHasil {
  const MatriksHasil({
    required this.judulKolom,
    required this.titikWaktu,
    required this.baris,
    this.barisWaktu,
  });

  final String judulKolom;
  final List<int> titikWaktu;

  /// Baris `Time` di paling atas — jam pengambilan tiap kolom. Nggak ikut
  /// dihitung, tapi tanpa jamnya lima kolom angka nggak bisa diadu balik ke
  /// rekaman disk.
  final BarisMatriks? barisWaktu;

  final List<BarisMatriks> baris;

  /// Semua baris yang punya kotak isian, `Time` duluan persis kayak kertasnya.
  List<BarisMatriks> get semuaBaris => [?barisWaktu, ...baris];

  static MatriksHasil? fromJson(Map<String, dynamic> json) {
    final baris = parseListAman(json['baris'], BarisMatriks.fromJson);
    if (baris.isEmpty) return null;

    final waktu = json['baris_waktu'];

    return MatriksHasil(
      judulKolom: json['judul_kolom'] as String? ?? '',
      titikWaktu: [
        for (final n in (json['titik_waktu'] as List<dynamic>? ?? []))
          if (n is num) n.toInt(),
      ],
      barisWaktu: waktu is Map<String, dynamic>
          ? BarisMatriks.fromJson(waktu)
          : null,
      baris: baris,
    );
  }
}

class BagianLembarKerja {
  const BagianLembarKerja({
    required this.kode,
    required this.judul,
    required this.halaman,
    required this.field,
    required this.tabel,
    required this.baris,
    this.matriks,
    this.tabelTambahan,
    this.fieldDiLuarKertas = const [],
    this.sumber,
    this.status,
    this.catatan,
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

  /// Tabel matriks (besaran × titik waktu). Null di bagian yang tabelnya
  /// bentuk biasa — sembilan alat lain nggak punya ini.
  final MatriksHasil? matriks;

  /// Tabel satu-baris di luar matriks (`Pressure Disk Logger`).
  final TabelSatuBaris? tabelTambahan;

  /// Kolom yang **nggak ada di kertas** tapi dibutuhkan olah datanya.
  /// Digambar terpisah dengan penanda, biar teknisi nggak nyariin di lembar.
  final List<FieldLembarKerja> fieldDiLuarKertas;

  /// Mis. `master_standar` — daftarnya diambil dari master data lab, bukan
  /// dipatok di formulirnya. Null di bagian yang barisnya udah tercetak.
  final String? sumber;

  /// Bagian yang **ada di lembar kertas tapi belum bisa diisi**, mis.
  /// `sumber_belum_ada`.
  ///
  /// SRE (Stray Radiant Energy) di Spectrophotometer yang pertama: di master
  /// Excel nilai standarnya `#REF!` dan budget-nya `#DIV/0!`, jadi backend
  /// nolak nyetak angka SRE sampai lab nyediakan lembar sumber yang sah.
  ///
  /// Dibaca sebagai KUNCI UMUM, bukan dicocokin ke [kode] `sre`: bagian mana
  /// pun yang datang berstatus begini diperlakukan sama, sekarang dan buat alat
  /// berikutnya.
  final String? status;

  /// Alasan yang ditulis backend buat [status] — ditampilin apa adanya.
  /// Teknisi nyariin blok ini karena ada di lembar kertasnya; nyembunyiin
  /// diam-diam bikin dia ngira layarnya yang rusak.
  final String? catatan;

  /// Bagian ini cuma buat dibaca — nggak nerima input sama sekali.
  bool get belumBisaDiisi => status == 'sumber_belum_ada';

  factory BagianLembarKerja.fromJson(Map<String, dynamic> json) =>
      BagianLembarKerja(
        kode: json['kode'] as String,
        judul: json['judul'] as String? ?? '',
        status: json['status'] as String?,
        catatan: json['catatan'] as String?,
        // Default 1: lembar kerja versi backend lama nggak ngirim `halaman`,
        // dan satu halaman penuh lebih baik daripada layar kosong.
        halaman: (json['halaman'] as num?)?.toInt() ?? 1,
        sumber: json['sumber'] as String?,
        field: parseListAman(json['field'], FieldLembarKerja.fromJson),
        tabel: parseListAman(json['tabel'], TabelHasil.fromJson),
        baris: parseListAman(json['baris'], BarisStandar.fromJson),
        matriks: json['matriks'] is Map<String, dynamic>
            ? MatriksHasil.fromJson(json['matriks'] as Map<String, dynamic>)
            : null,
        tabelTambahan: json['tabel_tekanan'] is Map<String, dynamic>
            ? TabelSatuBaris.fromJson(
                json['tabel_tekanan'] as Map<String, dynamic>,
              )
            : null,
        fieldDiLuarKertas: parseListAman(
          json['field_di_luar_kertas'],
          FieldLembarKerja.fromJson,
        ),
      );
}

/// `satuan_campuran` datang dalam DUA bentuk, dan dua-duanya sah.
///
/// Conductivity ngirim `true`. Spectrophotometer ngirim daftar satuan yang
/// dipakai (`["nm", "%T"]`) — kunci yang sama, tipe yang beda.
///
/// Waktu ini masih `json['satuan_campuran'] as bool?`, daftar itu ngelempar
/// `TypeError`, dan yang gagal bukan satu kolom melainkan **seluruh lembar**:
/// `LembarKerja.fromJson` di luar jangkauan [parseListAman], jadi layar
/// kalibrasinya kosong sebelum satu baris pun sempat digambar.
///
/// Daftar KOSONG dianggap `false`: itu bacanya "nggak ada satuan campur",
/// bukan "campur tapi nggak ada satuannya".
bool _campuran(dynamic nilai) => switch (nilai) {
  final bool b => b,
  final List<dynamic> l => l.isNotEmpty,
  _ => false,
};

/// Bentuk GRID termokopel — satu set point diisi BANYAK sensor sekaligus,
/// bukan satu deret pembacaan.
///
/// Dipakai Enclosure (Oven/Furnace/Bath/Inkubator/Refrigerator), dan sengaja
/// dibaca sebagai BENTUK UMUM — bukan dicocokin ke kode profil `oven` dkk.
/// Alat berikutnya yang satu set point-nya menaruh banyak sensor di banyak
/// posisi dapat layar yang sama tanpa nambah cabang di sini.
///
/// Bedanya dari [MatriksHasil] bukan cuma jumlah baris. Di matriks, tiap baris
/// itu BESARAN yang berbeda (`Temp. Disk 1`, `Indikator Pressure`) dan
/// barisnya dipatok backend. Di sini tiap baris itu SENSOR YANG SAMA JENISNYA
/// di posisi berbeda, jumlahnya ikut berapa termokopel yang benar-benar
/// dipasang teknisi — jadi barisnya bisa ditambah & dikurangi di layar.
class GridSensorBentuk {
  const GridSensorBentuk({
    required this.jumlahSensorSaran,
    required this.pengulangan,
    required this.butuhChannelUntuk,
    required this.barisIndikator,
    required this.barisSuhuRuang,
    required this.catatanSensorAcuan,
  });

  /// Berapa termokopel yang BIASANYA dipasang (master: 9). Cuma saran jumlah
  /// baris awal — bukan batas. Chamber kecil boleh kurang, dan backend
  /// menerima sampai 40 per set point.
  final int jumlahSensorSaran;

  /// Nomor kolom pembacaan yang tercetak, mis. `[1, 2, 3, 4, 5]`.
  ///
  /// Lima kolom tetap digambar walau backend cuma butuh 4 (master membuang
  /// pembacaan ke-5), supaya layar sama persis dengan kertas yang lagi dipegang
  /// teknisi.
  final List<int> pengulangan;

  /// Merk kalibrator yang koreksinya dibaca PER KANAL — kolom Channel cuma
  /// digambar buat merk ini. Kosong = nggak ada yang butuh kanal.
  ///
  /// Datang sebagai string tunggal (`"recorder"`) dari backend; disimpan
  /// sebagai himpunan supaya merk kedua nanti nggak perlu ganti tipe.
  final Set<String> butuhChannelUntuk;

  final bool barisIndikator;

  /// Baris Suhu Ruang DIGAMBAR tapi **nggak ikut dikirim**.
  ///
  /// Backend belum punya tempat menampungnya (validasi request cuma mengenal
  /// `sensor_grid` & `indikator`), jadi kalau diikutkan angkanya hilang tanpa
  /// satu pun pesan. Barisnya tetap ada di layar karena ada di kertas dan
  /// teknisi memang menulisnya di lapangan — hilang dari layar berarti
  /// teknisi ragu apakah dia salah lembar. Lihat `pertanyaan-lab-suhu.md` C-9.
  final bool barisSuhuRuang;

  /// Kalimat aturan Sensor Acuan apa adanya dari backend.
  ///
  /// Sengaja NGGAK ditulis ulang di sini: aturannya pernah berubah (dulu
  /// "sensor pertama", sekarang "nomor terkecil"), dan layar yang menyimpan
  /// salinannya sendiri bakal terus menampilkan aturan lama sesudah backend
  /// dibetulkan.
  final String catatanSensorAcuan;

  /// Kalibrator [merk] butuh nomor Channel per termokopel?
  bool butuhChannel(String? merk) {
    if (merk == null || merk.trim().isEmpty) return false;
    final m = merk.toLowerCase();
    return butuhChannelUntuk.any((k) => m.contains(k));
  }

  static GridSensorBentuk? fromJson(Map<String, dynamic> json) {
    final ulang = [
      for (final n in (json['pengulangan'] as List<dynamic>? ?? const []))
        if (n is num) n.toInt(),
    ];
    if (ulang.isEmpty) return null;

    // `butuh_channel_untuk` dikirim string tunggal sekarang, tapi daftar juga
    // diterima — supaya nambah merk berkanal kedua nggak perlu rilis mobile.
    final channel = switch (json['butuh_channel_untuk']) {
      final String s when s.trim().isNotEmpty => {s.trim().toLowerCase()},
      final List<dynamic> l => {
        for (final e in l)
          if (e is String && e.trim().isNotEmpty) e.trim().toLowerCase(),
      },
      _ => <String>{},
    };

    return GridSensorBentuk(
      jumlahSensorSaran:
          (json['jumlah_sensor_saran'] as num?)?.toInt() ?? ulang.length,
      pengulangan: ulang,
      butuhChannelUntuk: channel,
      barisIndikator: json['baris_indikator'] as bool? ?? true,
      barisSuhuRuang: json['baris_suhu_ruang'] as bool? ?? false,
      catatanSensorAcuan: json['catatan_sensor_acuan'] as String? ?? '',
    );
  }
}

/// Formulir lembar kerja utuh.
class LembarKerja {
  const LembarKerja({
    required this.kodeDokumen,
    this.kodeMetode,
    required this.judul,
    required this.untuk,
    required this.jumlahPengulangan,
    required this.larutanStandar,
    required this.satuan,
    this.satuanCampuran = false,
    this.suhuWajib = false,
    required this.satuanSuhu,
    required this.semuaKolomOpsional,
    required this.catatanPengisian,
    required this.bagian,
    this.gridSensor,
  });

  final String kodeDokumen;

  /// Nomor instruksi kerja yang TERCETAK di lembar ("2. Calibration Methode :
  /// SIDIK-IK-CAL-0507"), buat ditampilkan apa adanya.
  ///
  /// Beda dari [kodeDokumen], yang nomor FORMULIR-nya (`SIDIK-FM-CAL-…`). Dua
  /// nomor ini pernah ketuker di profil Conductivity — makanya dipisah, dan
  /// `null` di alat yang backend-nya belum ngirim.
  final String? kodeMetode;

  final String judul;

  /// `teknisi` atau `admin` — backend yang mutusin dari role token.
  final String untuk;

  final int jumlahPengulangan;
  final List<double> larutanStandar;
  final String satuan;

  /// Lembar ini memakai **lebih dari satu satuan**, jadi [satuan] di level
  /// lembar nggak mewakili dan yang berlaku ada di tiap baris.
  ///
  /// Conductivity yang pertama: 25 & 1412 dibaca µS/cm, 111 dibaca mS/cm.
  /// Backend ngirim `satuan: null` + `satuan_campuran: true` supaya layar nggak
  /// diam-diam melabeli semua kolom dengan satu satuan.
  ///
  /// Spectrophotometer ngirim kunci yang sama dalam bentuk **daftar satuan**
  /// (`["nm", "%T"]`) plus `satuan` level lembar yang keisi satuan blok
  /// pertama. Lihat [_campuran] buat kenapa dua bentuk itu dua-duanya harus
  /// kebaca.
  final bool satuanCampuran;

  /// Suhu larutan WAJIB diisi buat tiap baris yang pembacaannya diisi.
  ///
  /// Dikirim backend, bukan disimpulin layar dari nama alat: keempat alat
  /// sama-sama punya kolom `suhu`, yang beda cuma apakah suhunya masuk
  /// hitungan. Conductivity nilai acuannya digeser ikut suhu; Turbidimeter &
  /// Chlorine dibaca nominal.
  final bool suhuWajib;

  final String satuanSuhu;

  /// Selalu true dari backend. Dipakai layar buat mastiin tombol kirim nggak
  /// pernah dikunci — bukan buat dibalik jadi validasi.
  final bool semuaKolomOpsional;

  final String catatanPengisian;
  final List<BagianLembarKerja> bagian;

  /// Bentuk GRID termokopel, kalau lembar ini memakainya. Null buat sepuluh
  /// alat lain yang satu titiknya cuma satu deret pembacaan.
  final GridSensorBentuk? gridSensor;

  /// Lembar ini diisi sebagai grid sensor, bukan tabel titik datar.
  ///
  /// Dibaca dari ADA-nya `grid_sensor` di respons — bukan dari nama atau kode
  /// alat. Backend yang tahu alat mana berbentuk grid; layar cuma menggambar
  /// apa yang dikirim.
  bool get pakaiGrid => gridSensor != null;

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

  /// Satuan yang berlaku buat [baris].
  ///
  /// Lembar bersatuan campur ([satuanCampuran]) ngambil dari barisnya; sisanya
  /// pakai [satuan] lembar seperti biasa. Satu pintu supaya nggak ada layar
  /// yang lupa dan melabeli 111 mS/cm sebagai µS/cm.
  String satuanUntuk(BarisTabelHasil baris) =>
      satuanCampuran ? (baris.satuan ?? satuan) : satuan;

  /// Bagian di satu halaman, urutannya ngikut backend.
  List<BagianLembarKerja> bagianDiHalaman(int nomor) =>
      bagian.where((b) => b.halaman == nomor).toList();

  /// [b] itu bagian PERTAMA lembar ini?
  ///
  /// Dipakai buat memilih satu bagian yang menggambar GRID sensor — gridnya
  /// milik lembar, bukan milik bagian, jadi tanpa penanda begini dia kegambar
  /// sekali per bagian. Dibandingkan lewat `kode` (bukan `identical`) karena
  /// dua tata letak halaman membangun daftar bagiannya masing-masing.
  bool bagianPertama(BagianLembarKerja b) =>
      bagian.isNotEmpty && bagian.first.kode == b.kode;

  factory LembarKerja.fromJson(Map<String, dynamic> json) => LembarKerja(
    kodeDokumen: json['kode_dokumen'] as String? ?? '',
    kodeMetode: json['kode_metode'] as String?,
    judul: json['judul'] as String? ?? '',
    untuk: json['untuk'] as String? ?? 'teknisi',
    jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 5,
    larutanStandar: (json['larutan_standar'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList(),
    satuan: json['satuan'] as String? ?? '',
    satuanCampuran: _campuran(json['satuan_campuran']),
    suhuWajib: json['suhu_wajib'] as bool? ?? false,
    satuanSuhu: json['satuan_suhu'] as String? ?? '°C',
    semuaKolomOpsional: json['semua_kolom_opsional'] as bool? ?? true,
    catatanPengisian: json['catatan_pengisian'] as String? ?? '',
    bagian: parseListAman(json['bagian'], BagianLembarKerja.fromJson),
    gridSensor: json['grid_sensor'] is Map<String, dynamic>
        ? GridSensorBentuk.fromJson(json['grid_sensor'] as Map<String, dynamic>)
        : null,
  );
}

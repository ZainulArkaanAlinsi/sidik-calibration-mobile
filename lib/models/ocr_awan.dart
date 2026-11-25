import '../services/auth_service.dart' show ApiException;

/// OCR awan atas POTONGAN SEL angka. Dua jalur server berbagi bentuk jawaban ini:
/// `POST /worksheet-scans/{id}/ocr-awan` (§22A, server memotong dari hasil pindai
/// yang tersimpan) dan `POST /ocr/sel-awan` (§22B, HP mengunggah potongannya;
/// jalur yang dipakai aplikasi Lab). Kontrak: `docs/kontrak-api.md` di repo API.
///
/// Tiga hal yang dijaga di berkas ini, dan ketiganya tidak menghasilkan error
/// bila dilanggar:
///
///  1. **Hasilnya USULAN.** Tidak ada status hijau untuk tulisan tangan. Status
///     tertinggi yang dikenal klien adalah [StatusSelAwan.kuning]; bila server
///     suatu hari mengirim `hijau`, klien menurunkannya ke kuning, bukan
///     menampilkannya hijau.
///  2. **Dua bentuk ditampilkan berdampingan.** `teks_awan` (apa adanya dari
///     Google) dan `teks_normal` (bentuk angka murni) tidak boleh saling
///     menggantikan diam-diam. Lihat [SelOcrAwan.bentukBeda].
///  3. **Sel identitas tidak pernah diminta.** Server memang menyaringnya,
///     tetapi klien juga menolak mengirim kuncinya ([periksaKunciOcrAwan]).

/// Batas kunci per permintaan (`ocr.awan_sel.maks_sel_per_permintaan` di server).
/// Satu permintaan boleh memuat banyak sel; jangan memanggil per sel.
const maksKunciOcrAwan = 48;

/// Status satu sel hasil OCR awan. Hanya tiga, dan TIDAK ADA hijau:
/// tulisan tangan tidak pernah hijau.
enum StatusSelAwan {
  /// Ada bacaan angka yang lolos normalisasi, tetap wajib dikonfirmasi manusia.
  kuning,

  /// Tidak lolos normalisasi, keyakinan rendah/tidak ada, atau Google gagal
  /// untuk sel itu. Tidak mengisi apa pun.
  merah,

  /// Google tidak melihat tulisan. Sel kosong tetap kosong.
  kosong;

  /// `hijau` (tidak pernah dikirim server) diturunkan ke [kuning]; nilai yang
  /// tidak dikenal jatuh ke [merah] (tidak dipakai sebagai usulan).
  static StatusSelAwan dariServer(Object? nilai) => switch (nilai) {
    'kuning' || 'hijau' => StatusSelAwan.kuning,
    'kosong' => StatusSelAwan.kosong,
    _ => StatusSelAwan.merah,
  };
}

/// Satu sel di `hasil[]`.
class SelOcrAwan {
  const SelOcrAwan({
    required this.kunci,
    required this.status,
    this.teksAwan,
    this.keyakinan,
    this.teksNormal,
    this.nilaiAwan,
    this.dinormalkan = false,
    this.alasan = const [],
  });

  /// Kunci sel apa adanya dari server (`tabel|baris|repeat|field`). Klien tidak
  /// pernah menyusun atau mengubahnya.
  final String kunci;

  /// Teks dari Google APA ADANYA. `null` = Google gagal untuk sel ini;
  /// `""` = Google tidak melihat tulisan.
  final String? teksAwan;

  final double? keyakinan;
  final StatusSelAwan status;

  /// Bentuk angka murni (koma desimal) bila `teks_awan` lolos normalisasi;
  /// selain itu `null`.
  final String? teksNormal;
  final double? nilaiAwan;

  /// Server menyatakan bentuk `teks_normal` BEDA dari `teks_awan`.
  final bool dinormalkan;

  /// Kode alasan dari server, mis. kenapa sel merah. Tampilan: terjemahkan di
  /// lapisan layar, jangan dibaca sebagai kalimat.
  final List<String> alasan;

  /// Ada bentuk angka yang boleh DITAWARKAN ke teknisi sebagai usulan.
  ///
  /// Hanya kuning dengan `teks_normal` terisi. Merah, kosong, dan `teks_normal`
  /// null tidak pernah menjadi usulan. Ini bukan izin mengisi sel: pemakaian
  /// nilai tetap menunggu konfirmasi manusia.
  bool get adaUsulan =>
      status == StatusSelAwan.kuning &&
      teksNormal != null &&
      teksNormal!.trim().isNotEmpty;

  /// Dua bentuk wajib ditampilkan berdampingan: server bilang dinormalkan, atau
  /// teksnya memang beda. Sengaja tidak mempercayai bendera `dinormalkan` saja.
  bool get bentukBeda =>
      teksAwan != null &&
      teksNormal != null &&
      (dinormalkan || teksAwan != teksNormal);

  /// `null` bila entri tidak punya `kunci` — tidak ada sel yang bisa dituju,
  /// jadi entri itu dibuang, bukan ditebak.
  static SelOcrAwan? dariJson(Map<String, dynamic> json) {
    final kunci = json['kunci'];
    if (kunci is! String || kunci.isEmpty) return null;

    return SelOcrAwan(
      kunci: kunci,
      teksAwan: json['teks_awan'] is String ? json['teks_awan'] as String : null,
      keyakinan: json['keyakinan'] is num
          ? (json['keyakinan'] as num).toDouble()
          : null,
      status: StatusSelAwan.dariServer(json['status']),
      teksNormal: json['teks_normal'] is String
          ? json['teks_normal'] as String
          : null,
      nilaiAwan: json['nilai_awan'] is num
          ? (json['nilai_awan'] as num).toDouble()
          : null,
      dinormalkan: json['dinormalkan'] == true,
      alasan: _daftarTeks(json['alasan']),
    );
  }
}

/// Satu sel di `dilewati[]`: server tidak membacanya (bukan sel angka, kosong di
/// HP, melebihi batas, Google gagal, dst.). Sel itu diperlakukan seperti tanpa
/// OCR awan — pembaca di HP atau isi manual.
class SelDilewatiAwan {
  const SelDilewatiAwan({required this.kunci, required this.alasan});

  final String kunci;

  /// Mis. `isian_tidak_dikirim`, `kosong_lokal`, `google_gagal`.
  final String alasan;
}

/// `meta` respons. Hanya bagian yang dipakai klien.
class MetaOcrAwan {
  const MetaOcrAwan({
    this.jumlahDikirim,
    this.jumlahPanggilan,
    this.usulan = true,
    this.sebagian = false,
    this.sisaSelScan,
    this.sisaSelLembar,
    this.dilewatiOtomatis = const {},
  });

  final int? jumlahDikirim;
  final int? jumlahPanggilan;

  /// Selalu `true` dari server; klien memperlakukan semuanya usulan walau
  /// bendera ini hilang.
  final bool usulan;

  /// `true` = sebagian sel terbaca, sisanya tidak sempat (Google gagal di
  /// tengah). Yang tidak terbaca ada di `dilewati` dengan alasan `google_gagal`.
  final bool sebagian;

  /// Sisa jatah sel OCR awan untuk hasil pindai ini (hitungan lunak).
  final int? sisaSelScan;

  /// Sisa hitungan sel lunak per lembar/sesi (§22B, jalur unggah). `null` bila
  /// jawabannya dari §22A atau server tidak menyebutnya.
  final int? sisaSelLembar;

  /// Sel yang server lewati sendiri, mis. `sudah_hijau_lokal`, `kosong_lokal`.
  final Map<String, int> dilewatiOtomatis;

  static MetaOcrAwan dariJson(Map<String, dynamic>? json) {
    if (json == null) return const MetaOcrAwan();

    final otomatis = <String, int>{};
    final mentah = json['dilewati_otomatis'];
    if (mentah is Map) {
      mentah.forEach((k, v) {
        if (v is num) otomatis['$k'] = v.toInt();
      });
    }

    return MetaOcrAwan(
      jumlahDikirim: (json['jumlah_dikirim'] as num?)?.toInt(),
      jumlahPanggilan: (json['jumlah_panggilan'] as num?)?.toInt(),
      sebagian: json['sebagian'] == true,
      sisaSelScan: (json['sisa_sel_scan'] as num?)?.toInt(),
      sisaSelLembar: (json['sisa_sel_lembar'] as num?)?.toInt(),
      dilewatiOtomatis: otomatis,
    );
  }
}

/// Respons `200` dari `ocr-awan`. Semuanya USULAN: server tidak menulis apa pun
/// ke sel hasil pindai.
class HasilOcrAwan {
  const HasilOcrAwan({
    this.hasil = const [],
    this.dilewati = const [],
    this.meta = const MetaOcrAwan(),
  });

  final List<SelOcrAwan> hasil;
  final List<SelDilewatiAwan> dilewati;
  final MetaOcrAwan meta;

  /// Sel hasil menurut kunci. Kunci yang tidak ada di sini tidak punya usulan.
  Map<String, SelOcrAwan> get perKunci => {for (final s in hasil) s.kunci: s};

  /// Sel yang boleh ditawarkan sebagai usulan (lihat [SelOcrAwan.adaUsulan]).
  List<SelOcrAwan> get usulan => [
    for (final s in hasil)
      if (s.adaUsulan) s,
  ];

  factory HasilOcrAwan.fromJson(Map<String, dynamic> json) {
    return HasilOcrAwan(
      hasil: [
        for (final e in _daftarMap(json['hasil']))
          ?SelOcrAwan.dariJson(e),
      ],
      dilewati: [
        for (final e in _daftarMap(json['dilewati']))
          if (e['kunci'] is String && (e['kunci'] as String).isNotEmpty)
            SelDilewatiAwan(
              kunci: e['kunci'] as String,
              alasan: e['alasan'] is String ? e['alasan'] as String : '',
            ),
      ],
      meta: MetaOcrAwan.dariJson(
        json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}

/// Golongan galat OCR awan. Semuanya berakhir sama bagi teknisi: jatuh ke jalur
/// lama (pembaca di HP / isi manual) tanpa crash.
enum JenisGalatOcrAwan {
  /// `503 fitur_dimatikan` — Super Admin mematikan `ocr_cloud_sel` atau
  /// `pindai_lembar`. Ambil ulang `fitur_nonaktif`.
  fiturMati,

  /// `503 ocr_cloud_belum_aktif` / `ocr_cloud_belum_disetel` /
  /// `citra_tidak_bisa_dipotong` — server belum siap. Bawaan produksi.
  awanBelumSiap,

  /// `422 citra_tidak_tersimpan` / `citra_rusak` — citra hasil pindai tidak ada
  /// di server, rusak, atau melebihi 16 juta piksel (mis. 48 MP). Pindai ulang.
  citraBermasalah,

  /// `422 gambar_tidak_terbaca` — Google tidak bisa membaca satu pun potongan.
  tidakTerbaca,

  /// `429 batas_per_lembar` / `gagal_berulang_per_lembar` / `batas_sel_per_scan`.
  jatahHabis,

  /// `429` tanpa `kode` — limiter 4 permintaan per menit per akun.
  terlaluSering,

  /// `502 ocr_cloud_gagal` — Google gagal, waktu habis, atau jaringan putus.
  awanGagal,

  /// `422 permintaan_tidak_valid` / `templat_tidak_dikenal` (§22B) — server tidak
  /// menerima bentuk kiriman atau tidak mengenali templatnya. Bukan salah
  /// teknisi; teknisi cukup melanjutkan manual.
  permintaanDitolak,

  /// `422 tidak_ada_potongan_valid` (§22B) — tidak satu pun potongan boleh
  /// dikirim (semuanya ada di `dilewati[]`).
  tidakAdaPotongan,

  /// `404 sesi_tidak_ditemukan` / `403 bukan_sesi_anda` (§22B).
  sesiBermasalah,

  /// Galat dengan `fallback_manual: true` yang `kode`-nya belum dikenal klien.
  lainnya,
}

/// Galat `ocr-awan` yang harus jatuh ke jalur lama.
///
/// Dibuat dari [ApiException] hanya bila bentuknya cocok kontrak. Galat lain
/// (403/404 kepemilikan, 401, 422 validasi tanpa `kode`, 5xx polos) TIDAK
/// disamarkan jadi ini: 422 tanpa `kode` berarti kiriman klien salah, dan
/// menyuruh teknisi "pindai ulang" untuk bug aplikasi tidak menolong siapa pun.
///
/// **Tidak ada ulang otomatis**, untuk jenis apa pun ([bolehUlangOtomatis]).
class GalatOcrAwan implements Exception {
  const GalatOcrAwan({
    required this.status,
    required this.jenis,
    required this.pesan,
    this.kode,
    this.fallbackManual = true,
  });

  final int status;

  /// `kode` dari server, yang stabil. Cocokkan ini, bukan [pesan].
  final String? kode;
  final JenisGalatOcrAwan jenis;

  /// `message` dari server: kalimat tetap, ditampilkan apa adanya.
  final String pesan;

  /// Jalur lama (pembaca HP / isi manual) tetap terbuka.
  final bool fallbackManual;

  /// Selalu `false`. `429` dan `502` tidak diulang otomatis: tiap panggilan
  /// ulang memakai jatah dan biaya, dan jaringan putus bisa berarti permintaan
  /// pertama sudah sampai.
  bool get bolehUlangOtomatis => false;

  /// Google gagal berulang untuk sesi itu: berhenti memanggil untuk lembar itu.
  bool get berhentiUntukLembar => kode == 'gagal_berulang_per_lembar';

  /// Keadaan fitur berubah di server: ambil ulang `fitur_nonaktif` dari
  /// `GET /me/permissions`.
  bool get perluAmbilUlangFitur => jenis == JenisGalatOcrAwan.fiturMati;

  static const _kodeDikenal = <String, JenisGalatOcrAwan>{
    'fitur_dimatikan': JenisGalatOcrAwan.fiturMati,
    'ocr_cloud_belum_aktif': JenisGalatOcrAwan.awanBelumSiap,
    'ocr_cloud_belum_disetel': JenisGalatOcrAwan.awanBelumSiap,
    'citra_tidak_bisa_dipotong': JenisGalatOcrAwan.awanBelumSiap,
    'citra_tidak_tersimpan': JenisGalatOcrAwan.citraBermasalah,
    'citra_rusak': JenisGalatOcrAwan.citraBermasalah,
    'gambar_tidak_terbaca': JenisGalatOcrAwan.tidakTerbaca,
    'batas_per_lembar': JenisGalatOcrAwan.jatahHabis,
    'gagal_berulang_per_lembar': JenisGalatOcrAwan.jatahHabis,
    'batas_sel_per_scan': JenisGalatOcrAwan.jatahHabis,
    'ocr_cloud_gagal': JenisGalatOcrAwan.awanGagal,
    // §22B (`POST /ocr/sel-awan`).
    'batas_sel_per_lembar': JenisGalatOcrAwan.jatahHabis,
    'terlalu_sering': JenisGalatOcrAwan.terlaluSering,
    'permintaan_tidak_valid': JenisGalatOcrAwan.permintaanDitolak,
    'templat_tidak_dikenal': JenisGalatOcrAwan.permintaanDitolak,
    'tidak_ada_potongan_valid': JenisGalatOcrAwan.tidakAdaPotongan,
    'sesi_tidak_ditemukan': JenisGalatOcrAwan.sesiBermasalah,
    'bukan_sesi_anda': JenisGalatOcrAwan.sesiBermasalah,
  };

  /// [ApiException] dari `ocr-awan` → [GalatOcrAwan], atau `null` bila bukan
  /// galat yang harus jatuh ke jalur lama.
  static GalatOcrAwan? dariRespons(ApiException e) {
    final kode = e.body['kode'];
    final kodeTeks = kode is String && kode.isNotEmpty ? kode : null;
    final fallback = e.body['fallback_manual'];

    JenisGalatOcrAwan? jenis;

    if (kodeTeks != null) {
      jenis = _kodeDikenal[kodeTeks];
    }

    // Limiter 4/menit per akun: `429` tanpa `kode`.
    if (jenis == null && kodeTeks == null && e.status == 429) {
      jenis = JenisGalatOcrAwan.terlaluSering;
    }

    // Kode baru yang belum dikenal, tetapi server menyatakan jalur manual
    // tetap terbuka: jatuh ke jalur lama, bukan crash.
    if (jenis == null && fallback == true) jenis = JenisGalatOcrAwan.lainnya;

    if (jenis == null) return null;

    return GalatOcrAwan(
      status: e.status,
      kode: kodeTeks,
      jenis: jenis,
      pesan: e.message,
      fallbackManual: fallback is bool ? fallback : true,
    );
  }

  @override
  String toString() => 'GalatOcrAwan($status, kode: $kode, ${jenis.name})';
}

/// Periksa dan rapikan daftar kunci sebelum dikirim. Melempar [ArgumentError]
/// (bug pemanggil, bukan galat server) bila:
///
///  - daftar kosong — server akan memilih sendiri sampai [maksKunciOcrAwan]
///    sel, jadi "tidak ada pilihan" tidak boleh berubah diam-diam jadi
///    "baca semuanya". Mau serahkan pilihan ke server: kirim `null`.
///  - ada kunci kosong, atau kunci sel identitas (`isian|…`, `centang|…`):
///    tidak pernah diminta;
///  - lebih dari [maksKunciOcrAwan] kunci unik. Tidak dipecah otomatis:
///    memecah menghabiskan jatah panggilan per sesi dan limiter 4/menit.
///
/// Kunci duplikat dibuang; urutan dan isi kunci tidak diubah.
List<String> periksaKunciOcrAwan(List<String> kunci) {
  if (kunci.isEmpty) {
    throw ArgumentError.value(
      kunci,
      'kunci',
      'Daftar kunci kosong. Kirim null bila memang menyerahkan pilihan ke server.',
    );
  }

  final unik = <String>{};

  for (final k in kunci) {
    if (k.trim().isEmpty) {
      throw ArgumentError.value(k, 'kunci', 'Kunci sel kosong.');
    }
    if (kunciSelIdentitas(k)) {
      throw ArgumentError.value(
        k,
        'kunci',
        'Sel isian/centang tidak pernah diminta ke OCR awan.',
      );
    }
    unik.add(k);
  }

  if (unik.length > maksKunciOcrAwan) {
    throw ArgumentError.value(
      kunci.length,
      'kunci',
      'Maksimal $maksKunciOcrAwan kunci per permintaan.',
    );
  }

  return List.unmodifiable(unik);
}

/// Sel `isian` (kondisi lingkungan/identitas kop) dan `centang` — server juga
/// menolak membacanya (`isian_tidak_dikirim`, `centang_tidak_dikirim`).
bool kunciSelIdentitas(String kunci) =>
    kunci.startsWith('isian|') || kunci.startsWith('centang|');

List<String> _daftarTeks(Object? nilai) => nilai is List
    ? [
        for (final e in nilai)
          if (e is String) e,
      ]
    : const [];

List<Map<String, dynamic>> _daftarMap(Object? nilai) => nilai is List
    ? [
        for (final e in nilai)
          if (e is Map<String, dynamic>) e,
      ]
    : const [];

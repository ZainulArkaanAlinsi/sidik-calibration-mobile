import 'package:flutter/painting.dart' show Color, TextAlign;

import '../widget/grid/grid_sel.dart';

/// Workbook Alat — mode "Asli Excel", BACA-SAJA (S1b, K-49-08).
///
/// Bentuk JSON = kontrak `GET /studio/workbook*` (rencana
/// `_agents_workspace/studio-data-acuan/02-rencana-S1b.md`, repo API).
/// Kunci yang tidak dikirim / bertipe salah dibaca sebagai "tidak diketahui",
/// bukan ditebak.
///
/// Studio TIDAK menghitung apa pun dari sel ini: `n` disimpan apa adanya
/// (`num` hasil `jsonDecode`, tanpa pembulatan) dan `s` adalah teks tampil
/// buatan server.
///
/// Lembar DATABASE/SERTIFIKAT: sejak K-49-12 isinya DIKIRIM dan tampil apa
/// adanya; panel penanda cuma untuk lembar yang `dikecualikan` = `true`.
/// `tautan_tabel` (bila ada) = tabel tempat data yang sama juga dikelola.

int _int(Object? v, [int cadangan = 0]) => switch (v) {
  int n => n,
  num n => n.toInt(),
  String s => int.tryParse(s) ?? cadangan,
  _ => cadangan,
};

String? _teks(Object? v) => v is String && v.isNotEmpty ? v : null;

bool _bool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

DateTime? _waktu(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Bilangan ≥ 1, selain itu `null` (tidak dikirim / bertipe salah).
int? _intPositif(Object? v) {
  final n = _int(v);
  return n >= 1 ? n : null;
}

/// `bool` yang TIDAK dikirim tetap `null` — beda dari `false`.
bool? _boolAtauNull(Object? v) => switch (v) {
  true || 1 || '1' || 'true' => true,
  false || 0 || '0' || 'false' => false,
  _ => null,
};

/// Status master di jenisnya (K-49-13, `status`).
enum StatusWorkbook {
  /// Master aktif jenisnya — yang tampil di daftar.
  aktif,

  /// Versi lama yang sudah digantikan: tersembunyi dari daftar, tetap bisa
  /// dibuka lewat riwayat.
  riwayat,

  /// Tidak dikirim (server sebelum K-49-13) atau nilai yang belum dikenal.
  tidakDiketahui;

  static StatusWorkbook dari(Object? v) => switch (v) {
    'aktif' => aktif,
    'riwayat' => riwayat,
    _ => tidakDiketahui,
  };
}

/// Sumber impor workbook.
enum SumberWorkbook {
  /// Ekspor CSV di repo (`Project-PT-Sidik/alat-alat-Pt-Sidik/`): NILAI
  /// tersimpan saja — tanpa rumus, tanpa tata letak.
  csv,

  /// `.xlsm` master (dibuka pemilik dengan sandi): + rumus + tata letak.
  xlsm,

  /// Nilai yang belum dikenal klien ini (server lebih baru).
  lain;

  static SumberWorkbook dari(Object? v) => switch (v) {
    'csv' => csv,
    'xlsm' => xlsm,
    _ => lain,
  };
}

/// Satu baris `GET /studio/workbook`.
class WorkbookRingkas {
  const WorkbookRingkas({
    required this.id,
    required this.nama,
    required this.sumber,
    required this.sumberMentah,
    required this.sha256,
    required this.ukuran,
    required this.jumlahLembar,
    required this.berkasAsliTersimpan,
    this.kodeProfil,
    this.keluarga,
    this.diimporPada,
    this.kunciJenis,
    this.aktif,
    this.status = StatusWorkbook.tidakDiketahui,
    this.versi,
    this.digantikanOlehId,
    this.jumlahRiwayat = 0,
  });

  final int id;
  final String nama;

  /// `null` = belum dipetakan ke profil kalibrasi (peta workbook yang masih
  /// ditanyakan ke pemilik).
  final String? kodeProfil;
  final String? keluarga;
  final SumberWorkbook sumber;

  /// Nilai `sumber` apa adanya — ditampilkan bila [sumber] = `lain`.
  final String sumberMentah;
  final String sha256;

  /// Byte.
  final int ukuran;
  final int jumlahLembar;
  final bool berkasAsliTersimpan;
  final DateTime? diimporPada;

  // ── Jenis master (K-49-13). Server lama tidak mengirim satu pun kunci ini:
  // semuanya `null`/bawaan dan baris dianggap master biasa (perilaku lama).

  /// `kunci_jenis` — kelompok "satu master aktif" (`{keluarga|profil}:{varian}`).
  /// Tidak diurai klien.
  final String? kunciJenis;

  /// `aktif` apa adanya; `null` = tidak dikirim.
  final bool? aktif;
  final StatusWorkbook status;

  /// `versi` = URUTAN IMPOR di dalam jenis (1 = paling awal) — BUKAN tanda
  /// lebih baru: admin bisa mengaktifkan versi lama, jadi riwayat bisa
  /// bernomor lebih besar dari master aktifnya. Ditampilkan sebagai
  /// "Impor #n"; aktif/lama hanya dari [status]/[digantikanOlehId].
  final int? versi;

  /// Riwayat → id workbook yang menggantikannya.
  final int? digantikanOlehId;

  /// Jumlah versi lama (riwayat, tanpa arsip) di jenis yang sama.
  final int jumlahRiwayat;

  bool get dipetakan => kodeProfil != null;

  /// Versi lama, BUKAN master aktif: baca saja (tanpa edit/simulasi).
  ///
  /// Ditentukan dari `status`; bila status tidak dikirim/tak dikenal, dari
  /// `digantikan_oleh_id` atau `aktif: false`. Tidak pernah dari [versi].
  /// Server lama (tanpa semua kunci itu) = master biasa.
  bool get riwayat => switch (status) {
    StatusWorkbook.riwayat => true,
    StatusWorkbook.aktif => false,
    StatusWorkbook.tidakDiketahui => digantikanOlehId != null || aktif == false,
  };

  factory WorkbookRingkas.fromJson(Map<String, dynamic> j) => WorkbookRingkas(
    id: _int(j['id']),
    nama: _teks(j['nama']) ?? '',
    kodeProfil: _teks(j['kode_profil']),
    keluarga: _teks(j['keluarga']),
    sumber: SumberWorkbook.dari(j['sumber']),
    sumberMentah: '${j['sumber'] ?? ''}',
    sha256: _teks(j['sha256']) ?? '',
    ukuran: _int(j['ukuran']),
    jumlahLembar: _int(j['jumlah_lembar']),
    berkasAsliTersimpan: _bool(j['berkas_asli_tersimpan']),
    diimporPada: _waktu(j['diimpor_pada']),
    kunciJenis: _teks(j['kunci_jenis']),
    aktif: _boolAtauNull(j['aktif']),
    status: StatusWorkbook.dari(j['status']),
    versi: _intPositif(j['versi']),
    digantikanOlehId: _intPositif(j['digantikan_oleh_id']),
    jumlahRiwayat: switch (_int(j['jumlah_riwayat'])) {
      final n when n > 0 => n,
      _ => 0,
    },
  );
}

/// `GET /studio/workbook/{id}/riwayat` (K-49-13): semua versi jenis yang sama
/// (master aktif + riwayat, tanpa arsip). Urutan = urutan server apa adanya
/// (master aktif dulu, lalu riwayat) — TIDAK diurut ulang klien menurut
/// `versi` (urutan impor, bukan kebaruan).
class RiwayatWorkbook {
  const RiwayatWorkbook({required this.versi, this.kunciJenis});

  final List<WorkbookRingkas> versi;
  final String? kunciJenis;

  /// Master aktif jenis ini (biasanya satu; bisa kosong bila diarsipkan).
  List<WorkbookRingkas> get aktif => [
    for (final v in versi)
      if (!v.riwayat) v,
  ];

  /// Versi lama — yang dibuka baca-saja dari layar riwayat.
  List<WorkbookRingkas> get riwayat => [
    for (final v in versi)
      if (v.riwayat) v,
  ];

  /// Baris yang bukan objek dibuang (tidak bisa diletakkan), sisanya dibaca
  /// toleran seperti baris daftar.
  factory RiwayatWorkbook.fromJson(Map<String, dynamic> j) => RiwayatWorkbook(
    versi: [
      if (j['data'] case final List daftar)
        for (final v in daftar)
          if (v is Map) WorkbookRingkas.fromJson(Map<String, dynamic>.from(v)),
    ],
    kunciJenis: _teks(j['kunci_jenis']),
  );
}

/// `GET /studio/workbook/{id}` — meta + daftar lembar.
class WorkbookDetail {
  const WorkbookDetail({required this.meta, required this.lembar});

  final WorkbookRingkas meta;

  /// Urut [LembarWorkbook.urutan] (urutan tab di Excel).
  final List<LembarWorkbook> lembar;

  factory WorkbookDetail.fromJson(Map<String, dynamic> j) {
    final lembar = <LembarWorkbook>[];
    final mentah = j['lembar'];
    if (mentah is List) {
      for (final l in mentah) {
        if (l is Map) {
          lembar.add(LembarWorkbook.fromJson(Map<String, dynamic>.from(l)));
        }
      }
    }
    lembar.sort((a, b) => a.urutan.compareTo(b.urutan));
    return WorkbookDetail(meta: WorkbookRingkas.fromJson(j), lembar: lembar);
  }
}

/// Keadaan tampil lembar di Excel.
enum KetersembunyianLembar {
  tidak,

  /// Disembunyikan biasa (Format → Hide).
  hidden,

  /// `veryHidden` — cuma bisa dibuka lewat VBA.
  veryHidden;

  /// Bentuk lama: teks `tidak`/`hidden`/`veryHidden`. Kontrak Tahap C:
  /// `bool` (`true` = disembunyikan, jenisnya tidak disebut → [hidden]).
  /// Tak dikenal = [tidak] (tampil) — lembar tidak hilang diam-diam.
  static KetersembunyianLembar dari(Object? v) => switch (v) {
    'hidden' || true || 1 || '1' || 'true' => hidden,
    'veryHidden' => veryHidden,
    _ => tidak,
  };

  bool get disembunyikan => this != tidak;
}

/// Jenis berkas gambar lembar (`gambar[].jenis`).
enum JenisGambar {
  png,
  jpeg,

  /// EMF/WMF/… — Studio tidak menggambarnya (kotak abu berlabel).
  lain;

  static JenisGambar dari(Object? v) =>
      switch (v is String ? v.toLowerCase() : null) {
        'png' => png,
        'jpeg' || 'jpg' => jpeg,
        _ => lain,
      };

  bool get bisaDigambar => this != lain;
}

/// Satu gambar di lembar (`gambar[]`, kontrak Tahap C): jangkar kiri-atas
/// pada sel ([kolom], [baris]) + geser [dx]/[dy] px, ukuran [lebar] ×
/// [tinggi] px — semuanya px Excel pada zoom 100 % (= dp grid).
class GambarLembar {
  const GambarLembar({
    required this.id,
    required this.kolom,
    required this.baris,
    required this.lebar,
    required this.tinggi,
    required this.jenis,
    required this.jenisMentah,
    this.dx = 0,
    this.dy = 0,
  });

  /// Id untuk `GET /studio/workbook/{id}/gambar/{id}`.
  final String id;
  final int kolom;
  final int baris;
  final double dx;
  final double dy;
  final double lebar;
  final double tinggi;
  final JenisGambar jenis;

  /// `jenis` apa adanya (label kotak abu untuk jenis yang tidak digambar).
  final String jenisMentah;

  /// `null` bila entri tidak bisa diletakkan (tanpa id/jangkar/ukuran) —
  /// dibuang, bukan ditebak.
  static GambarLembar? fromJson(Object? mentah) {
    if (mentah is! Map) return null;
    final j = Map<String, dynamic>.from(mentah);
    final id = j['id'];
    final dari = j['dari'];
    if (id == null || '$id'.isEmpty || dari is! Map) return null;
    final k = dari['kolom'];
    final kolom = k is num ? k.toInt() : (k is String ? indeksKolom(k) : null);
    final baris = _int(dari['baris'], -1);
    double angka(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
    final lebar = angka(j['lebar']);
    final tinggi = angka(j['tinggi']);
    if (kolom == null || kolom < 1 || baris < 1 || lebar <= 0 || tinggi <= 0) {
      return null;
    }
    return GambarLembar(
      id: '$id',
      kolom: kolom,
      baris: baris,
      dx: angka(dari['dx']),
      dy: angka(dari['dy']),
      lebar: lebar,
      tinggi: tinggi,
      jenis: JenisGambar.dari(j['jenis']),
      jenisMentah: '${j['jenis'] ?? ''}',
    );
  }
}

class LembarWorkbook {
  const LembarWorkbook({
    required this.id,
    required this.urutan,
    required this.nama,
    required this.tersembunyi,
    required this.dikecualikan,
    required this.jumlahBaris,
    required this.jumlahKolom,
    required this.jumlahSel,
    required this.jumlahRumus,
    required this.tataLetak,
    this.alasanDikecualikan,
    this.tautanTabel,
    this.gambar = const [],
  });

  final int id;
  final int urutan;
  final String nama;

  /// Disembunyikan di Excel: tidak tampil di bilah tab sampai ditampilkan
  /// lewat menu tab ("Tampilkan lembar tersembunyi…", tampilan saja).
  final KetersembunyianLembar tersembunyi;

  /// Gambar di atas grid (kontrak Tahap C). Server lama = kosong.
  final List<GambarLembar> gambar;

  /// Isinya TIDAK diimpor — Studio menampilkan penanda, bukan grid. Sejak
  /// K-49-12 lembar DATABASE/SERTIFIKAT biasanya tidak lagi dikecualikan.
  final bool dikecualikan;
  final String? alasanDikecualikan;

  /// Tabel tempat datanya JUGA dikelola (`customers` / `certificates`).
  final String? tautanTabel;
  final int jumlahBaris;
  final int jumlahKolom;
  final int jumlahSel;
  final int jumlahRumus;
  final TataLetakLembar tataLetak;

  factory LembarWorkbook.fromJson(Map<String, dynamic> j) => LembarWorkbook(
    id: _int(j['id']),
    urutan: _int(j['urutan']),
    nama: _teks(j['nama']) ?? '',
    tersembunyi: KetersembunyianLembar.dari(j['tersembunyi']),
    dikecualikan: _bool(j['dikecualikan']),
    alasanDikecualikan: _teks(j['alasan_dikecualikan']),
    tautanTabel: _teks(j['tautan_tabel']),
    jumlahBaris: _int(j['jumlah_baris']),
    jumlahKolom: _int(j['jumlah_kolom']),
    jumlahSel: _int(j['jumlah_sel']),
    jumlahRumus: _int(j['jumlah_rumus']),
    tataLetak: TataLetakLembar.fromJson(j['tata_letak']),
    gambar: [
      if (j['gambar'] case final List daftar)
        for (final g in daftar) ?GambarLembar.fromJson(g),
    ],
  );
}

/// `tata_letak` lembar dalam SATUAN EXCEL apa adanya (lebar kolom =
/// karakter, tinggi baris = poin). Konversi ke dp di [keGrid] — satu tempat.
///
/// Sumber CSV: lebar/tinggi kosong, kecuali server memperkirakan lebar
/// kolom dari isinya ([lebarPerkiraan]).
class TataLetakLembar {
  const TataLetakLembar({
    this.lebarKolom = const {},
    this.tinggiBaris = const {},
    this.merge = const [],
    this.freeze,
    this.kolomTersembunyi = const {},
    this.barisTersembunyi = const {},
    this.lebarKolomBawaan,
    this.tinggiBarisBawaan,
    this.garisKisi = true,
    this.lebarPerkiraan = false,
  });

  static const kosong = TataLetakLembar();

  /// Kolom (basis-1) → lebar Excel (karakter).
  final Map<int, double> lebarKolom;

  /// Baris (basis-1) → tinggi Excel (poin).
  final Map<int, double> tinggiBaris;
  final List<RentangSel> merge;

  /// Sel kiri-atas panel yang bisa digulir (`B4` = baris 1–3 & kolom A beku).
  final AlamatSel? freeze;
  final Set<int> kolomTersembunyi;
  final Set<int> barisTersembunyi;

  /// `lebar_kolom_bawaan` (karakter Excel, satuan `<col width>`); `null` =
  /// bawaan Excel 8,43 karakter (64 dp).
  final double? lebarKolomBawaan;

  /// `tinggi_baris_bawaan` (poin); `null` = bawaan Excel 15 pt (20 dp).
  final double? tinggiBarisBawaan;

  /// `garis_kisi` — View → Gridlines lembar. Tidak dikirim = tampil.
  final bool garisKisi;

  /// `lebar_perkiraan` — lebar kolom DIPERKIRAKAN server dari isi (CSV tidak
  /// membawa lebar asli). Disebut di kaki supaya tidak disangka lebar Excel.
  final bool lebarPerkiraan;

  factory TataLetakLembar.fromJson(Object? mentah) {
    if (mentah is! Map) return kosong;
    final j = Map<String, dynamic>.from(mentah);

    final lebar = <int, double>{};
    final l = j['lebar_kolom'];
    if (l is Map) {
      l.forEach((kunci, nilai) {
        final k = indeksKolom('$kunci');
        if (k != null && nilai is num) lebar[k] = nilai.toDouble();
      });
    }

    final tinggi = <int, double>{};
    final t = j['tinggi_baris'];
    if (t is Map) {
      t.forEach((kunci, nilai) {
        final b = int.tryParse('$kunci');
        if (b != null && b >= 1 && nilai is num) tinggi[b] = nilai.toDouble();
      });
    }

    final merge = <RentangSel>[];
    final m = j['merge'];
    if (m is List) {
      for (final r in m) {
        final rentang = r is String ? RentangSel.urai(r) : null;
        if (rentang != null && !rentang.tunggal) merge.add(rentang);
      }
    }

    final kolomSembunyi = <int>{};
    final ks = j['kolom_tersembunyi'];
    if (ks is List) {
      for (final h in ks) {
        final k = indeksKolom('$h');
        if (k != null) kolomSembunyi.add(k);
      }
    }

    final barisSembunyi = <int>{};
    final bs = j['baris_tersembunyi'];
    if (bs is List) {
      for (final b in bs) {
        final n = _int(b, -1);
        if (n >= 1) barisSembunyi.add(n);
      }
    }

    double? positif(Object? v) => v is num && v > 0 ? v.toDouble() : null;

    final f = j['freeze'];
    final kisi = j['garis_kisi'];
    return TataLetakLembar(
      lebarKolom: lebar,
      tinggiBaris: tinggi,
      merge: merge,
      freeze: f is String ? AlamatSel.urai(f) : null,
      kolomTersembunyi: kolomSembunyi,
      barisTersembunyi: barisSembunyi,
      lebarKolomBawaan: positif(j['lebar_kolom_bawaan']),
      tinggiBarisBawaan: positif(j['tinggi_baris_bawaan']),
      // Hanya `false` eksplisit yang mematikan kisi; tidak dikirim / nilai
      // lain = tampil (bawaan Excel).
      garisKisi:
          !(kisi == false || kisi == 0 || kisi == '0' || kisi == 'false'),
      lebarPerkiraan: _bool(j['lebar_perkiraan']),
    );
  }

  /// Tata letak grid dalam dp — konversi satuan Excel di grid
  /// ([lebarKolomExcelKeDp], [tinggiBarisExcelKeDp]).
  TataLetakGrid keGrid() => TataLetakGrid(
    lebarKolom: {
      for (final e in lebarKolom.entries) e.key: lebarKolomExcelKeDp(e.value),
    },
    tinggiBaris: {
      for (final e in tinggiBaris.entries) e.key: tinggiBarisExcelKeDp(e.value),
    },
    gabungan: merge,
    barisBeku: freeze == null ? 0 : freeze!.baris - 1,
    kolomBeku: freeze == null ? 0 : freeze!.kolom - 1,
    kolomTersembunyi: kolomTersembunyi,
    barisTersembunyi: barisTersembunyi,
    lebarKolomBawaan: lebarKolomBawaan == null
        ? lebarKolomBawaanDp
        : lebarKolomExcelKeDp(lebarKolomBawaan!),
    tinggiBarisBawaan: tinggiBarisBawaan == null
        ? tinggiBarisBawaanDp
        : tinggiBarisExcelKeDp(tinggiBarisBawaan!),
    garisKisi: garisKisi,
  );
}

/// Tipe sel `t` dari server.
enum TipeSel {
  angka('n'),
  teks('s'),
  logika('b'),
  galat('e'),
  rumus('f'),
  kosong('kosong');

  const TipeSel(this.kode);

  final String kode;

  static TipeSel dari(Object? v) => switch (v) {
    'n' => angka,
    's' => teks,
    'b' => logika,
    'e' => galat,
    'f' => rumus,
    _ => kosong,
  };
}

/// Gaya `g` sel (kontrak FORMAT 3): `tebal`, `miring`, `isi`, `teks`,
/// `rata`, `border` (peta per sisi → gaya garis Excel), `bungkus`,
/// `vertikal`, `ukuran` (pt), `font` (nama). Kunci yang tidak dikirim =
/// bawaan Excel.
class GayaSel {
  const GayaSel({
    this.tebal = false,
    this.miring = false,
    this.isi,
    this.teks,
    this.rata,
    this.garis = GarisSel.tanpa,
    this.bungkus = false,
    this.vertikal,
    this.vertikalMentah,
    this.ukuran,
    this.font,
  });

  final bool tebal;
  final bool miring;
  final Color? isi;
  final Color? teks;

  /// Nilai `rata` apa adanya (`left`, `center`, `right`, `general`, …).
  final String? rata;
  final GarisSel garis;

  /// `bungkus` — "Wrap Text".
  final bool bungkus;

  /// `vertikal` terbaca; `null` = bawah (bawaan Excel) atau tak dikenal.
  final RataVertikal? vertikal;

  /// `vertikal` apa adanya (untuk inspektur).
  final String? vertikalMentah;

  /// `ukuran` font (pt).
  final double? ukuran;

  /// `font` — nama font Excel.
  final String? font;

  bool get kosong =>
      !tebal &&
      !miring &&
      isi == null &&
      teks == null &&
      rata == null &&
      !garis.ada &&
      !bungkus &&
      vertikalMentah == null &&
      ukuran == null &&
      font == null;

  static GayaSel? fromJson(Object? mentah) {
    if (mentah is! Map) return null;
    final j = Map<String, dynamic>.from(mentah);
    final ukuran = j['ukuran'];
    return GayaSel(
      tebal: _bool(j['tebal']),
      miring: _bool(j['miring']),
      isi: warnaHex(j['isi']),
      teks: warnaHex(j['teks']),
      rata: _teks(j['rata']),
      garis: _garis(j['border']),
      bungkus: _bool(j['bungkus']),
      vertikal: rataVertikalExcel(j['vertikal']),
      vertikalMentah: _teks(j['vertikal']),
      ukuran: ukuran is num && ukuran > 0 ? ukuran.toDouble() : null,
      font: _teks(j['font']),
    );
  }

  /// `border`: peta per sisi (`atas/kanan/bawah/kiri` atau
  /// `top/right/bottom/left`) → gaya garis Excel (`thin`, `medium`, …;
  /// lihat [JenisGaris.dari]). `true`/teks tak kosong = keempat sisi tipis
  /// (bentuk lama).
  static GarisSel _garis(Object? v) {
    if (v == null || v == false) return GarisSel.tanpa;
    if (v == true) return GarisSel.semua;
    if (v is String) return v.isEmpty ? GarisSel.tanpa : GarisSel.semua;
    if (v is Map) {
      JenisGaris sisi(String id, String en) => JenisGaris.dari(v[id] ?? v[en]);

      return GarisSel(
        jenisAtas: sisi('atas', 'top'),
        jenisKanan: sisi('kanan', 'right'),
        jenisBawah: sisi('bawah', 'bottom'),
        jenisKiri: sisi('kiri', 'left'),
      );
    }
    return GarisSel.tanpa;
  }
}

/// Perataan vertikal Excel → [RataVertikal]: `top` atas, `center` tengah,
/// `bottom` bawah; `justify`/`distributed` (membagi baris ke tinggi sel)
/// mulai dari atas. Tak dikenal = `null` (bawaan Excel: bawah).
RataVertikal? rataVertikalExcel(Object? v) =>
    switch (v is String ? v.toLowerCase() : null) {
      'top' || 'atas' || 'justify' || 'distributed' => RataVertikal.atas,
      'center' || 'tengah' => RataVertikal.tengah,
      'bottom' || 'bawah' => RataVertikal.bawah,
      _ => null,
    };

/// `#RRGGBB` (atau `#AARRGGBB`) → warna; selain itu `null`.
Color? warnaHex(Object? v) {
  if (v is! String) return null;
  var h = v.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final n = int.tryParse(h, radix: 16);
  return n == null ? null : Color(n);
}

/// Satu sel `GET /studio/workbook/{id}/lembar/{lembar}`.
class SelWorkbook {
  const SelWorkbook({
    required this.alamat,
    required this.tipe,
    required this.tipeMentah,
    required this.teks,
    this.nilai,
    this.rumus,
    this.formatAngka,
    this.gaya,
  });

  /// `b`/`k` (basis-1); `a` hanya dipakai bila `b`/`k` tidak ada.
  final AlamatSel alamat;
  final TipeSel tipe;
  final String tipeMentah;

  /// `n` — NILAI PERSIS dari server, tanpa pembulatan. `null` = bukan angka.
  final num? nilai;

  /// `s` — teks tampil (hasil format angka Excel di server).
  final String teks;

  /// `r` — `=RUMUS` atau `null`.
  final String? rumus;

  /// `f` — format angka Excel (`0.000`, `General`, …).
  final String? formatAngka;
  final GayaSel? gaya;

  /// Melempar [FormatException] bila alamatnya tidak terbaca — sel tanpa
  /// alamat tidak bisa diletakkan, dan diam-diam membuangnya menyembunyikan
  /// data (lihat [HalamanSelWorkbook.jumlahCacat]).
  factory SelWorkbook.fromJson(Map<String, dynamic> j) {
    final b = _int(j['b'], -1);
    final k = _int(j['k'], -1);
    final alamat = (b >= 1 && k >= 1)
        ? AlamatSel(b, k)
        : AlamatSel.urai('${j['a'] ?? ''}');
    if (alamat == null) {
      throw FormatException('Alamat sel tidak terbaca', '${j['a']}');
    }
    final n = j['n'];
    return SelWorkbook(
      alamat: alamat,
      tipe: TipeSel.dari(j['t']),
      tipeMentah: '${j['t'] ?? ''}',
      nilai: n is num ? n : null,
      teks: j['s'] is String
          ? j['s'] as String
          : (n is num ? '$n' : (j['s'] == null ? '' : '${j['s']}')),
      rumus: _teks(j['r']),
      formatAngka: _teks(j['f']),
      gaya: GayaSel.fromJson(j['g']),
    );
  }

  /// Format angka "General" Excel: `f` tidak dikirim (server mengirim
  /// `null` untuk General/tanpa format) atau `General` eksplisit.
  bool get formatGeneral =>
      formatAngka == null || formatAngka!.toLowerCase() == 'general';

  /// Bentuk netral untuk [GridSel].
  ///
  /// [tiruGeneral] — workbook ASLI (`.xlsm`, lebar kolom bukan perkiraan):
  /// angka berformat General ditampilkan grid dari `n` untuk lebar kolomnya
  /// seperti Excel ([SelGrid.general]), bukan dari `s` server.
  ///
  /// Sel CSV (tanpa [tiruGeneral]): `s` dipakai apa adanya bila sudah teks
  /// tulisan Excel saat ekspor; bila `s` angka MENTAH tulisan skrip
  /// ([teksAngkaMentah]: > 15 digit signifikan, `e` kecil, pangkat bukan
  /// `E+NN`), sel General itu juga dibangun dari `n` — tampilan saja.
  SelGrid keGrid({bool tiruGeneral = false}) {
    final g = gaya;
    final jenis = switch (tipe) {
      TipeSel.angka => JenisSelGrid.angka,
      TipeSel.logika => JenisSelGrid.logika,
      TipeSel.galat => JenisSelGrid.galat,
      TipeSel.kosong => JenisSelGrid.kosong,
      TipeSel.teks => JenisSelGrid.teks,
      // Sel berumus: perataannya ikut hasilnya.
      TipeSel.rumus => nilai != null ? JenisSelGrid.angka : JenisSelGrid.teks,
    };
    return SelGrid(
      teks: teks,
      rumus: rumus,
      jenis: jenis,
      tebal: g?.tebal ?? false,
      miring: g?.miring ?? false,
      isi: g?.isi,
      warnaTeks: g?.teks,
      rata: rataExcel(g?.rata),
      vertikal: g?.vertikal,
      bungkus: g?.bungkus ?? false,
      ukuran: g?.ukuran,
      font: g?.font,
      garis: g?.garis ?? GarisSel.tanpa,
      nilai: nilai,
      general:
          formatGeneral &&
          nilai != null &&
          jenis == JenisSelGrid.angka &&
          (tiruGeneral || teksAngkaMentah(teks)),
    );
  }
}

/// Perataan horizontal Excel → [TextAlign]; `general`/tak dikenal = `null`
/// (ikut jenis sel, seperti Excel).
TextAlign? rataExcel(String? rata) => switch (rata?.toLowerCase()) {
  'left' || 'kiri' || 'fill' || 'justify' || 'distributed' => TextAlign.left,
  'center' || 'tengah' || 'centercontinuous' => TextAlign.center,
  'right' || 'kanan' => TextAlign.right,
  _ => null,
};

/// Satu halaman baris sel (`baris_dari..baris_sampai`).
class HalamanSelWorkbook {
  HalamanSelWorkbook({
    required this.barisDari,
    required this.barisSampai,
    required this.jumlahBaris,
    required List<SelWorkbook> sel,
    this.jumlahCacat = 0,
  }) : sel = List.unmodifiable(sel),
       _peta = {
         for (final s in sel) kunciSel(s.alamat.baris, s.alamat.kolom): s,
       };

  final int barisDari;
  final int barisSampai;

  /// Jumlah baris lembar (seluruhnya, bukan halaman ini).
  final int jumlahBaris;
  final List<SelWorkbook> sel;

  /// Sel yang dikirim server tapi tidak terbaca klien. Bukan nol = DITAMPILKAN
  /// ke pengguna — sel hilang diam-diam di layar master lab = data salah.
  final int jumlahCacat;
  final Map<int, SelWorkbook> _peta;
  final _grid = <int, SelGrid>{};
  bool? _gridGeneral;

  /// `null` = sel kosong (server tidak mengirim sel kosong tanpa gaya).
  SelWorkbook? pada(int baris, int kolom) => _peta[kunciSel(baris, kolom)];

  /// Bentuk [GridSel] sel ini, dibuat SEKALI per halaman: grid menanyakan
  /// sel yang sama berkali-kali (sel itu sendiri + tetangganya untuk garis
  /// tepi & teks meluber). Sel tak dikirim = [SelGrid.kosong].
  /// [tiruGeneral] lihat [SelWorkbook.keGrid] (tetap per workbook; cache
  /// dibuang bila berubah).
  SelGrid selGrid(int baris, int kolom, {bool tiruGeneral = false}) {
    if (_gridGeneral != tiruGeneral) {
      _grid.clear();
      _gridGeneral = tiruGeneral;
    }
    final kunci = kunciSel(baris, kolom);
    final ada = _grid[kunci];
    if (ada != null) return ada;
    final s = _peta[kunci];
    if (s == null) return SelGrid.kosong;
    return _grid[kunci] = s.keGrid(tiruGeneral: tiruGeneral);
  }

  factory HalamanSelWorkbook.fromJson(Map<String, dynamic> j) {
    final sel = <SelWorkbook>[];
    var cacat = 0;
    final mentah = j['sel'];
    if (mentah is List) {
      for (final s in mentah) {
        if (s is! Map) {
          cacat++;
          continue;
        }
        try {
          sel.add(SelWorkbook.fromJson(Map<String, dynamic>.from(s)));
        } catch (_) {
          cacat++;
        }
      }
    }
    return HalamanSelWorkbook(
      barisDari: _int(j['baris_dari'], 1),
      barisSampai: _int(j['baris_sampai']),
      jumlahBaris: _int(j['jumlah_baris']),
      sel: sel,
      jumlahCacat: cacat,
    );
  }
}

// ─────────────────────────────────────────────────────────── simulasi (C)

/// Satu edit simulasi untuk `POST /studio/workbook/{id}/hitung`.
///
/// [isi] dikirim APA ADANYA seperti diketik di Excel: `""` = kosongkan,
/// diawali `=` = rumus, selain itu konstanta yang diketik (server yang
/// menentukan angka/logika/teks — Studio tidak menafsirkannya).
typedef EditSel = ({int lembarId, AlamatSel alamat, String isi});

Map<String, Object> editSelKeJson(EditSel e) => {
  'lembar_id': e.lembarId,
  'a': e.alamat.a1,
  'isi': e.isi,
};

/// Galat mesin hitung per sel (`galat[]` jawaban `/hitung`).
typedef GalatHitungSel = ({int lembarId, String a, String pesan});

/// Jawaban 200 `/hitung`. [sel] per lembar = HANYA sel yang nilai/teks
/// tampilnya beda dari snapshot impor + sel yang diedit, bentuknya sama
/// persis dengan sel `GET lembar` — klien menimpanya di atas grid.
class HasilHitung {
  HasilHitung({
    required this.sel,
    required this.galat,
    this.jumlahDihitung = 0,
    this.durasiMs = 0,
    this.jumlahCacat = 0,
  });

  static final kosong = HasilHitung(sel: const {}, galat: const []);

  /// `lembar_id` → sel.
  final Map<int, List<SelWorkbook>> sel;
  final List<GalatHitungSel> galat;
  final int jumlahDihitung;
  final int durasiMs;

  /// Sel jawaban yang tidak terbaca klien — disebut, bukan dibuang diam-diam.
  final int jumlahCacat;

  factory HasilHitung.fromJson(Map<String, dynamic> j) {
    final sel = <int, List<SelWorkbook>>{};
    var cacat = 0;
    if (j['lembar'] case final List daftar) {
      for (final l in daftar) {
        if (l is! Map) continue;
        final id = _int(l['lembar_id'], -1);
        final isi = <SelWorkbook>[];
        if (l['sel'] case final List mentah) {
          for (final s in mentah) {
            try {
              isi.add(
                SelWorkbook.fromJson(Map<String, dynamic>.from(s as Map)),
              );
            } catch (_) {
              cacat++;
            }
          }
        }
        if (id >= 0) (sel[id] ??= []).addAll(isi);
      }
    }
    final galat = <GalatHitungSel>[
      if (j['galat'] case final List daftar)
        for (final g in daftar)
          if (g is Map)
            (
              lembarId: _int(g['lembar_id'], -1),
              a: '${g['a'] ?? ''}',
              pesan: '${g['pesan'] ?? ''}',
            ),
    ];
    return HasilHitung(
      sel: sel,
      galat: galat,
      jumlahDihitung: _int(j['jumlah_dihitung']),
      durasiMs: _int(j['durasi_ms']),
      jumlahCacat: cacat,
    );
  }
}

/// Jawaban `POST /studio/workbook/impor` (K-50-12). Diurai TOLERAN: kontrak
/// final belum membekukan bentuknya, jadi yang dibaca hanya yang berguna
/// untuk satu baris konfirmasi, dan semuanya boleh tidak ada.
class HasilUnggahMaster {
  const HasilUnggahMaster({this.id, this.nama, this.versi, this.pesan});

  final int? id;
  final String? nama;
  final int? versi;
  final String? pesan;

  factory HasilUnggahMaster.fromJson(Map<String, dynamic> j) {
    final d = j['data'] is Map
        ? Map<String, dynamic>.from(j['data'] as Map)
        : j;
    // Beberapa bentuk yang masuk akal: data langsung, atau data.workbook.
    final w = d['workbook'] is Map
        ? Map<String, dynamic>.from(d['workbook'] as Map)
        : d;
    return HasilUnggahMaster(
      id: _intPositif(w['id']),
      nama: _teks(w['nama']),
      versi: _intPositif(w['versi']),
      pesan: _teks(j['message']) ?? _teks(d['message']),
    );
  }
}

/// Sebab `422` unggah master yang dikenali klien. Dipilih dari `kode` dulu,
/// lalu dari teks pesan; selain itu [lain] (pesan server ditampilkan apa
/// adanya).
enum GalatUnggahMaster {
  sandiSalah,
  sandiDiperlukan,
  formatTidakDikenal,
  lain;

  static GalatUnggahMaster dari(Map<String, dynamic> body, String pesan) {
    final kode = '${body['kode'] ?? ''}'.toLowerCase();
    final teks = '$kode ${pesan.toLowerCase()}';
    bool ada(String s) => teks.contains(s);
    final sandi = ada('sandi') || ada('password');
    if (sandi && (ada('salah') || ada('wrong') || ada('invalid'))) {
      return sandiSalah;
    }
    if (sandi && (ada('perlu') || ada('wajib') || ada('required'))) {
      return sandiDiperlukan;
    }
    if (ada('format') || ada('ekstensi') || ada('tidak_didukung')) {
      return formatTidakDikenal;
    }
    return lain;
  }
}

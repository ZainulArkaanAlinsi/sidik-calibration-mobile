import '../core/utils/parse_list.dart';

/// Vonis server per sel hasil pindai.
///
/// **Yang mutusin server, bukan layar.** Aturannya harus sama di semua versi
/// APK — HP yang ngitung sendiri bikin dua teknisi dengan versi beda dapat
/// jawaban beda buat foto yang sama.
enum VonisSel {
  /// Kebaca yakin — boleh keisi otomatis.
  hijau,

  /// Keisi, tapi WAJIB dilihat teknisi. Tulisan tangan nggak pernah naik ke
  /// hijau, jadi hampir semua sel bakal di sini — dan itu bener, bukan bug.
  kuning,

  /// Nggak bisa dipercaya. Dikosongin, teknisi ngetik sendiri.
  merah,

  /// Selnya emang kosong di kertasnya.
  kosong;

  static VonisSel fromApi(String? nilai) => switch (nilai) {
    'hijau' => VonisSel.hijau,
    'merah' => VonisSel.merah,
    'kosong' => VonisSel.kosong,
    _ => VonisSel.kuning,
  };
}

/// Hasil `POST /api/worksheet-scans` (201) atau `GET /api/worksheet-scans/{id}`.
class HasilPindai {
  const HasilPindai({
    required this.scanId,
    required this.status,
    required this.ringkasan,
    required this.tabel,
    required this.bolehAutoIsi,
    required this.wajibDicek,
  });

  final int scanId;
  final String status;
  final RingkasanPindai ringkasan;
  final List<TabelPindai> tabel;

  /// **Dipakai apa adanya**, jangan dihitung ulang dari jumlah sel merah di
  /// HP: aturannya milik server supaya sama di semua versi APK.
  final bool bolehAutoIsi;
  final bool wajibDicek;

  /// Semua sel, diratakan — buat kirim koreksi (yang dikirim WAJIB semuanya,
  /// bukan cuma yang diubah teknisi).
  List<SelPindai> get semuaSel => [
    for (final t in tabel)
      for (final b in t.baris)
        for (final s in b.sel) s,
  ];

  factory HasilPindai.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return HasilPindai(
      scanId: (data['scan_id'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? '',
      ringkasan: RingkasanPindai.fromJson(
        data['ringkasan'] as Map<String, dynamic>? ?? const {},
      ),
      tabel: parseListAman(data['tabel'], TabelPindai.fromJson),
      bolehAutoIsi: data['boleh_auto_isi'] as bool? ?? false,
      wajibDicek: data['wajib_dicek'] as bool? ?? true,
    );
  }
}

class RingkasanPindai {
  const RingkasanPindai({
    required this.totalSel,
    required this.hijau,
    required this.kuning,
    required this.merah,
    required this.kosong,
  });

  final int totalSel;
  final int hijau;
  final int kuning;
  final int merah;
  final int kosong;

  factory RingkasanPindai.fromJson(Map<String, dynamic> json) =>
      RingkasanPindai(
        totalSel: (json['total_sel'] as num?)?.toInt() ?? 0,
        hijau: (json['hijau'] as num?)?.toInt() ?? 0,
        kuning: (json['kuning'] as num?)?.toInt() ?? 0,
        merah: (json['merah'] as num?)?.toInt() ?? 0,
        kosong: (json['kosong'] as num?)?.toInt() ?? 0,
      );
}

class TabelPindai {
  const TabelPindai({
    required this.tabelId,
    required this.tahap,
    required this.judul,
    required this.baris,
    required this.pengulangan,
    this.grup,
  });

  /// `grup ?? tahap` — identitas tabel di kunci sel.
  final String tabelId;

  /// `sebelum_adjustment` / `sesudah_adjustment`. **Ini yang dipakai buat
  /// nuang angkanya balik ke formulir**, bukan [tabelId]: kotak isian di layar
  /// lembar kerja dikunci per tahap, dan Spectrophotometer punya tiga tabel
  /// dengan tahap yang sama tapi `tabel_id` beda-beda.
  final String tahap;

  /// Pembeda tabel yang tahap-nya sama (tiga blok Spectrophotometer). `null` di
  /// alat yang satu tahap = satu tabel.
  final String? grup;

  final String judul;
  final List<BarisPindai> baris;

  /// Urutan Repeat di layar WAJIB ngikut ini, bukan urutan array yang datang.
  final List<int> pengulangan;

  factory TabelPindai.fromJson(Map<String, dynamic> json) => TabelPindai(
    tabelId: json['tabel_id'] as String? ?? '',
    // Respons lama nggak ngirim `tahap` kepisah; jatuh ke `tabel_id` biar
    // alat satu-tahap tetap kepetakan — di situ dua-duanya memang sama.
    tahap: json['tahap'] as String? ?? json['tabel_id'] as String? ?? '',
    grup: json['grup'] as String?,
    judul: json['judul'] as String? ?? '',
    pengulangan: (json['pengulangan'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
    baris: parseListAman(
      json['baris'],
      (b) => BarisPindai.fromJson(b, json['pengulangan']),
    ),
  );
}

class BarisPindai {
  const BarisPindai({
    required this.barisKe,
    required this.label,
    required this.titikUkur,
    required this.sel,
    this.satuan,
  });

  final int barisKe;
  final String label;
  final double titikUkur;
  final String? satuan;

  /// Sel baris ini, urut ngikut `pengulangan` tabelnya.
  final List<SelPindai> sel;

  factory BarisPindai.fromJson(
    Map<String, dynamic> json, [
    dynamic pengulanganTabel,
  ]) {
    final urutan = (pengulanganTabel as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList();

    final perRepeat = <int, Map<String, dynamic>>{
      for (final p in (json['pengulangan'] as List<dynamic>? ?? const []))
        if (p is Map<String, dynamic>)
          ((p['repeat_no'] as num?)?.toInt() ?? 0): p,
    };

    // Urutannya dari `pengulangan` TABEL, bukan dari urutan array yang datang —
    // sama aturannya kayak kunci sel: nggak ada satu pun tahap yang boleh
    // ngandelin urutan array.
    //
    // Respons pindai yang sekarang NGGAK ngirim `pengulangan` di level tabel
    // (`PemrosesScanLembarKerja::susunPerTabel` cuma ngirim tabel_id/tahap/
    // grup/judul/baris), jadi jatuhnya ke nomor Repeat yang diurut naik —
    // deterministik, dan tetap nggak ngandelin urutan array.
    final urut = urutan.isEmpty
        ? (perRepeat.keys.toList()..sort())
        : urutan;

    return BarisPindai(
      barisKe: (json['baris_ke'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      satuan: json['satuan'] as String?,
      sel: [
        for (final nomor in urut)
          for (final e in (perRepeat[nomor]?['kolom']
                      as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .entries)
            // Kunci map-nya = `field_id` kolom itu. Sel yang isinya `null`
            // artinya kolom itu nggak ada di lembar ini — digambar sebagai sel
            // kosong, bukan error.
            if (e.value is Map<String, dynamic>)
              SelPindai.fromJson(
                e.value as Map<String, dynamic>,
                nomor,
                e.key,
              ),
      ],
    );
  }
}

/// Satu sel hasil baca.
class SelPindai {
  const SelPindai({
    required this.kunci,
    required this.repeatNo,
    required this.fieldId,
    required this.vonis,
    this.teksMentah,
    this.nilai,
    this.alasan = const [],
    this.normalisasi = const [],
  });

  /// `{tabel_id}|{baris_ke}|{repeat_no}|{field_id}` — dipakai APA ADANYA waktu
  /// ngirim koreksi. Jangan disusun ulang di layar.
  final String kunci;

  final int repeatNo;

  /// Kolom lembar kerja: `pembacaan`, `suhu`, … Sama persis dengan `kode`
  /// kolom di bentuk lembar, jadi dipakai apa adanya waktu angkanya dituang
  /// balik ke kotak isian.
  final String fieldId;

  final VonisSel vonis;

  /// Teks apa adanya hasil OCR, termasuk yang ngawur.
  final String? teksMentah;

  /// Angka hasil normalisasi SERVER. `null` = nggak jadi angka yang sah.
  final double? nilai;

  /// Kode alasan dari server (mis. `teks_meluber_dari_sel`). Ditampilin ke
  /// teknisi sebagai kalimat, bukan kodenya.
  final List<String> alasan;

  /// Catatan perubahan yang dilakukan server, mis. `O→0`. Teknisi berhak tahu
  /// angka yang dia lihat udah ditebak-tebak sampai mana.
  final List<String> normalisasi;

  factory SelPindai.fromJson(
    Map<String, dynamic> json,
    int repeatNo,
    String fieldId,
  ) =>
      SelPindai(
        kunci: json['kunci'] as String? ?? '',
        repeatNo: repeatNo,
        fieldId: fieldId,
        vonis: VonisSel.fromApi(json['status'] as String?),
        teksMentah: json['teks_mentah'] as String?,
        nilai: (json['nilai'] as num?)?.toDouble(),
        alasan: (json['alasan'] as List<dynamic>? ?? const [])
            .map((e) => '$e')
            .toList(),
        normalisasi: (json['normalisasi'] as List<dynamic>? ?? const [])
            .map((e) => '$e')
            .toList(),
      );
}

/// Satu sel yang teknisi SETUJUI di layar review, siap dituang ke formulir.
///
/// Bentuknya sengaja bukan `Map<String, double>` berkunci sel: kunci sel itu
/// bahasa server (`{tabel_id}|{baris_ke}|{repeat_no}|{field_id}`), sementara
/// kotak isian di layar lembar kerja dialamati pakai tahap + titik ukur +
/// nomor Repeat + kolom. Nerjemahin kunci jadi alamat kotak dengan mecah
/// stringnya berarti nebak `baris_ke` itu titik yang mana — dan tebakan itu
/// persis cara angka mendarat di baris sebelah. Di sini terjemahannya diambil
/// dari respons server, yang emang ngirim `titik_ukur` per baris.
typedef SelDipakaiPindai = ({
  String tahap,
  double titikUkur,
  int repeatNo,
  String fieldId,
  double nilai,
  bool perluDicek,
});

/// Satu baris koreksi yang dikirim balik waktu teknisi nekan "Pakai Angka Ini".
class KoreksiSel {
  const KoreksiSel({required this.kunci, this.nilaiFinal});

  final String kunci;

  /// `null` buat sel yang memang kosong di kertasnya.
  final double? nilaiFinal;

  Map<String, dynamic> toJson() => {
    'kunci': kunci,
    'nilai_final': nilaiFinal,
  };
}

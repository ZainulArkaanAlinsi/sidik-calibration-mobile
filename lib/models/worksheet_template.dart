import '../core/utils/parse_list.dart';

/// Template pindai lembar kerja — `GET /api/worksheet-templates/{kode}`.
///
/// Bentuk tabelnya diturunkan backend dari `CalibrationProfile::bentukLembarKerja()`,
/// jadi alat ke-7 dan seterusnya otomatis kebagian tanpa nyentuh HP. **Jangan
/// ada satu pun bentuk lembar yang ditulis ulang di sini** — jumlah titik,
/// jumlah kolom pengulangan, satuan, dan desimal semuanya dari respons ini.
class WorksheetTemplate {
  const WorksheetTemplate({
    required this.templateId,
    required this.versi,
    required this.kodeDokumen,
    required this.judul,
    required this.tabel,
    required this.sel,
    required this.siapPindai,
    this.alasanBelumSiap,
    this.ukuranReferensi,
  });

  final String templateId;
  final int versi;
  final String kodeDokumen;
  final String judul;
  final List<TabelTemplate> tabel;

  /// Peta kunci sel → kotak koordinat di ruang [ukuranReferensi].
  ///
  /// Kuncinya dipakai APA ADANYA waktu ngirim hasil pindai. HP nggak pernah
  /// nyusun kunci sendiri dari indeks tampilan: kiriman berkunci asing bikin
  /// SATU LEMBAR PENUH ditolak, dan kunci yang ngarang bisa mendaratkan angka
  /// di sel yang salah tanpa ada yang error.
  final Map<String, KotakSel> sel;

  /// `false` = lembar ini belum boleh dipindai. Tombolnya dimatiin dan
  /// [alasanBelumSiap] ditampilin apa adanya.
  ///
  /// Sekarang keenam alat masih `false` (`geometri_belum_diverifikasi`):
  /// koordinat selnya belum diukur dari lembar CETAK asli, dan koordinat
  /// tebakan berarti angka mendarat di sel yang salah. Ini bukan bug yang perlu
  /// diakalin dari HP — nyalain paksa buat "nyoba dulu" cuma bikin teknisi
  /// percaya fitur yang belum boleh dipakai.
  final bool siapPindai;
  final String? alasanBelumSiap;

  /// Ukuran citra hasil warp yang dipakai koordinat [sel], mis. 1654×2339.
  /// `null` selama geometrinya belum diukur.
  final ({int w, int h})? ukuranReferensi;

  factory WorksheetTemplate.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    final geometri = data['geometri'] as Map<String, dynamic>?;
    final ukuran = geometri?['ukuran_referensi'] as Map<String, dynamic>?;

    return WorksheetTemplate(
      templateId: data['template_id'] as String? ?? '',
      versi: (data['versi'] as num?)?.toInt() ?? 0,
      kodeDokumen: data['kode_dokumen'] as String? ?? '',
      judul: data['judul'] as String? ?? '',
      tabel: parseListAman(data['tabel'], TabelTemplate.fromJson),
      sel: {
        for (final e in (data['sel'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .entries)
          if (e.value is Map<String, dynamic>)
            e.key: KotakSel.fromJson(e.value as Map<String, dynamic>),
      },
      siapPindai: data['siap_pindai'] as bool? ?? false,
      alasanBelumSiap: data['alasan_belum_siap'] as String?,
      ukuranReferensi: ukuran == null
          ? null
          : (
              w: (ukuran['w'] as num?)?.toInt() ?? 0,
              h: (ukuran['h'] as num?)?.toInt() ?? 0,
            ),
    );
  }
}

/// Satu tabel di template pindai.
class TabelTemplate {
  const TabelTemplate({
    required this.tabelId,
    required this.judul,
    required this.baris,
    required this.kolom,
    required this.pengulangan,
  });

  /// **Identitas tabel — `grup ?? tahap`, BUKAN `tahap` doang.**
  ///
  /// Spectrophotometer punya tiga tabel ber-`tahap` sama
  /// (`sesudah_adjustment`) yang cuma dibedain `grup`. Pakai `tahap` doang
  /// bikin ketiganya saling nimpa, dan angka Holmium mendarat di baris
  /// Didynium tanpa satu pun error muncul.
  final String tabelId;

  final String judul;
  final List<BarisTemplate> baris;
  final List<KolomTemplate> kolom;
  final List<int> pengulangan;

  factory TabelTemplate.fromJson(Map<String, dynamic> json) => TabelTemplate(
    tabelId: json['tabel_id'] as String? ?? '',
    judul: json['judul'] as String? ?? '',
    baris: parseListAman(json['baris'], BarisTemplate.fromJson),
    kolom: parseListAman(json['kolom'], KolomTemplate.fromJson),
    pengulangan: (json['pengulangan'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
  );
}

/// Satu baris tabel template — nomor barisnya yang jadi bagian kunci sel.
class BarisTemplate {
  const BarisTemplate({
    required this.barisKe,
    required this.titikUkur,
    required this.label,
    this.standardId,
    this.satuan,
    this.resolusi,
    this.desimal,
  });

  final int barisKe;
  final double titikUkur;
  final String label;

  /// Bukti pembanding yang ikut dikirim balik per sel, **bukan** bagian kunci.
  /// Kalau HP ngirim nilai yang beda dari template, seluruh pemetaan dibatalin
  /// — dan itu memang yang diinginkan.
  final int? standardId;

  final String? satuan;
  final double? resolusi;

  /// `null` kalau `equipment_id` nggak ikut dikirim: satuan/resolusi/desimal
  /// lahir dari alat pelanggan. Jangan diisi nilai bawaan sendiri.
  final int? desimal;

  factory BarisTemplate.fromJson(Map<String, dynamic> json) => BarisTemplate(
    barisKe: (json['baris_ke'] as num?)?.toInt() ?? 0,
    titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
    label: json['label'] as String? ?? '',
    standardId: (json['standard_id'] as num?)?.toInt(),
    satuan: json['satuan'] as String?,
    resolusi: (json['resolusi'] as num?)?.toDouble(),
    desimal: (json['desimal'] as num?)?.toInt(),
  );
}

/// Satu kolom di dalam sel — `field_id` yang jadi bagian kunci sel.
class KolomTemplate {
  const KolomTemplate({required this.fieldId, required this.label, this.satuan});

  final String fieldId;
  final String label;
  final String? satuan;

  factory KolomTemplate.fromJson(Map<String, dynamic> json) => KolomTemplate(
    fieldId: json['field_id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    satuan: json['satuan'] as String?,
  );
}

/// Kotak satu sel di ruang citra hasil warp.
class KotakSel {
  const KotakSel({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  factory KotakSel.fromJson(Map<String, dynamic> json) => KotakSel(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 0,
    h: (json['h'] as num?)?.toDouble() ?? 0,
  );
}

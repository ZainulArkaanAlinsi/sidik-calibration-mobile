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
    this.marker = const [],
    this.jangkar = const [],
    this.qrIsi,
    this.kertas = 'cetak',
    this.revisi,
    this.modeUji = false,
    this.halamanPt,
    this.jangkarTeks = const [],
    this.selAsli = const [],
    this.isian = const [],
    this.centang = const [],
  });

  /// `cetak` = lembar bermarker + QR buatan sistem (kontrak lama, semua field
  /// di atas). `asli` = formulir SIDIK-FM-CAL asli lab tanpa marker & QR —
  /// `GET /worksheet-templates/{kode}?kertas=asli`, `FormulirAsli` di API.
  ///
  /// Dua bentuk ini BEDA ruang koordinatnya, dan itu alasan field asli
  /// dipisah, bukan menumpang [sel]/[ukuranReferensi]: kotak cetak dalam
  /// piksel citra warp, kotak asli TERNORMAL 0..1 terhadap halaman PDF.
  final String kertas;

  bool get kertasAsli => kertas == 'asli';

  /// Revisi TERCETAK formulir asli (`"4"`). Dikirim balik sebagai
  /// `template_versi` — ini revisi yang DIPEGANG aplikasi, bukan yang dibaca
  /// dari foto (itu `revisi_terbaca`).
  final String? revisi;

  /// Sakelar server `OCR_FORMULIR_ASLI_UJI`: formulir yang belum lulus ≥20 foto
  /// boleh dicoba, dengan tidak satu butir pun hijau. Tidak pernah menyalakan
  /// [siapPindai].
  final bool modeUji;

  /// Ukuran halaman formulir asli dalam POINT (pH: 792×612 lanskap). Pecahan
  /// sah — A4 itu 595,28×841,89 pt — jadi bukan `int` seperti [ukuranReferensi].
  final ({double w, double h})? halamanPt;

  /// Tulisan cetak formulir (kata per kata dari PDF) berikut kotaknya — bahan
  /// homography. Urutannya PENTING: `indeks` yang dikirim balik menunjuk ke
  /// posisi di daftar ini.
  final List<JangkarTeks> jangkarTeks;

  /// Sel tabel formulir asli, urut seperti dikirim server. Kuncinya dipakai
  /// APA ADANYA — sama aturannya dengan [sel].
  final List<SelTemplateAsli> selAsli;

  /// Isian di luar tabel yang DIBUKA buat pindai (tahap 1: Env. Condition).
  final List<IsianTemplate> isian;

  /// Kotak centang (Usage Check per baris, TH-n per pilihan).
  final List<CentangTemplate> centang;

  /// Tombol "Pindai formulir kertas" boleh tampil?
  ///
  /// Formulir asli yang belum terverifikasi tetap boleh dicoba selama server
  /// menyalakan mode uji — keputusan pemilik (K1, 9 Okt 2026). Di produksi
  /// sakelarnya mati, jadi tombolnya memang tersembunyi.
  bool get bolehDipindaiAsli => kertasAsli && (siapPindai || modeUji);

  /// Jumlah butir (sel + isian + centang) yang kotaknya `null` — titik peta
  /// yang tidak jatuh di tepat satu kotak draf. Butir begitu TIDAK dibaca, dan
  /// server menolak lembarnya; jadi HP berhenti sebelum kamera dibuka.
  int get kotakAsliHilang =>
      selAsli.where((s) => s.kotak == null).length +
      isian.where((i) => i.kotak == null).length +
      centang.where((c) => c.kotak == null).length;

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

  /// Empat penanda sudut di ruang [ukuranReferensi], urut id 0..3.
  ///
  /// Ini TUJUAN warp — bukan sudut halaman. Markernya dicetak agak masuk ke
  /// dalam kertas, jadi meratakan foto ke pojok halaman menggeser seluruh grid
  /// sebesar jarak itu.
  final List<({double x, double y})> marker;

  /// Label yang TERCETAK di lembar (nomor Repeat) berikut kotaknya.
  ///
  /// Ini penangkal paling ampuh buat kesalahan "geser satu baris": penjagaan
  /// lain ngukur geometri, yang ini **baca isinya**. Kalau grid kegeser, label
  /// yang kebaca di posisi baris ke-2 bakal `3`.
  final List<JangkarTemplate> jangkar;

  /// Isi QR yang tercetak di lembar (`conductivity_meter|v1`).
  ///
  /// Dipakai buat MEMBANDINGKAN sama QR yang beneran kebaca dari foto —
  /// **bukan** buat dikirim balik seolah-olah kebaca. Nyalin nilai ini ke
  /// `qr.isi` tanpa mindai fotonya sama dengan ngaku baca sesuatu yang nggak
  /// pernah dilihat, dan yang dikorbanin persis penjagaan versi lembar.
  final String? qrIsi;

  factory WorksheetTemplate.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    final geometri = data['geometri'] as Map<String, dynamic>?;
    final ukuran = geometri?['ukuran_referensi'] as Map<String, dynamic>?;

    if (data['kertas'] == 'asli') return WorksheetTemplate._asli(data);

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
      marker: [
        for (final m in geometri?['marker'] as List<dynamic>? ?? const [])
          if (m is Map<String, dynamic>)
            (
              x: (m['x'] as num?)?.toDouble() ?? 0,
              y: (m['y'] as num?)?.toDouble() ?? 0,
            ),
      ],
      // `jangkar` ada di level atas respons, bukan di dalam `geometri`.
      jangkar: parseListAman(data['jangkar'], JangkarTemplate.fromJson),
      qrIsi: (geometri?['qr'] as Map<String, dynamic>?)?['isi'] as String?,
    );
  }

  /// Formulir asli (`kertas: "asli"`) — bentuknya `FormulirAsli::untukKode()`
  /// di repo API.
  ///
  /// [sel] sengaja DIBIARKAN KOSONG: entri sel asli tidak punya `x/y/w/h` di
  /// tingkat atas (kotaknya bersarang di `kotak`, ternormal), dan membacanya
  /// lewat [KotakSel.fromJson] menghasilkan kotak 0×0 yang kelihatan sah.
  factory WorksheetTemplate._asli(Map<String, dynamic> data) {
    final geometri = data['geometri'] as Map<String, dynamic>? ?? const {};
    final ukuran = geometri['ukuran_referensi'] as Map<String, dynamic>?;
    final w = (ukuran?['w'] as num?)?.toDouble();
    final h = (ukuran?['h'] as num?)?.toDouble();

    final selMentah = data['sel'];

    return WorksheetTemplate(
      templateId: data['template_id'] as String? ?? '',
      versi: (data['versi'] as num?)?.toInt() ?? 0,
      kodeDokumen: data['kode_dokumen'] as String? ?? '',
      judul: data['judul'] as String? ?? '',
      tabel: parseListAman(data['tabel'], TabelTemplate.fromJson),
      sel: const {},
      siapPindai: data['siap_pindai'] as bool? ?? false,
      alasanBelumSiap: data['alasan_belum_siap'] as String?,
      kertas: 'asli',
      revisi: data['revisi'] == null ? null : '${data['revisi']}',
      modeUji: data['mode_uji'] as bool? ?? false,
      halamanPt: w == null || h == null || w <= 0 || h <= 0
          ? null
          : (w: w, h: h),
      jangkarTeks: parseListAman(geometri['jangkar_teks'], JangkarTeks.fromJson),
      selAsli: [
        if (selMentah is Map<String, dynamic>)
          for (final e in selMentah.entries)
            if (e.value is Map<String, dynamic>)
              SelTemplateAsli.fromJson(e.key, e.value as Map<String, dynamic>),
      ],
      isian: parseListAman(data['isian'], IsianTemplate.fromJson),
      centang: parseListAman(data['centang'], CentangTemplate.fromJson),
    );
  }
}

/// Kotak TERNORMAL 0..1 terhadap halaman, atau `null` — butir yang letaknya
/// tidak diketahui server. `null` = jangan dibaca, bukan "kotak 0×0".
KotakSel? _kotakTernormal(Object? json) =>
    json is Map<String, dynamic> ? KotakSel.fromJson(json) : null;

/// Satu kata cetak formulir asli berikut kotaknya (ternormal).
class JangkarTeks {
  const JangkarTeks({required this.teks, required this.kotak});

  final String teks;
  final KotakSel kotak;

  factory JangkarTeks.fromJson(Map<String, dynamic> json) => JangkarTeks(
    teks: '${json['teks'] ?? ''}',
    kotak: KotakSel.fromJson(
      json['kotak'] as Map<String, dynamic>? ?? const {},
    ),
  );
}

/// Satu sel tabel formulir asli.
///
/// Bagian kuncinya (`tabel_id`, `baris_ke`, `repeat_no`, `field_id`) dibaca
/// dari entri server, BUKAN dipecah dari string kunci — kunci itu bahasa
/// server dan bentuknya boleh berubah tanpa HP ikut tahu.
class SelTemplateAsli {
  const SelTemplateAsli({
    required this.kunci,
    required this.tabelId,
    required this.barisKe,
    required this.repeatNo,
    required this.fieldId,
    this.titikUkur,
    this.standardId,
    this.kotak,
  });

  final String kunci;
  final String tabelId;
  final int barisKe;
  final int repeatNo;
  final String fieldId;

  /// Bukti pembanding, bukan bagian kunci — sama dengan jalur cetak.
  final double? titikUkur;
  final int? standardId;

  /// Ternormal 0..1; `null` = jangan dibaca.
  final KotakSel? kotak;

  factory SelTemplateAsli.fromJson(String kunci, Map<String, dynamic> json) =>
      SelTemplateAsli(
        kunci: json['kunci'] as String? ?? kunci,
        tabelId: json['tabel_id'] as String? ?? '',
        barisKe: (json['baris_ke'] as num?)?.toInt() ?? 0,
        repeatNo: (json['repeat_no'] as num?)?.toInt() ?? 0,
        fieldId: json['field_id'] as String? ?? '',
        titikUkur: (json['titik_ukur'] as num?)?.toDouble(),
        standardId: (json['standard_id'] as num?)?.toInt(),
        kotak: _kotakTernormal(json['kotak']),
      );
}

/// Isian di luar tabel (mis. `suhu_awal`). [cara] mengikuti PANDUAN §4.
class IsianTemplate {
  const IsianTemplate({required this.kode, this.cara, this.kotak});

  final String kode;
  final String? cara;
  final KotakSel? kotak;

  factory IsianTemplate.fromJson(Map<String, dynamic> json) => IsianTemplate(
    kode: json['kode'] as String? ?? '',
    cara: json['cara'] as String?,
    kotak: _kotakTernormal(json['kotak']),
  );
}

/// Kotak centang formulir asli.
///
/// Identitasnya `kode` + [pilihan] (TH-n: satu nilai yang dipilih) ATAU `kode`
/// + [barisKe] (Usage Check per baris tercetak). HP tidak pernah menebak baris
/// dari urutan (PANDUAN §6 butir 5) — keduanya dikirim balik apa adanya.
class CentangTemplate {
  const CentangTemplate({
    required this.kode,
    this.pilihan,
    this.barisKe,
    this.label,
    this.kotak,
  });

  final String kode;
  final String? pilihan;
  final int? barisKe;

  /// Tulisan baris tercetak (Usage Check), mis. `pH Buffer Solutions 4`.
  final String? label;
  final KotakSel? kotak;

  /// Identitas yang sama dengan `idCentang()` di server.
  String get id => '$kode|${pilihan ?? ''}|${barisKe ?? ''}';

  factory CentangTemplate.fromJson(Map<String, dynamic> json) =>
      CentangTemplate(
        kode: json['kode'] as String? ?? '',
        pilihan: json['pilihan'] as String?,
        barisKe: (json['baris_ke'] as num?)?.toInt(),
        label: json['label'] as String?,
        kotak: _kotakTernormal(json['kotak']),
      );
}

/// Satu label tercetak yang ikut dibaca sebagai bukti barisnya nggak geser.
class JangkarTemplate {
  const JangkarTemplate({
    required this.fieldId,
    required this.repeatNo,
    required this.teks,
    required this.kotak,
  });

  final String fieldId;
  final int repeatNo;

  /// Teks yang MESTI kebaca di kotak itu. Yang dikirim balik ke server cuma
  /// cocok/nggaknya — servernya yang mutusin artinya.
  final String teks;

  /// Kotak di ruang citra hasil warp. Bisa `0×0` selama geometrinya masih
  /// rangka: berkas `ocr:rangka-geometri` nulis `{x:0,y:0,w:0,h:0}` buat semua
  /// jangkar. Kotak sebesar itu nggak bisa dipotong, jadi jangkarnya nggak
  /// dibaca — dan yang dikirim BUKAN `cocok: true` karangan, tapi nggak ada
  /// sama sekali, biar servernya yang nolak dengan alasan yang jujur.
  final KotakSel kotak;

  bool get bisaDibaca => kotak.w >= 1 && kotak.h >= 1;

  factory JangkarTemplate.fromJson(Map<String, dynamic> json) =>
      JangkarTemplate(
        fieldId: json['field_id'] as String? ?? '',
        repeatNo: (json['repeat_no'] as num?)?.toInt() ?? 0,
        teks: '${json['teks'] ?? ''}',
        kotak: KotakSel.fromJson(
          json['kotak'] as Map<String, dynamic>? ?? const {},
        ),
      );
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

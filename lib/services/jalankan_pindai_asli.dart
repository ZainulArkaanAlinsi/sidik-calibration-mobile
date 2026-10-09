import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/worksheet_template.dart';
import 'jalankan_pindai.dart' show AmbangMutu, GagalPindai;
import 'pembaca_centang.dart';
import 'pembaca_halaman.dart';
import 'pembaca_sel.dart' show BacaanSel, PembacaSel;
import 'pindai_lembar.dart';
import 'registrasi_jangkar_teks.dart';

/// Kenapa pindai formulir ASLI berhenti sebelum sampai server.
///
/// Dipisah dari [GagalPindai] (jalur cetak bermarker) karena sebabnya beda:
/// tidak ada marker & QR di sini; pengenalnya kode FM tercetak, penyelarasnya
/// tulisan cetak formulir.
enum GagalPindaiAsli {
  /// Template tidak `siap_pindai` dan mode uji server mati.
  belumSiap,

  /// Ada kotak (sel/isian/centang) tanpa koordinat — server pasti menolak.
  geometriBelumLengkap,

  /// Kode formulir (`SIDIK-FM-CAL-xxxx`) tidak terbaca di foto.
  kodeTidakTerbaca,

  /// Yang terbaca kode formulir LAIN.
  formulirLain,

  /// Revisi tercetak beda dengan yang dipegang sistem.
  revisiBeda,

  /// Tulisan cetak yang cocok kurang dari [JalankanPindaiAsli.jangkarMin].
  jangkarKurang,

  /// Cukup jangkar, tapi tidak menyebar ke keempat kuadran halaman.
  jangkarTidakMenyebar,

  /// Mutu foto — rinciannya di [PindaiAsliGagal.mutu].
  mutu,
}

class PindaiAsliGagal implements Exception {
  const PindaiAsliGagal(this.sebab, {this.mutu, this.terbaca, this.jumlah});

  final GagalPindaiAsli sebab;

  /// Sebab mutu foto, kalau [sebab] = [GagalPindaiAsli.mutu]. Ambangnya
  /// salinan server ([AmbangMutu]), sama dengan jalur cetak.
  final GagalPindai? mutu;

  /// Teks yang terbaca — kode formulir lain, atau revisi yang beda.
  final String? terbaca;

  /// Jumlah jangkar cocok / kotak hilang.
  final int? jumlah;

  @override
  String toString() => 'PindaiAsliGagal(${sebab.name})';
}

/// Payload siap kirim + citra halaman yang sudah diratakan.
class HasilSusunPindaiAsli {
  const HasilSusunPindaiAsli({
    required this.body,
    required this.citraWarp,
    required this.registrasi,
  });

  final Map<String, dynamic> body;

  /// Halaman UTUH yang sudah diratakan, rasio sisi = halaman formulir.
  /// Server memotong crop review dari sini (kotak ternormal × ukuran citra)
  /// dan menolak citra yang rasionya meleset > 2%.
  final img.Image citraWarp;

  /// Bukti penyelarasan — buat log & test, tidak dikirim utuh.
  final HasilRegistrasi registrasi;
}

/// Satu foto formulir SIDIK-FM-CAL ASLI → payload `POST /worksheet-scans`
/// (`kertas: "asli"`). PANDUAN-OCR-LEMBAR-KERJA.md §3.
///
/// ```
/// KENALI  → ML Kit sehalaman, cari kode formulir tercetak
/// RATAKAN → jangkar teks unik → homography RANSAC → kanvas halaman
/// POTONG  → kotak dari geometri server (ternormal), BUKAN tebakan posisi
/// BACA    → sel & isian: ML Kit per potongan; centang: rasio piksel gelap
/// ```
///
/// Mesinnya GENERIK: tidak ada satu pun nama alat, kode formulir, atau kunci
/// sel di sini. Formulir berikutnya yang geometrinya dipetakan di server ikut
/// jalan tanpa HP diubah.
///
/// Tidak mengirim sendiri — sama dengan [JalankanPindai], supaya seluruh
/// urutan ini bisa diuji tanpa jaringan.
class JalankanPindaiAsli {
  const JalankanPindaiAsli({
    required this.halaman,
    required this.pembaca,
    this.mesin = const PindaiLembar(),
    this.registrasi = const RegistrasiJangkarTeks(),
    this.skalaPxPerPt = 3.0,
    this.payload = const PayloadPindaiAsli(),
  });

  /// ML Kit SEHALAMAN — buat mengenali formulir & mencari jangkar.
  final PembacaHalaman halaman;

  /// ML Kit PER POTONGAN — buat angka di sel & isian.
  final PembacaSel pembaca;

  final PindaiLembar mesin;
  final RegistrasiJangkarTeks registrasi;

  /// Resolusi kanvas hasil perataan. 3 px/pt: sel tabel pH (±22 pt) jadi
  /// ±66 px, baris Env. (±9,5 pt) ±28 px — dua-duanya masih di atas batas
  /// yang dibesarkan [PembacaSel] sebelum dibaca, dan kanvas Letter lanskap
  /// (2376×1836) masih jauh di bawah batas unggah server setelah JPEG.
  final double skalaPxPerPt;

  final PayloadPindaiAsli payload;

  /// Syarat jangkar — PANDUAN §3 ("≥8 jangkar, menyebar di 4 kuadran"),
  /// angka yang sama dengan `ocr.geometri.jangkar_teks.jumlah_min` server.
  static const jangkarMin = 8;

  Future<HasilSusunPindaiAsli> susun(
    img.Image foto, {
    required WorksheetTemplate template,
    int? calibrationSessionId,
    int? equipmentId,
    Map<String, String>? perangkat,
    DateTime? diambilPada,
  }) async {
    if (!template.bolehDipindaiAsli) {
      throw const PindaiAsliGagal(GagalPindaiAsli.belumSiap);
    }

    final halamanPt = template.halamanPt;
    final hilang = template.kotakAsliHilang;

    if (halamanPt == null ||
        template.jangkarTeks.isEmpty ||
        template.selAsli.isEmpty ||
        hilang > 0) {
      throw PindaiAsliGagal(
        GagalPindaiAsli.geometriBelumLengkap,
        jumlah: hilang,
      );
    }

    // ---- 1. KENALI --------------------------------------------------------
    final dikenali = await _kenali(foto, template, halamanPt);
    final citra = dikenali.citra;
    final terbaca = dikenali.terbaca;

    // ---- 2. RATAKAN -------------------------------------------------------
    final reg = registrasi.cocokkan(
      registrasi.calon(
        jangkar: template.jangkarTeks,
        halamanPt: halamanPt,
        terbaca: terbaca,
      ),
    );

    if (reg == null || reg.inlier.length < jangkarMin) {
      throw PindaiAsliGagal(
        GagalPindaiAsli.jangkarKurang,
        jumlah: reg?.inlier.length ?? 0,
      );
    }

    if (!reg.menyebar) {
      throw PindaiAsliGagal(
        GagalPindaiAsli.jangkarTidakMenyebar,
        jumlah: reg.inlier.length,
      );
    }

    // Revisi dibaca SESUDAH homography: tempatnya ditentukan relatif ke kata
    // "Revise" tercetak di ruang halaman, jadi kemiringan foto tidak
    // menggeser apa yang dibaca.
    final revisiTerbaca = bacaRevisi(
      terbaca: terbaca,
      registrasi: reg,
      jangkar: template.jangkarTeks,
      halamanPt: halamanPt,
    );
    final angkaRevisi = revisiTerbaca == null
        ? null
        : RegExp(r'\d+').firstMatch(revisiTerbaca)?.group(0);

    if (angkaRevisi != null &&
        int.tryParse(angkaRevisi) != int.tryParse(template.revisi ?? '')) {
      throw PindaiAsliGagal(GagalPindaiAsli.revisiBeda, terbaca: revisiTerbaca);
    }

    final warp = ratakanHalaman(
      citra,
      reg.templateKeFoto,
      halamanPt: halamanPt,
      skala: skalaPxPerPt,
    );

    // ---- Mutu: dihitung di HP, diputuskan server ---------------------------
    final mutu = mesin.mutu(warp);
    final sudut = _sudutSisaDeg(reg.templateKeFoto, halamanPt);
    final pxPerSel = _pxPerSelTinggi(template, reg.templateKeFoto, halamanPt);

    final sebabMutu = AmbangMutu.periksa(
      mutu,
      sudutMiringDeg: sudut,
      pxPerSelTinggi: pxPerSel,
    );
    if (sebabMutu != null) {
      throw PindaiAsliGagal(GagalPindaiAsli.mutu, mutu: sebabMutu);
    }

    // ---- 3–4. POTONG & BACA -----------------------------------------------
    ({double x, double y, double w, double h}) piksel(KotakSel k) => (
      x: k.x * warp.width,
      y: k.y * warp.height,
      w: k.w * warp.width,
      h: k.h * warp.height,
    );

    Future<BacaanSel> bacaKotak(KotakSel k) {
      final p = piksel(k);

      return pembaca.baca(
        mesin.potongSel(warp, x: p.x, y: p.y, w: p.w, h: p.h),
      );
    }

    final sel = <String, BacaanSel>{
      for (final s in template.selAsli) s.kunci: await bacaKotak(s.kotak!),
    };

    final isian = <String, BacaanSel>{
      for (final i in template.isian) i.kode: await bacaKotak(i.kotak!),
    };

    final centang = <String, double?>{
      for (final c in template.centang)
        c.id: () {
          final p = piksel(c.kotak!);

          return rasioGelapCentang(warp, x: p.x, y: p.y, w: p.w, h: p.h);
        }(),
    };

    return HasilSusunPindaiAsli(
      body: payload.susun(
        template: template,
        kodeTerbaca: dikenali.kode,
        revisiTerbaca: revisiTerbaca,
        jangkarCocok: reg.inlier,
        residualPt: reg.residualPt,
        mutu: mutu,
        sudutMiringDeg: sudut,
        pxPerSelTinggi: pxPerSel,
        sel: sel,
        isian: isian,
        centang: centang,
        calibrationSessionId: calibrationSessionId,
        equipmentId: equipmentId,
        perangkat: perangkat,
        diambilPada: diambilPada,
      ),
      citraWarp: warp,
      registrasi: reg,
    );
  }

  /// Cari orientasi yang membuat kode formulir terbaca.
  ///
  /// Formulir lanskap yang difoto dengan HP tegak muncul TERBARING di foto, dan
  /// ML Kit membaca teks terbaring jauh lebih buruk daripada teks tegak. Jadi
  /// fotonya diputar dulu — kelipatan 90° saja, dipilih dari bentuk fotonya:
  /// foto yang bentuknya sama dengan halaman dicoba 0° lalu 180°, yang
  /// bentuknya beda dicoba 90° lalu 270°. Paling banyak dua kali baca.
  Future<({img.Image citra, List<TeksTerbaca> terbaca, String kode})> _kenali(
    img.Image foto,
    WorksheetTemplate template,
    ({double w, double h}) halamanPt,
  ) async {
    // EXIF orientasi dipanggang dulu: `decodeImage` membiarkan piksel apa
    // adanya dan cuma mencatat orientasinya. Cuma kalau memang ada —
    // `bakeOrientation` selalu menyalin, dan salinan foto 12 MP itu ±36 MB.
    final ifd = foto.exif.imageIfd;
    final tegak = ifd.hasOrientation && ifd.orientation != 1
        ? img.bakeOrientation(foto)
        : foto;

    final halamanLanskap = halamanPt.w >= halamanPt.h;
    final fotoLanskap = tegak.width >= tegak.height;
    final sudut = halamanLanskap == fotoLanskap
        ? const [0, 180]
        : const [90, 270];

    String? kodeLain;

    for (final s in sudut) {
      final citra = s == 0 ? tegak : img.copyRotate(tegak, angle: s);
      final terbaca = await halaman.baca(citra);
      final cari = cariKodeDokumen(terbaca, template.kodeDokumen);

      if (cari.cocok != null) {
        return (citra: citra, terbaca: terbaca, kode: cari.cocok!);
      }

      kodeLain ??= cari.lain;
    }

    if (kodeLain != null) {
      throw PindaiAsliGagal(GagalPindaiAsli.formulirLain, terbaca: kodeLain);
    }

    throw const PindaiAsliGagal(GagalPindaiAsli.kodeTidakTerbaca);
  }

  /// Kemiringan sisa sisi atas halaman di foto, dalam derajat, sesudah
  /// orientasi kelipatan 90° dinormalkan.
  ///
  /// Yang dikirim sebagai `sudut_kemiringan_deg`. Ambang server (8°) menjaga
  /// foto yang DIAMBIL MIRING — perspektif yang menggepengkan tulisan. Halaman
  /// yang terbaring 90° bukan foto miring: kanvasnya diratakan utuh dan
  /// potongan selnya tegak, jadi yang dilaporkan cuma sisa di luar kelipatan
  /// 90°. Normalnya sudah nol karena [_kenali] memutar fotonya lebih dulu.
  static double _sudutSisaDeg(
    Homografi templateKeFoto,
    ({double w, double h}) halamanPt,
  ) {
    final a = templateKeFoto.terapkan((x: 0, y: 0));
    final b = templateKeFoto.terapkan((x: halamanPt.w, y: 0));
    if (a == null || b == null) return 0;

    final deg = math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;

    return deg - (deg / 90).round() * 90;
  }

  /// Tinggi rata-rata satu sel tabel dalam piksel FOTO — bukan piksel kanvas,
  /// alasannya sama dengan `JalankanPindai._pxPerSelTinggi`: di kanvas, tinggi
  /// sel selalu sama berapa pun jauhnya HP.
  static int _pxPerSelTinggi(
    WorksheetTemplate template,
    Homografi templateKeFoto,
    ({double w, double h}) halamanPt,
  ) {
    var total = 0.0;
    var n = 0;

    for (final s in template.selAsli) {
      final k = s.kotak;
      if (k == null) continue;

      final cx = (k.x + k.w / 2) * halamanPt.w;
      final atas = templateKeFoto.terapkan((x: cx, y: k.y * halamanPt.h));
      final bawah = templateKeFoto.terapkan((
        x: cx,
        y: (k.y + k.h) * halamanPt.h,
      ));
      if (atas == null || bawah == null) continue;

      total += math.sqrt(
        math.pow(bawah.x - atas.x, 2) + math.pow(bawah.y - atas.y, 2),
      );
      n++;
    }

    return n == 0 ? 0 : (total / n).round();
  }
}

/// Kode formulir di teks halaman.
///
/// [cocok] = teks MENTAH yang dinormalkan sama persis dengan [kode] (dikirim
/// apa adanya sebagai `kode_dokumen_terbaca`; server menormalkan ulang).
/// [lain] = kode formulir lain berawalan sama yang terbaca — buat pesan
/// "yang difoto formulir X", bukan "kode tidak terbaca".
///
/// Kata yang dipecah ML Kit (`SIDIK-FM-CAL-` `0509`) ikut dicoba sampai tiga
/// kata berurutan. Tidak ada koreksi karakter: `O5O9` bukan `0509`.
///
/// "Formulir lain" cuma kalau yang terbaca BERBENTUK kode sah (awalan sama +
/// empat angka). `SIDIK-FM-CAL-O5O9` itu salah baca, bukan formulir lain —
/// pesannya harus "foto ulang", bukan "salah formulir".
({String? cocok, String? lain}) cariKodeDokumen(
  List<TeksTerbaca> terbaca,
  String kode,
) {
  final target = normalisasiKodeDokumen(kode);
  if (target.isEmpty) return (cocok: null, lain: null);

  final pisah = target.lastIndexOf('-');
  final awalan = pisah > 0 ? target.substring(0, pisah + 1) : null;
  final kodeSah = awalan == null
      ? null
      : RegExp('^${RegExp.escape(awalan)}\\d{4}');
  String? lain;

  for (var i = 0; i < terbaca.length; i++) {
    for (var n = 1; n <= 3 && i + n <= terbaca.length; n++) {
      final mentah = [
        for (var k = i; k < i + n; k++) terbaca[k].teks,
      ].join(' ');
      final norm = normalisasiKodeDokumen(mentah);

      if (norm == target) return (cocok: mentah, lain: null);

      if (n == 1 && lain == null && (kodeSah?.hasMatch(norm) ?? false)) {
        lain = mentah;
      }
    }
  }

  return (cocok: null, lain: lain);
}

/// Teks revisi tercetak di kanan kata "Revise"/"Revisi", atau `null` kalau
/// formulirnya tidak mencetaknya (12 dari 41 formulir — PANDUAN §2 butir 5).
///
/// Dicari di RUANG HALAMAN lewat homography: kata yang pusatnya jatuh di
/// pita baris yang sama, sampai 80 pt di kanan kata itu.
String? bacaRevisi({
  required List<TeksTerbaca> terbaca,
  required HasilRegistrasi registrasi,
  required List<JangkarTeks> jangkar,
  required ({double w, double h}) halamanPt,
}) {
  const kata = {'REVISE', 'REVISI', 'REVISION', 'REV'};

  final calon = [
    for (final j in jangkar)
      if (kata.contains(normalisasiJangkar(j.teks))) j,
  ];
  if (calon.length != 1) return null;

  final k = calon.single.kotak;
  final x0 = (k.x + k.w) * halamanPt.w;
  final x1 = x0 + 80;
  final tinggi = k.h * halamanPt.h;
  final y0 = k.y * halamanPt.h - tinggi * 0.5;
  final y1 = (k.y + k.h) * halamanPt.h + tinggi * 0.5;

  final kena = <({double x, String teks})>[];

  for (final e in terbaca) {
    if (kata.contains(normalisasiJangkar(e.teks))) continue;

    final p = registrasi.fotoKeTemplate.terapkan((
      x: e.kotak.center.dx,
      y: e.kotak.center.dy,
    ));
    if (p == null) continue;

    if (p.x > x0 - 2 && p.x <= x1 && p.y >= y0 && p.y <= y1) {
      kena.add((x: p.x, teks: e.teks));
    }
  }

  if (kena.isEmpty) return null;

  kena.sort((a, b) => a.x.compareTo(b.x));
  final teks = kena.map((e) => e.teks).join(' ').trim();

  return teks.isEmpty ? null : teks;
}

/// Payload `POST /api/worksheet-scans` untuk formulir ASLI — kontrak
/// `WorksheetScanRequest::aturanAsli()` di repo API (B2, 3222d1b).
///
/// Aturan yang sama dengan [PayloadPindai] jalur cetak, dan sama mahalnya
/// kalau dilanggar:
///
///  - kunci sel & identitas centang diambil dari TEMPLATE apa adanya;
///  - SEMUA sel, isian, dan centang template ikut — termasuk yang kosong;
///  - teks dikirim apa adanya, tanpa dibersihkan & tanpa koma tambahan;
///  - nilai yang tidak terukur dikirim `null`, bukan angka karangan.
///
/// `geometri.ukuran_referensi` SENGAJA tidak dikirim: aturannya `integer` di
/// server, sedangkan halaman A4 595,28×841,89 pt — satu pecahan menolak SELURUH
/// kiriman di lapisan bentuk. Server memakai ukuran dari template sendiri.
class PayloadPindaiAsli {
  const PayloadPindaiAsli();

  Map<String, dynamic> susun({
    required WorksheetTemplate template,
    required String kodeTerbaca,
    required List<CalonJangkar> jangkarCocok,
    required double residualPt,
    required ({double blur, double kecerahan, double glare}) mutu,
    required double sudutMiringDeg,
    required int pxPerSelTinggi,
    required Map<String, BacaanSel> sel,
    required Map<String, BacaanSel> isian,
    required Map<String, double?> centang,
    String? revisiTerbaca,
    int? calibrationSessionId,
    int? equipmentId,
    Map<String, String>? perangkat,
    DateTime? diambilPada,
  }) {
    final jangkarUrut = [...jangkarCocok]
      ..sort((a, b) => a.indeks.compareTo(b.indeks));

    return {
      'kertas': 'asli',
      'template_id': template.templateId,
      // Revisi yang DIPEGANG aplikasi (dari template), bukan yang dibaca —
      // yang dibaca ikut di `revisi_terbaca`, dan server menolak kalau
      // keduanya saling membantah.
      'template_versi': int.tryParse(template.revisi ?? '') ?? 0,
      'kode_dokumen_terbaca': _maks(kodeTerbaca, 40),
      if (revisiTerbaca case final String r) 'revisi_terbaca': _maks(r, 20),
      if (calibrationSessionId case final int id) 'calibration_session_id': id,
      if (equipmentId case final int id) 'equipment_id': id,

      'geometri': {
        'jangkar_cocok': [
          for (final j in jangkarUrut)
            {'indeks': j.indeks, 'teks_mentah': _maks(j.teksMentah, 64)},
        ],
        'residual_reproyeksi_pt': residualPt,
      },

      // Apa adanya, tidak dibulatkan — kecuali `px_per_sel_tinggi` yang
      // divalidasi `integer` (lihat `PayloadPindai`).
      'kualitas': {
        'blur_laplacian': mutu.blur,
        'kecerahan_rata': mutu.kecerahan,
        'rasio_glare': mutu.glare,
        'sudut_kemiringan_deg': sudutMiringDeg,
        'px_per_sel_tinggi': pxPerSelTinggi,
      },

      if (perangkat case final Map<String, String> p) 'perangkat': p,
      'diambil_pada': (diambilPada ?? DateTime.now()).toIso8601String(),

      'sel': [
        for (final s in template.selAsli)
          {
            'tabel_id': s.tabelId,
            'baris_ke': s.barisKe,
            'repeat_no': s.repeatNo,
            'field_id': s.fieldId,
            'teks_mentah': _maksAtauNull(sel[s.kunci]?.teks, 64),
            'confidence_ocr': sel[s.kunci]?.keyakinan,
            'kotak_teks_di_dalam_sel': sel[s.kunci]?.didalamKotak ?? true,
            // Bukti pembanding, BUKAN kunci: beda dari template = APK memegang
            // formulir versi lain, dan server membatalkan pemetaannya.
            if (s.titikUkur case final double t) 'titik_ukur': t,
            if (s.standardId case final int id) 'standard_id': id,
            'sumber': 'mlkit',
          },
      ],

      'isian': [
        for (final i in template.isian)
          {
            'kode': i.kode,
            'teks_mentah': _maksAtauNull(isian[i.kode]?.teks, 64),
            'confidence_ocr': isian[i.kode]?.keyakinan,
            'kotak_teks_di_dalam_sel': isian[i.kode]?.didalamKotak ?? true,
            'sumber': 'mlkit',
          },
      ],

      'centang': [
        for (final c in template.centang)
          {
            'kode': c.kode,
            if (c.barisKe case final int b) 'baris_ke': b,
            if (c.pilihan case final String p) 'pilihan': p,
            'rasio_gelap': centang[c.id],
          },
      ],
    };
  }
}

/// Potong teks mentah ke batas `max:` aturan server.
///
/// Bukan merapikan bacaan: satu teks yang kepanjangan (ML Kit yang ikut
/// membaca label cetak di sebelah kotak) menolak SELURUH lembar di lapisan
/// bentuk dengan 422 tanpa `status` — teknisi cuma melihat "gagal", bukan sel
/// mana yang salah. Yang tersisa tetap awal bacaan aslinya, dan bacaan
/// sepanjang itu di kotak angka akan divonis merah oleh server.
String _maks(String teks, int n) =>
    teks.length <= n ? teks : teks.substring(0, n);

String? _maksAtauNull(String? teks, int n) =>
    teks == null ? null : _maks(teks, n);

/// JPEG citra halaman yang sudah diratakan — lampiran `citra_warp`.
///
/// JPEG, bukan PNG seperti jalur cetak: halaman foto berderau sebesar
/// 2376×1836 sebagai PNG bisa mendekati batas 8 MB server, dan satu lampiran
/// yang kebesaran menolak SELURUH kiriman. Kualitas 95 — yang dibaca mesin
/// sudah dibaca di HP; citra ini cuma dipotong untuk dicocokkan mata teknisi.
Uint8List jpgDari(img.Image citra) => img.encodeJpg(citra, quality: 95);

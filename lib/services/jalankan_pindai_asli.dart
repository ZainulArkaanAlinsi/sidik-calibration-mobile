import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/worksheet_template.dart';
import 'jalankan_pindai.dart' show AmbangMutu, GagalPindai;
import 'baca_paralel.dart';
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

  /// Teks revisi tidak terbaca di foto — tidak boleh dilewati diam-diam.
  revisiTidakTerbaca,

  /// Tulisan cetak yang cocok kurang dari [JalankanPindaiAsli.jangkarMin].
  jangkarKurang,

  /// Cukup jangkar, tapi tidak menyebar ke keempat kuadran halaman.
  jangkarTidakMenyebar,

  /// Mutu foto — rinciannya di [PindaiAsliGagal.mutu].
  mutu,

  /// Sisi atas halaman di foto (sesudah [JalankanPindaiAsli] memutarnya tegak)
  /// tidak mendatar: bingkai teks ML Kit dan citra Dart berbeda 180° (atau
  /// lebih dari 45°). Dipotong terus, sel diambil dari posisi simetris yang
  /// salah.
  fotoTerbalik,

  /// SEMUA potongan sel/isian gagal dibaca — pengenal teks tidak jalan.
  pembacaMati,
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

/// Satu sel hasil baca — teks mentah ML Kit + keyakinannya. Hanya USULAN.
typedef SelAsliTerbaca = ({SelTemplateAsli sel, BacaanSel bacaan});

/// Satu isian di luar tabel (Env. Condition) hasil baca — juga hanya USULAN.
typedef IsianAsliTerbaca = ({IsianTemplate isian, BacaanSel bacaan});

/// Kunci potongan isian di [HasilBacaAsli.potongan] — sama dengan bentuk kunci
/// isian di rute crop server (`isian|{kode}`), supaya tidak bertabrakan dengan
/// kunci sel tabel.
String kunciPotonganIsian(String kode) => 'isian|$kode';

/// Hasil baca satu foto formulir asli. Tidak memuat citra: foto tidak pernah
/// keluar dari HP dan tidak disimpan di sini (K-50-11).
class HasilBacaAsli {
  const HasilBacaAsli({
    required this.sel,
    required this.kodeTerbaca,
    this.revisiTerbaca,
    this.isian = const [],
    this.potongan = const {},
    this.gagalDibaca = const {},
  });

  final List<SelAsliTerbaca> sel;

  /// Isian Env./header yang dibuka server (`tahap: 1`) dan ada kotaknya di
  /// peta. Kotak centang TIDAK dibaca: dibiarkan untuk diisi manual.
  final List<IsianAsliTerbaca> isian;
  final String kodeTerbaca;
  final String? revisiTerbaca;

  /// Potongan PNG per kunci sel (dari halaman yang sudah diratakan), buat
  /// layar review — hanya di memori.
  final Map<String, Uint8List> potongan;

  /// Kunci sel (`SelTemplateAsli.kunci`) dan isian ([kunciPotonganIsian])
  /// yang pembacaannya GAGAL (ML Kit melempar galat), bukan yang kosong di
  /// kertas. Bacaannya `teks: null`; yang membedakannya dari sel kosong cuma
  /// himpunan ini. Penampil review wajib menjadikannya MERAH dan kosong —
  /// kalau diperlakukan seperti sel kosong, sel yang tak terbaca hilang
  /// diam-diam dari review.
  final Set<String> gagalDibaca;
}

/// Satu foto formulir SIDIK-FM-CAL ASLI → bacaan per sel, SELURUHNYA di HP
/// (ML Kit on-device, K-50-11). Tidak ada yang dikirim ke server.
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

  /// Syarat jangkar — PANDUAN §3 ("≥8 jangkar, menyebar di 4 kuadran"),
  /// angka yang sama dengan `ocr.geometri.jangkar_teks.jumlah_min` server.
  static const jangkarMin = 8;

  /// [jpegAsli] = bita JPEG kamera yang di-decode jadi [foto] (sebelum EXIF
  /// dipanggang). Kalau ada, ML Kit sehalaman membaca JPEG itu langsung —
  /// tanpa encode ulang ke PNG dan tanpa menurunkan resolusi. `null` (test,
  /// sumber non-JPEG) = jalur PNG lama.
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
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
    final dikenali = await _kenali(foto, template, halamanPt, jpegAsli);
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

    // Penjaga salah-putar 180° (temuan peninjau M01 #1). Rotasi 180° tetap
    // homografi yang sah — residualnya rendah dan `_sudutSisaDeg` menormalkan
    // 180 jadi 0 — jadi dia lolos semua gerbang lain. Karena [_kenali] sudah
    // memutar citra tegak, sudut MENTAH sisi atas halaman harus dekat 0.
    final sudutMentah = sudutMentahSisiAtasDeg(reg.templateKeFoto, halamanPt);
    if (sudutMentah == null || sudutMentah.abs() >= sudutMentahMaksDeg) {
      throw const PindaiAsliGagal(GagalPindaiAsli.fotoTerbalik);
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

    // Revisi yang tidak terbaca BERHENTI di sini. Dulu null = lanjut, sehingga
    // formulir revisi lama (kotak bergeser) bisa dibaca seolah revisi ini.
    // Pengecualian cuma untuk formulir yang menyatakan tak mencetak revisi.
    final tanpaRevisiTercetak =
        revisiTerbaca == null && !template.revisiTercetak;

    if (!tanpaRevisiTercetak) {
      if (revisiTerbaca == null || angkaRevisi == null) {
        throw PindaiAsliGagal(
          GagalPindaiAsli.revisiTidakTerbaca,
          terbaca: revisiTerbaca,
        );
      }

      if (int.tryParse(angkaRevisi) != int.tryParse(template.revisi ?? '')) {
        throw PindaiAsliGagal(
          GagalPindaiAsli.revisiBeda,
          terbaca: revisiTerbaca,
        );
      }
    }

    // Perataan kanvas 4,4 MP + ukuran mutunya = kerja per piksel terberat di
    // alur ini → isolate latar, supaya layar tidak beku beberapa detik.
    // Kodenya sama persis; yang pindah cuma tempat jalannya.
    // Argumen disalin ke variabel lokal dulu: closure yang menyebut field
    // instans membawa `this` (dan pembaca ML Kit native) ke isolate lain.
    final skala = skalaPxPerPt;
    final mesinLokal = mesin;
    final templateKeFoto = reg.templateKeFoto;
    final (:warp, :mutu) = await _ratakanDanUkurDiIsolate((
      foto: citra,
      templateKeFoto: templateKeFoto,
      halamanPt: halamanPt,
      skala: skala,
      mesin: mesinLokal,
    ));

    // ---- Mutu: dihitung di HP, diputuskan server ---------------------------
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

    // SEL tabel (usulan angka ukur) lalu ISIAN Env./header yang dibuka server.
    // Kotak centang sengaja TIDAK dibaca: pilihan Thermohygro/Usage Check
    // menentukan standar yang tercatat, jadi teknisi memilihnya sendiri.
    final gambar = <String, img.Image>{};
    final gagalDibaca = <String>{};

    // Potong dulu semuanya (murah, `copyCrop` kotak kecil), baru dibaca
    // [bacaSelSerentak] sekaligus. Hasil dipasangkan menurut INDEKS — urutan
    // selesai ML Kit tidak pernah menentukan sel mana mendapat bacaan mana.
    final antrean = <({String kunci, img.Image potong})>[];

    for (final s in template.selAsli) {
      final p = piksel(s.kotak!);
      final potong = mesin.potongSel(warp, x: p.x, y: p.y, w: p.w, h: p.h);

      gambar[s.kunci] = potong;
      antrean.add((kunci: s.kunci, potong: potong));
    }

    for (final i in template.isian) {
      final p = piksel(i.kotak!);
      final potong = mesin.potongSel(warp, x: p.x, y: p.y, w: p.w, h: p.h);
      final kunci = kunciPotonganIsian(i.kode);

      gambar[kunci] = potong;
      antrean.add((kunci: kunci, potong: potong));
    }

    final pembacaLokal = pembaca;
    final bacaan =
        await petaTerbatas<({String kunci, img.Image potong}), BacaanSel>(
          antrean,
          (a) async {
            try {
              return await pembacaLokal.baca(a.potong);
            } catch (_) {
              // Satu sel gagal TIDAK menggugurkan sel lain. Sel ini jadi kosong
              // (tanpa teks karangan, tanpa nol) dan dicatat di [gagalDibaca]
              // supaya review menandainya MERAH.
              gagalDibaca.add(a.kunci);
              return (teks: null, keyakinan: null, didalamKotak: true);
            }
          },
        );

    // Semua gagal = pengenalnya mati, bukan kertasnya. Satu layar penuh merah
    // menyesatkan (seolah fotonya jelek) → pesan galat umum (keputusan
    // orkestrator, 20 Okt).
    if (antrean.isNotEmpty && gagalDibaca.length == antrean.length) {
      throw const PindaiAsliGagal(GagalPindaiAsli.pembacaMati);
    }

    final jumlahSel = template.selAsli.length;
    final hasil = <SelAsliTerbaca>[
      for (var k = 0; k < jumlahSel; k++)
        (sel: template.selAsli[k], bacaan: bacaan[k]),
    ];
    final hasilIsian = <IsianAsliTerbaca>[
      for (var k = 0; k < template.isian.length; k++)
        (isian: template.isian[k], bacaan: bacaan[jumlahSel + k]),
    ];

    // Encode PNG puluhan potongan di isolate latar, bukan isolate UI.
    final potongan = await encodePotonganDiIsolate(gambar);

    return HasilBacaAsli(
      sel: hasil,
      kodeTerbaca: dikenali.kode,
      revisiTerbaca: revisiTerbaca,
      isian: hasilIsian,
      potongan: potongan,
      gagalDibaca: gagalDibaca,
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
    Uint8List? jpegAsli,
  ) async {
    // EXIF orientasi dipanggang dulu: `decodeImage` membiarkan piksel apa
    // adanya dan cuma mencatat orientasinya. Cuma kalau memang ada —
    // `bakeOrientation` selalu menyalin, dan salinan foto 12 MP itu ±36 MB.
    // Panggang & putar menyalin seluruh foto → isolate latar.
    final ifd = foto.exif.imageIfd;
    final orientasiAsal = ifd.hasOrientation ? ifd.orientation ?? 1 : 1;
    final tegak = ifd.hasOrientation && ifd.orientation != 1
        ? await _panggangDiIsolate(foto)
        : foto;

    final halamanLanskap = halamanPt.w >= halamanPt.h;
    final fotoLanskap = tegak.width >= tegak.height;
    final sudut = halamanLanskap == fotoLanskap
        ? const [0, 180]
        : const [90, 270];

    String? kodeLain;

    for (final s in sudut) {
      final citra = s == 0 ? tegak : await _putarDiIsolate(tegak, s);
      // JPEG asli + orientasi EXIF yang membuat ML Kit melihat bingkai yang
      // SAMA dengan [citra] (EXIF dipanggang lalu diputar [s]).
      final terbaca = await halaman.baca(
        citra,
        asli: jpegAsli == null
            ? null
            : (
                jpeg: jpegAsli,
                orientasi: orientasiSetelahPutar(orientasiAsal, s),
              ),
      );
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

/// Batas sudut MENTAH sisi atas halaman di foto, dalam derajat.
const sudutMentahMaksDeg = 45.0;

/// Sudut sisi atas halaman (template (0,0)→(w,0)) di foto, derajat, TANPA
/// dinormalkan ke kelipatan 90°. `null` = tidak terpetakan.
double? sudutMentahSisiAtasDeg(
  Homografi templateKeFoto,
  ({double w, double h}) halamanPt,
) {
  final a = templateKeFoto.terapkan((x: 0, y: 0));
  final b = templateKeFoto.terapkan((x: halamanPt.w, y: 0));
  if (a == null || b == null) return null;

  return math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;
}

// ---- Isolate latar ---------------------------------------------------------
//
// Fungsi puncak (bukan closure di dalam metode) supaya yang dikirim ke isolate
// cuma argumennya — closure di metode instans bisa ikut membawa `this`,
// termasuk pembaca ML Kit yang memegang sumber daya native.

img.Image _putar(({img.Image citra, int sudut}) a) =>
    img.copyRotate(a.citra, angle: a.sudut);

// Pembungkus `Isolate.run` sebagai fungsi PUNCAK (temuan peninjau M01 #2):
// closure yang dibuat di dalam `baca` ikut membawa konteks scope-nya —
// termasuk pembaca ML Kit dan himpunan yang ditangkap lambda lain — dan bisa
// ditolak "unsendable". Di sini scope-nya cuma argumennya sendiri.

Future<img.Image> _panggangDiIsolate(img.Image foto) =>
    Isolate.run(() => img.bakeOrientation(foto));

Future<img.Image> _putarDiIsolate(img.Image citra, int sudut) =>
    Isolate.run(() => _putar((citra: citra, sudut: sudut)));

Future<({img.Image warp, ({double blur, double kecerahan, double glare}) mutu})>
_ratakanDanUkurDiIsolate(
  ({
    img.Image foto,
    Homografi templateKeFoto,
    ({double w, double h}) halamanPt,
    double skala,
    PindaiLembar mesin,
  })
  a,
) => Isolate.run(() => _ratakanDanUkur(a));

/// Encode PNG tiap potongan di isolate latar. Yang dikirim cuma [gambar].
Future<Map<String, Uint8List>> encodePotonganDiIsolate(
  Map<String, img.Image> gambar,
) => Isolate.run(() => _encodePotongan(gambar));

Map<String, Uint8List> _encodePotongan(Map<String, img.Image> gambar) => {
  for (final e in gambar.entries)
    e.key: Uint8List.fromList(img.encodePng(e.value)),
};

({img.Image warp, ({double blur, double kecerahan, double glare}) mutu})
_ratakanDanUkur(
  ({
    img.Image foto,
    Homografi templateKeFoto,
    ({double w, double h}) halamanPt,
    double skala,
    PindaiLembar mesin,
  })
  a,
) {
  final warp = ratakanHalaman(
    a.foto,
    a.templateKeFoto,
    halamanPt: a.halamanPt,
    skala: a.skala,
  );

  return (warp: warp, mutu: a.mesin.mutu(warp));
}

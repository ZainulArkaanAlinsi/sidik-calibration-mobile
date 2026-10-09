import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/worksheet_template.dart';
import 'pembaca_halaman.dart' show TeksTerbaca;

/// Satu titik di bidang 2D — piksel foto ATAU point halaman, tergantung sisi.
typedef Titik = ({double x, double y});

/// Satu pasangan "tulisan cetak #[indeks] di template" ↔ "kata yang sama di
/// foto". [template] dalam POINT halaman, [foto] dalam piksel foto.
typedef CalonJangkar = ({
  int indeks,
  String teksMentah,
  Titik foto,
  Titik template,
  int kuadran,
});

/// Huruf & angka saja, huruf besar — SAMA PERSIS dengan
/// `PemrosesScanLembarKerja::teksJangkar()` di server: `(oC)` = `OC`,
/// `:Insitu:` = `INSITU`.
///
/// Harus sama, bukan cuma mirip: server mengadu teks yang dikirim HP ke teks
/// template lewat fungsi ini, dan jangkar yang lolos di HP tapi gagal di server
/// cuma dibuang dari hitungan — lembar yang tampak aman di HP lalu ditolak
/// "patokan kurang" tanpa alasan yang kebaca.
String normalisasiJangkar(String teks) =>
    teks.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '').toUpperCase();

/// Kode formulir dinormalkan: spasi dibuang, huruf besar — sama dengan
/// `PemrosesScanLembarKerja::kodeDokumen()`. Tidak ada pencocokan longgar:
/// `0509` dan `0510` tetap beda, dan `O` tidak ditebak jadi `0`.
String normalisasiKodeDokumen(String teks) =>
    teks.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Kuadran halaman dari PUSAT kotak ternormal: 0 kiri-atas, 1 kanan-atas,
/// 2 kiri-bawah, 3 kanan-bawah — urutan & batas 0,5 sama dengan
/// `PemrosesScanLembarKerja::kuadran()`.
int kuadranKotak(KotakSel k) =>
    (k.x + k.w / 2 >= 0.5 ? 1 : 0) + (k.y + k.h / 2 >= 0.5 ? 2 : 0);

/// Homografi 3×3 (baris-mayor, `m[8]` dinormalkan 1).
class Homografi {
  const Homografi(this.m);

  final List<double> m;

  /// `null` kalau titiknya jatuh di garis tak hingga — bukan dipaksa jadi
  /// angka raksasa yang kelihatan sah.
  Titik? terapkan(Titik p) {
    final w = m[6] * p.x + m[7] * p.y + m[8];
    if (w.abs() < 1e-12) return null;

    return (
      x: (m[0] * p.x + m[1] * p.y + m[2]) / w,
      y: (m[3] * p.x + m[4] * p.y + m[5]) / w,
    );
  }

  /// Penyebut proyeksi di [p]. Tandanya harus SAMA untuk semua titik lembar:
  /// beda tanda = bidangnya "terlipat" melewati tak hingga.
  double penyebut(Titik p) => m[6] * p.x + m[7] * p.y + m[8];

  /// Determinan Jacobian di [p]. Positif = orientasi terjaga (boleh diputar,
  /// boleh miring); negatif = cermin — foto kertas tidak pernah tercermin, jadi
  /// hipotesis begitu pasti salah cocok.
  double determinanJacobian(Titik p) {
    final w = penyebut(p);
    if (w.abs() < 1e-12) return 0;

    final u = (m[0] * p.x + m[1] * p.y + m[2]) / w;
    final v = (m[3] * p.x + m[4] * p.y + m[5]) / w;
    final dudx = (m[0] - u * m[6]) / w;
    final dudy = (m[1] - u * m[7]) / w;
    final dvdx = (m[3] - v * m[6]) / w;
    final dvdy = (m[4] - v * m[7]) / w;

    return dudx * dvdy - dudy * dvdx;
  }

  Homografi? invers() {
    final det =
        m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);

    if (det.abs() < 1e-18) return null;

    final inv = [
      (m[4] * m[8] - m[5] * m[7]) / det,
      (m[2] * m[7] - m[1] * m[8]) / det,
      (m[1] * m[5] - m[2] * m[4]) / det,
      (m[5] * m[6] - m[3] * m[8]) / det,
      (m[0] * m[8] - m[2] * m[6]) / det,
      (m[2] * m[3] - m[0] * m[5]) / det,
      (m[3] * m[7] - m[4] * m[6]) / det,
      (m[1] * m[6] - m[0] * m[7]) / det,
      (m[0] * m[4] - m[1] * m[3]) / det,
    ];

    return _dinormalkan(inv);
  }

  /// Homografi kuadrat-terkecil dari ≥4 pasangan (DLT, `h33 = 1`).
  ///
  /// ## Kenapa tidak memakai `PindaiLembar._homografi`
  ///
  /// Yang di sana menyelesaikan TEPAT empat pasangan (empat marker sudut).
  /// Jangkar teks memberi puluhan pasangan yang semuanya sedikit berderau, dan
  /// homography dari empat jangkar acak saja akan benar di dekat keempatnya
  /// lalu melenceng di sisi lembar yang lain. Di sini semua inlier ikut
  /// menimbang.
  ///
  /// Koordinat dinormalkan dulu (Hartley: pusat di titik berat, jarak
  /// rata-rata √2). Tanpa itu, piksel foto ribuan dan point halaman ratusan
  /// membuat sistem normalnya bersyarat buruk, dan solusinya bergeser oleh
  /// galat pembulatan — persis di skala yang sedang diukur (≤ 1,5 pt).
  ///
  /// `null` = konfigurasi merosot (titik segaris/berimpit).
  static Homografi? kuadratTerkecil(List<Titik> sumber, List<Titik> tujuan) {
    final n = sumber.length;
    if (n < 4 || tujuan.length != n) return null;

    final ts = _normalisasi(sumber);
    final td = _normalisasi(tujuan);
    if (ts == null || td == null) return null;

    // Persamaan normal AᵀA·h = Aᵀb, 8 unknown.
    final ata = List.generate(8, (_) => List<double>.filled(8, 0));
    final atb = List<double>.filled(8, 0);

    void tambah(List<double> baris, double b) {
      for (var i = 0; i < 8; i++) {
        if (baris[i] == 0) continue;
        for (var j = 0; j < 8; j++) {
          ata[i][j] += baris[i] * baris[j];
        }
        atb[i] += baris[i] * b;
      }
    }

    for (var i = 0; i < n; i++) {
      final s = _terapkanAfin(ts, sumber[i]);
      final d = _terapkanAfin(td, tujuan[i]);

      tambah([s.x, s.y, 1, 0, 0, 0, -d.x * s.x, -d.x * s.y], d.x);
      tambah([0, 0, 0, s.x, s.y, 1, -d.y * s.x, -d.y * s.y], d.y);
    }

    final h = _selesaikan(ata, atb);
    if (h == null) return null;

    final hn = [...h, 1.0];

    // H = Td⁻¹ · Hn · Ts
    final tdInv = _inversAfin(td);
    final hasil = _kali(_kali(tdInv, hn), ts);

    return _dinormalkan(hasil);
  }

  static Homografi? _dinormalkan(List<double> m) {
    if (m[8].abs() < 1e-18) return null;
    if (m.any((v) => !v.isFinite)) return null;

    return Homografi([for (final v in m) v / m[8]]);
  }

  /// Matriks afin 3×3 (baris-mayor) yang memindah titik berat ke asal dan
  /// menyetel jarak rata-rata ke √2.
  static List<double>? _normalisasi(List<Titik> p) {
    var cx = 0.0;
    var cy = 0.0;
    for (final t in p) {
      cx += t.x;
      cy += t.y;
    }
    cx /= p.length;
    cy /= p.length;

    var jarak = 0.0;
    for (final t in p) {
      jarak += math.sqrt(math.pow(t.x - cx, 2) + math.pow(t.y - cy, 2));
    }
    jarak /= p.length;
    if (jarak < 1e-12) return null;

    final s = math.sqrt2 / jarak;

    return [s, 0, -s * cx, 0, s, -s * cy, 0, 0, 1];
  }

  static Titik _terapkanAfin(List<double> t, Titik p) =>
      (x: t[0] * p.x + t[1] * p.y + t[2], y: t[3] * p.x + t[4] * p.y + t[5]);

  static List<double> _inversAfin(List<double> t) {
    // t = [s, 0, a, 0, s, b, 0, 0, 1]
    final s = t[0];

    return [1 / s, 0, -t[2] / s, 0, 1 / s, -t[5] / s, 0, 0, 1];
  }

  static List<double> _kali(List<double> a, List<double> b) => [
    for (var i = 0; i < 3; i++)
      for (var j = 0; j < 3; j++)
        a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j],
  ];

  /// Eliminasi Gauss berpivot parsial. `null` = matriks singular.
  static List<double>? _selesaikan(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = [
      for (var i = 0; i < n; i++) [...a[i], b[i]],
    ];

    for (var k = 0; k < n; k++) {
      var pivot = k;
      for (var i = k + 1; i < n; i++) {
        if (m[i][k].abs() > m[pivot][k].abs()) pivot = i;
      }
      if (m[pivot][k].abs() < 1e-12) return null;

      final tukar = m[k];
      m[k] = m[pivot];
      m[pivot] = tukar;

      for (var i = k + 1; i < n; i++) {
        final f = m[i][k] / m[k][k];
        if (f == 0) continue;
        for (var j = k; j <= n; j++) {
          m[i][j] -= f * m[k][j];
        }
      }
    }

    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var s = m[i][n];
      for (var j = i + 1; j < n; j++) {
        s -= m[i][j] * x[j];
      }
      x[i] = s / m[i][i];
    }

    return x;
  }
}

/// Hasil penyelarasan foto ke halaman formulir.
class HasilRegistrasi {
  const HasilRegistrasi({
    required this.fotoKeTemplate,
    required this.templateKeFoto,
    required this.inlier,
    required this.residualPt,
    required this.kuadran,
  });

  /// Piksel foto → point halaman.
  final Homografi fotoKeTemplate;

  /// Point halaman → piksel foto (dipakai meratakan).
  final Homografi templateKeFoto;

  /// Jangkar yang dipakai, SATU per indeks template — ini yang dikirim sebagai
  /// `geometri.jangkar_cocok`.
  final List<CalonJangkar> inlier;

  /// RATA-RATA jarak (point) antara pusat jangkar template dan pusat kata di
  /// foto yang diproyeksikan ke halaman, atas [inlier]. Rata-rata, bukan RMS
  /// — sama dengan `residual_reproyeksi_px` jalur marker. Server yang menilai.
  final double residualPt;

  /// Jumlah inlier per kuadran (urutan [kuadranKotak]).
  final List<int> kuadran;

  bool get menyebar => kuadran.every((n) => n > 0);
}

/// Pencocok jangkar teks + homography RANSAC.
///
/// ## Alurnya
///
///  1. **Calon**: tiap tulisan cetak template yang teksnya UNIK (setelah
///     [normalisasiJangkar]) dipasangkan ke kata di foto yang teksnya sama.
///     Teks kembar (`Name`×5, `4.00`×2) tidak dipakai: memasangkannya berarti
///     menebak yang mana, dan tebakan salah = homography yang salah.
///  2. **RANSAC**: ambil 4 calon acak berindeks beda → homography → hitung
///     berapa calon lain yang jatuh ≤ [ambangInlierPt] dari tempatnya. Yang
///     terbanyak menang. Benihnya tetap, jadi foto yang sama selalu memberi
///     jawaban yang sama — penting buat audit.
///  3. **Perhalus**: kuadrat-terkecil atas semua inlier, ulang sampai
///     himpunannya stabil.
///
/// Syarat lulus (≥8 inlier, keempat kuadran) dinilai PEMANGGIL, dengan angka
/// yang sama dengan server — kelas ini cuma mengukur.
class RegistrasiJangkarTeks {
  const RegistrasiJangkarTeks({
    this.ambangInlierPt = 3.0,
    this.iterasi = 1500,
    this.benih = 20261009,
    this.maksKembarDiFoto = 3,
  });

  /// Jarak maksimum (point halaman) supaya satu pasangan dihitung cocok.
  ///
  /// 3 pt ≈ sepertujuh tinggi satu baris tabel pH (≈22 pt): cukup longgar buat
  /// derau kotak kata ML Kit vs kotak kata PDF, cukup ketat supaya kata yang
  /// salah pasang (beda baris) tidak lolos. Ambang VONIS tetap milik server
  /// (`ocr.geometri.jangkar_teks.residual_maks_pt`).
  final double ambangInlierPt;

  final int iterasi;
  final int benih;

  /// Satu jangkar template yang teksnya muncul lebih dari ini di foto
  /// dilewati — terlalu banyak kemungkinan untuk dipercaya.
  final int maksKembarDiFoto;

  /// Pasangan calon. [halamanPt] = ukuran halaman template dalam point.
  List<CalonJangkar> calon({
    required List<JangkarTeks> jangkar,
    required ({double w, double h}) halamanPt,
    required List<TeksTerbaca> terbaca,
  }) {
    final hitungTemplate = <String, int>{};
    for (final j in jangkar) {
      final t = normalisasiJangkar(j.teks);
      if (t.isEmpty) continue;
      hitungTemplate[t] = (hitungTemplate[t] ?? 0) + 1;
    }

    final fotoPerTeks = <String, List<TeksTerbaca>>{};
    for (final e in terbaca) {
      final t = normalisasiJangkar(e.teks);
      if (t.isEmpty || hitungTemplate[t] != 1) continue;
      (fotoPerTeks[t] ??= []).add(e);
    }

    final hasil = <CalonJangkar>[];

    for (var i = 0; i < jangkar.length; i++) {
      final j = jangkar[i];
      final t = normalisasiJangkar(j.teks);
      if (hitungTemplate[t] != 1) continue;

      final cocok = fotoPerTeks[t] ?? const <TeksTerbaca>[];
      if (cocok.isEmpty || cocok.length > maksKembarDiFoto) continue;

      final k = j.kotak;
      final template = (
        x: (k.x + k.w / 2) * halamanPt.w,
        y: (k.y + k.h / 2) * halamanPt.h,
      );

      for (final e in cocok) {
        hasil.add((
          indeks: i,
          teksMentah: e.teks,
          foto: (x: e.kotak.center.dx, y: e.kotak.center.dy),
          template: template,
          kuadran: kuadranKotak(k),
        ));
      }
    }

    return hasil;
  }

  /// Homography terbaik dari [calon], atau `null` kalau tidak ada hipotesis
  /// yang didukung ≥4 jangkar.
  HasilRegistrasi? cocokkan(List<CalonJangkar> calon) {
    final perIndeks = <int, List<CalonJangkar>>{};
    for (final c in calon) {
      (perIndeks[c.indeks] ??= []).add(c);
    }

    final indeks = perIndeks.keys.toList()..sort();
    if (indeks.length < 4) return null;

    final acak = math.Random(benih);
    var terbaik = <({CalonJangkar c, double galat})>[];
    var galatTerbaik = double.infinity;

    for (var it = 0; it < iterasi; it++) {
      final pilih = <int>{};
      while (pilih.length < 4) {
        pilih.add(indeks[acak.nextInt(indeks.length)]);
      }

      final sampel = [
        for (final i in pilih)
          perIndeks[i]![acak.nextInt(perIndeks[i]!.length)],
      ];

      if (_segaris([for (final s in sampel) s.template]) ||
          _segaris([for (final s in sampel) s.foto])) {
        continue;
      }

      final h = Homografi.kuadratTerkecil(
        [for (final s in sampel) s.foto],
        [for (final s in sampel) s.template],
      );
      if (h == null || !_wajar(h, [for (final s in sampel) s.foto])) continue;

      final inlier = _inlier(h, perIndeks);
      final galat = inlier.fold(0.0, (a, b) => a + b.galat);

      if (inlier.length > terbaik.length ||
          (inlier.length == terbaik.length && galat < galatTerbaik)) {
        terbaik = inlier;
        galatTerbaik = galat;
      }
    }

    if (terbaik.length < 4) return null;

    // Perhalus: kuadrat-terkecil atas seluruh inlier, ulang sampai stabil.
    Homografi? h;
    var inlier = terbaik;

    for (var putaran = 0; putaran < 5; putaran++) {
      final baru = Homografi.kuadratTerkecil(
        [for (final i in inlier) i.c.foto],
        [for (final i in inlier) i.c.template],
      );
      if (baru == null || !_wajar(baru, [for (final i in inlier) i.c.foto])) {
        break;
      }

      final ulang = _inlier(baru, perIndeks);
      if (ulang.length < 4) break;

      h = baru;
      final sama =
          ulang.length == inlier.length &&
          ulang.every((u) => inlier.any((i) => i.c == u.c));
      inlier = ulang;
      if (sama) break;
    }

    if (h == null) return null;

    final balik = h.invers();
    if (balik == null) return null;

    final kuadran = List<int>.filled(4, 0);
    for (final i in inlier) {
      kuadran[i.c.kuadran]++;
    }

    return HasilRegistrasi(
      fotoKeTemplate: h,
      templateKeFoto: balik,
      inlier: [for (final i in inlier) i.c],
      residualPt: inlier.fold(0.0, (a, b) => a + b.galat) / inlier.length,
      kuadran: kuadran,
    );
  }

  /// Inlier [h]: per indeks template, calon dengan galat terkecil — dan cuma
  /// kalau galatnya ≤ ambang. Satu indeks tidak pernah dihitung dua kali
  /// (server menolak indeks kembar).
  List<({CalonJangkar c, double galat})> _inlier(
    Homografi h,
    Map<int, List<CalonJangkar>> perIndeks,
  ) {
    final hasil = <({CalonJangkar c, double galat})>[];

    for (final daftar in perIndeks.values) {
      CalonJangkar? pilih;
      var galatPilih = double.infinity;

      for (final c in daftar) {
        if (h.penyebut(c.foto) <= 0) continue;

        final p = h.terapkan(c.foto);
        if (p == null) continue;

        final galat = math.sqrt(
          math.pow(p.x - c.template.x, 2) + math.pow(p.y - c.template.y, 2),
        );
        if (galat < galatPilih) {
          galatPilih = galat;
          pilih = c;
        }
      }

      if (pilih != null && galatPilih <= ambangInlierPt) {
        hasil.add((c: pilih, galat: galatPilih));
      }
    }

    return hasil;
  }

  /// Hipotesis yang secara fisik mustahil untuk selembar kertas: bidangnya
  /// terlipat lewat tak hingga di antara titik-titiknya, atau tercermin.
  static bool _wajar(Homografi h, List<Titik> foto) {
    for (final p in foto) {
      if (h.penyebut(p) <= 0) return false;
      if (h.determinanJacobian(p) <= 0) return false;
    }

    return true;
  }

  /// Ada tiga dari [p] yang (hampir) segaris? Homography dari sampel begitu
  /// tidak terdefinisi dengan baik, dan inlier yang "mendukungnya" kebetulan.
  static bool _segaris(List<Titik> p) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final t in p) {
      minX = math.min(minX, t.x);
      minY = math.min(minY, t.y);
      maxX = math.max(maxX, t.x);
      maxY = math.max(maxY, t.y);
    }
    final diag2 = math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2);
    if (diag2 < 1e-9) return true;

    for (var a = 0; a < p.length; a++) {
      for (var b = a + 1; b < p.length; b++) {
        for (var c = b + 1; c < p.length; c++) {
          final silang =
              (p[b].x - p[a].x) * (p[c].y - p[a].y) -
              (p[b].y - p[a].y) * (p[c].x - p[a].x);
          if (silang.abs() < 0.01 * diag2) return true;
        }
      }
    }

    return false;
  }
}

/// Ratakan foto ke halaman formulir: kanvas `halamanPt × skala` piksel,
/// dipetakan MUNDUR (tiap piksel tujuan mencari asalnya di foto) dengan
/// interpolasi bilinear.
///
/// ## Kenapa bilinear, bukan tetangga terdekat seperti `PindaiLembar.warp`
///
/// Foto lembar penuh biasanya ~4–5 px/pt, kanvas ini 3 px/pt: gambarnya
/// DIKECILKAN. Tetangga terdekat yang mengecilkan membuang piksel, dan goresan
/// pulpen yang tipis bisa hilang sebagian — angka `1` jadi putus, `8` jadi `0`.
/// Bilinear menimbang empat tetangga, jadi goresan tipis tetap meninggalkan
/// jejak.
///
/// Dikerjakan langsung di bita mentah (bukan `getPixel`) — kanvas formulir
/// Letter lanskap di 3 px/pt itu 4,4 juta piksel, dan objek per piksel membuat
/// HP berhenti beberapa detik.
///
/// Piksel yang jatuh di luar foto diputihkan: "di luar kertas" = putih, sama
/// alasannya dengan `PindaiLembar.warp`.
img.Image ratakanHalaman(
  img.Image foto,
  Homografi templateKeFoto, {
  required ({double w, double h}) halamanPt,
  required double skala,
}) {
  final lebar = (halamanPt.w * skala).round();
  final tinggi = (halamanPt.h * skala).round();

  final sumber =
      foto.format == img.Format.uint8 &&
          foto.numChannels == 3 &&
          !foto.hasPalette
      ? foto
      : foto.convert(format: img.Format.uint8, numChannels: 3);

  final sb = sumber.toUint8List();
  final sw = sumber.width;
  final sh = sumber.height;
  final strideS = sumber.rowStride;

  final hasil = img.Image(width: lebar, height: tinggi);
  final hb = hasil.toUint8List();
  final strideH = hasil.rowStride;

  // Skala per sumbu dari ukuran kanvas yang SUDAH dibulatkan — pembulatan
  // lebar/tinggi tidak boleh menggeser kotak di sisi kanan/bawah.
  final sx = lebar / halamanPt.w;
  final sy = tinggi / halamanPt.h;
  final m = templateKeFoto.m;

  for (var y = 0; y < tinggi; y++) {
    final ty = (y + 0.5) / sy;
    var o = y * strideH;

    for (var x = 0; x < lebar; x++, o += 3) {
      final tx = (x + 0.5) / sx;
      final w = m[6] * tx + m[7] * ty + m[8];

      double px = -1;
      double py = -1;
      if (w.abs() > 1e-12) {
        px = (m[0] * tx + m[1] * ty + m[2]) / w - 0.5;
        py = (m[3] * tx + m[4] * ty + m[5]) / w - 0.5;
      }

      if (px < 0 || py < 0 || px > sw - 1 || py > sh - 1) {
        hb[o] = 255;
        hb[o + 1] = 255;
        hb[o + 2] = 255;
        continue;
      }

      final x0 = px.floor();
      final y0 = py.floor();
      final x1 = x0 + 1 < sw ? x0 + 1 : x0;
      final y1 = y0 + 1 < sh ? y0 + 1 : y0;
      final fx = px - x0;
      final fy = py - y0;

      final a = y0 * strideS + x0 * 3;
      final b = y0 * strideS + x1 * 3;
      final c = y1 * strideS + x0 * 3;
      final d = y1 * strideS + x1 * 3;

      for (var k = 0; k < 3; k++) {
        final atas = sb[a + k] + (sb[b + k] - sb[a + k]) * fx;
        final bawah = sb[c + k] + (sb[d + k] - sb[c + k]) * fx;
        hb[o + k] = (atas + (bawah - atas) * fy).round().clamp(0, 255);
      }
    }
  }

  return hasil;
}

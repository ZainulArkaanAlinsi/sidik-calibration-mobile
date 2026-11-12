// Pembangkit foto SINTETIS lembar di atas meja, Dart murni (paket `image`),
// untuk menguji page registration. BUKAN tulisan teknisi: halaman digambar
// prosedural (bingkai, tabel, label cetak, coretan), lalu "difoto" dengan
// kamera lubang-jarum fisik (rotasi, tilt, perspektif) dan degradasi (cahaya
// tak rata, bayangan tangan, bayangan tepi kertas, blur, derau, JPEG).
//
// Deterministik: seed yang sama = foto yang sama persis, jadi angka di
// laporan bisa diulang.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/registrasi_halaman/geometri_halaman.dart'
    show TitikHalaman;

/// Kotak dalam point halaman (asal kiri-atas, y ke bawah).
class KotakPt {
  const KotakPt(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;
}

enum JenisAlas {
  /// Meja gelap-sedang (RGB ~35–95), seperti latar prototipe.
  gelap,

  /// Meja sedang abu/biru/hijau (RGB ~100–150).
  sedang,

  /// Kayu muda/krem berurat (RGB ~190–215, kuning): terang, tetapi berwarna.
  kayuTerang,

  /// Krem pucat (RGB ~225–235): hampir sama terang dengan kertas.
  krem,

  /// Putih (RGB ~240–250): praktis tak bisa dipisahkan dari kertas.
  putih,
}

class SpesifikasiFoto {
  const SpesifikasiFoto({
    required this.seed,
    this.halamanPt = (w: 612.0, h: 792.0),
    this.lebarFoto = 1008,
    this.tinggiFoto = 756,
    this.alas = JenisAlas.gelap,
    this.rollDeg = 0,
    this.pitchDeg = 0,
    this.yawDeg = 0,
    this.isi = 0.8,
    this.geserX = 0,
    this.geserY = 0,
    this.fRel = 0.85,
    this.gradienCahaya = 0.15,
    this.bayanganTangan = 0,
    this.blurPx = 0.4,
    this.noise = 4,
    this.jpegQ = 80,
    this.bersih = false,
    this.lengkung = 0,
    this.tanganTepi = false,
    this.homografi,
    this.sel,
    this.warnaAlas,
  });

  final int seed;
  final ({double w, double h}) halamanPt;
  final int lebarFoto;
  final int tinggiFoto;
  final JenisAlas alas;

  /// Putaran dalam bidang foto, tilt (sumbu x kamera), dan yaw (sumbu y).
  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;

  /// Pecahan sisi foto yang diisi halaman (0,5–0,9).
  final double isi;

  /// Geser halaman dalam sisa ruang, -1..1.
  final double geserX;
  final double geserY;

  /// Jarak fokus / sisi terpanjang foto.
  final double fRel;

  /// 0..0,5 — redup di satu sisi foto.
  final double gradienCahaya;

  /// 0..0,5 — pita gelap lembut melintang (bayangan tangan/ponsel).
  final double bayanganTangan;

  /// Sigma blur Gaussian, piksel foto.
  final double blurPx;

  /// Sigma derau sensor, tingkat abu.
  final double noise;
  final int jpegQ;

  /// Tanpa cahaya, blur, derau, JPEG, bayangan — untuk uji warp piksel.
  final bool bersih;

  /// Kertas melengkung: tepi kiri/kanan menggembung sebesar pecahan ini dari
  /// lebar halaman di tengah tinggi (0,02 = 2%).
  final double lengkung;

  /// Bercak berwarna kulit (lebih terang dari ambang) menempel di salah satu
  /// tepi: separuh di atas kertas, separuh di alas.
  final bool tanganTepi;

  /// Ganti kamera fisik dengan homografi point-halaman → piksel-foto (9
  /// angka baris-mayor), mis. dari kunci jawaban prototipe.
  final List<double>? homografi;
  final List<KotakPt>? sel;
  final (int, int, int)? warnaAlas;
}

class FotoSintetis {
  const FotoSintetis({
    required this.foto,
    required this.homografi,
    required this.sudutBenar,
    required this.sel,
    required this.halamanPt,
    required this.raster,
    required this.rasterW,
    required this.rasterH,
    required this.pxPerPt,
  });

  final img.Image foto;

  /// Point halaman → piksel foto (9 angka baris-mayor).
  final List<double> homografi;

  /// Sudut halaman di foto, urutan kiri-atas, kanan-atas, kanan-bawah,
  /// kiri-bawah.
  final List<TitikHalaman> sudutBenar;
  final List<KotakPt> sel;
  final ({double w, double h}) halamanPt;

  /// Halaman bersih (skala abu 0–255) untuk membandingkan hasil warp.
  final Uint8List raster;
  final int rasterW;
  final int rasterH;
  final double pxPerPt;

  double get diagonalFoto => math.sqrt(
    math.pow(foto.width, 2).toDouble() + math.pow(foto.height, 2).toDouble(),
  );
}

// ---------------------------------------------------------------------------
// Matriks 3×3
// ---------------------------------------------------------------------------

List<double> invers3(List<double> m) {
  final det =
      m[0] * (m[4] * m[8] - m[5] * m[7]) -
      m[1] * (m[3] * m[8] - m[5] * m[6]) +
      m[2] * (m[3] * m[7] - m[4] * m[6]);

  return [
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
}

List<double> kali3(List<double> a, List<double> b) => [
  for (var i = 0; i < 3; i++)
    for (var j = 0; j < 3; j++)
      a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j],
];

/// Homografi tepat dari empat pasangan titik (`h33 = 1`), baris-mayor;
/// `null` bila merosot. Pembanding independen atas `Homografi` di app.
List<double>? homografiDari4(
  List<TitikHalaman> sumber,
  List<TitikHalaman> tujuan,
) {
  final a = [for (var i = 0; i < 8; i++) List<double>.filled(9, 0.0)];
  for (var i = 0; i < 4; i++) {
    final s = sumber[i];
    final t = tujuan[i];
    a[2 * i] = [s.x, s.y, 1, 0, 0, 0, -t.x * s.x, -t.x * s.y, t.x];
    a[2 * i + 1] = [0, 0, 0, s.x, s.y, 1, -t.y * s.x, -t.y * s.y, t.y];
  }
  for (var k = 0; k < 8; k++) {
    var pivot = k;
    for (var i = k + 1; i < 8; i++) {
      if (a[i][k].abs() > a[pivot][k].abs()) pivot = i;
    }
    if (a[pivot][k].abs() < 1e-12) return null;
    final tukar = a[k];
    a[k] = a[pivot];
    a[pivot] = tukar;
    for (var i = 0; i < 8; i++) {
      if (i == k) continue;
      final f = a[i][k] / a[k][k];
      for (var j = k; j < 9; j++) {
        a[i][j] -= f * a[k][j];
      }
    }
  }

  return [for (var i = 0; i < 8; i++) a[i][8] / a[i][i], 1.0];
}

TitikHalaman proyeksi(List<double> m, double x, double y) {
  final w = m[6] * x + m[7] * y + m[8];

  return (
    x: (m[0] * x + m[1] * y + m[2]) / w,
    y: (m[3] * x + m[4] * y + m[5]) / w,
  );
}

// ---------------------------------------------------------------------------
// Kamera lubang-jarum
// ---------------------------------------------------------------------------

List<double> _putar(double roll, double pitch, double yaw) {
  final cr = math.cos(roll), sr = math.sin(roll);
  final cp = math.cos(pitch), sp = math.sin(pitch);
  final cy = math.cos(yaw), sy = math.sin(yaw);
  final rz = [cr, -sr, 0.0, sr, cr, 0.0, 0.0, 0.0, 1.0];
  final rx = [1.0, 0.0, 0.0, 0.0, cp, -sp, 0.0, sp, cp];
  final ry = [cy, 0.0, sy, 0.0, 1.0, 0.0, -sy, 0.0, cy];

  return kali3(rz, kali3(rx, ry));
}

/// Homografi point-halaman → piksel dari kamera lubang-jarum. Jarak kamera
/// dicari sampai halaman memenuhi [SpesifikasiFoto.isi] sisi foto.
List<double> homografiKamera(SpesifikasiFoto s) {
  final w = s.halamanPt.w;
  final h = s.halamanPt.h;
  final fw = s.lebarFoto.toDouble();
  final fh = s.tinggiFoto.toDouble();
  final cx = fw / 2;
  final cy = fh / 2;
  final f = s.fRel * math.max(fw, fh);
  final r = _putar(
    s.rollDeg * math.pi / 180,
    s.pitchDeg * math.pi / 180,
    s.yawDeg * math.pi / 180,
  );
  // Kolom r1, r2 (sumbu x,y halaman di ruang kamera).
  final r1 = [r[0], r[3], r[6]];
  final r2 = [r[1], r[4], r[7]];

  List<double> bentuk(double d) {
    final tx = -(w / 2) * r1[0] - (h / 2) * r2[0];
    final ty = -(w / 2) * r1[1] - (h / 2) * r2[1];
    final tz = d - (w / 2) * r1[2] - (h / 2) * r2[2];
    // K · [r1 r2 t']
    return [
      f * r1[0] + cx * r1[2],
      f * r2[0] + cx * r2[2],
      f * tx + cx * tz,
      f * r1[1] + cy * r1[2],
      f * r2[1] + cy * r2[2],
      f * ty + cy * tz,
      r1[2],
      r2[2],
      tz,
    ];
  }

  var d = f * math.max(w, h) / (s.isi * math.min(fw, fh));
  for (var i = 0; i < 25; i++) {
    final m = bentuk(d);
    var ex = 0.0;
    var ey = 0.0;
    for (final p in [(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)]) {
      final q = proyeksi(m, p.$1, p.$2);
      ex = math.max(ex, (q.x - cx).abs());
      ey = math.max(ey, (q.y - cy).abs());
    }
    final skala = math.max(ex / (s.isi * fw / 2), ey / (s.isi * fh / 2));
    if ((skala - 1).abs() < 1e-4) break;
    d *= skala;
  }

  var m = bentuk(d);
  // Geser dalam sisa ruang (pergeseran bidang citra).
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in [(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)]) {
    final q = proyeksi(m, p.$1, p.$2);
    minX = math.min(minX, q.x);
    maxX = math.max(maxX, q.x);
    minY = math.min(minY, q.y);
    maxY = math.max(maxY, q.y);
  }
  final margin = 0.04;
  final longgarKiri = minX - margin * fw;
  final longgarKanan = fw * (1 - margin) - maxX;
  final longgarAtas = minY - margin * fh;
  final longgarBawah = fh * (1 - margin) - maxY;
  final dx = s.geserX >= 0
      ? s.geserX * math.max(0, longgarKanan)
      : s.geserX * math.max(0, longgarKiri);
  final dy = s.geserY >= 0
      ? s.geserY * math.max(0, longgarBawah)
      : s.geserY * math.max(0, longgarAtas);
  m = kali3([1, 0, dx, 0, 1, dy, 0, 0, 1], m);

  return m;
}

// ---------------------------------------------------------------------------
// Halaman prosedural
// ---------------------------------------------------------------------------

class _Raster {
  _Raster(this.w, this.h, this.ppp)
    : d = Uint8List(w * h)..fillRange(0, w * h, 255);

  final int w;
  final int h;
  final double ppp;
  final Uint8List d;

  void isiKotak(double x, double y, double lebar, double tinggi, int nilai) {
    final x0 = (x * ppp).floor().clamp(0, w);
    final x1 = ((x + lebar) * ppp).ceil().clamp(0, w);
    final y0 = (y * ppp).floor().clamp(0, h);
    final y1 = ((y + tinggi) * ppp).ceil().clamp(0, h);
    for (var yy = y0; yy < y1; yy++) {
      d.fillRange(yy * w + x0, yy * w + x1, nilai);
    }
  }

  void garisKotak(KotakPt k, double tebal, int nilai) {
    isiKotak(k.x - tebal / 2, k.y - tebal / 2, k.w + tebal, tebal, nilai);
    isiKotak(k.x - tebal / 2, k.y + k.h - tebal / 2, k.w + tebal, tebal, nilai);
    isiKotak(k.x - tebal / 2, k.y - tebal / 2, tebal, k.h + tebal, nilai);
    isiKotak(k.x + k.w - tebal / 2, k.y - tebal / 2, tebal, k.h + tebal, nilai);
  }

  void goresan(math.Random rng, KotakPt k, int nilai) {
    // Poligaris acak di dalam kotak: menyerupai angka tulisan tangan.
    var x = k.x + k.w * rng.nextDouble() * 0.2 + 3;
    var y = k.y + k.h * (0.3 + 0.4 * rng.nextDouble());
    final n = 5 + rng.nextInt(7);
    for (var i = 0; i < n; i++) {
      final nx = (x + k.w * 0.08 * (0.5 + rng.nextDouble())).clamp(
        k.x + 2,
        k.x + k.w - 2,
      );
      final ny = (k.y + k.h * (0.2 + 0.6 * rng.nextDouble())).clamp(
        k.y + 2,
        k.y + k.h - 2,
      );
      final langkah = 6;
      for (var t = 0; t <= langkah; t++) {
        final px = x + (nx - x) * t / langkah;
        final py = y + (ny - y) * t / langkah;
        isiKotak(px - 0.7, py - 0.7, 1.4, 1.4, nilai);
      }
      x = nx;
      y = ny;
    }
  }
}

({List<KotakPt> sel, _Raster raster}) _gambarHalaman(
  double wPt,
  double hPt,
  List<KotakPt>? selDiberikan,
  math.Random rng,
) {
  const ppp = 1.5;
  final r = _Raster((wPt * ppp).ceil(), (hPt * ppp).ceil(), ppp);
  final margin = 0.04 * math.min(wPt, hPt);

  // Bingkai luar + kop berarsir.
  r.garisKotak(
    KotakPt(margin, margin, wPt - 2 * margin, hPt - 2 * margin),
    1.6,
    25,
  );
  r.isiKotak(margin + 1, margin + 1, wPt - 2 * margin - 2, 0.07 * hPt, 215);
  r.isiKotak(margin + 12, margin + 10, wPt * 0.18, 0.035 * hPt, 40); // "logo"
  for (var i = 0; i < 4; i++) {
    r.isiKotak(
      wPt * 0.36,
      margin + 10 + i * 0.016 * hPt,
      wPt * (0.2 + 0.2 * rng.nextDouble()),
      3,
      60,
    );
  }

  final sel = <KotakPt>[];
  if (selDiberikan != null) {
    sel.addAll(selDiberikan);
  } else {
    // Tabel: kolom berbobot acak, baris 18–28 pt.
    final kolom = 3 + rng.nextInt(4);
    final bobot = [for (var i = 0; i < kolom; i++) 0.6 + rng.nextDouble()];
    final jumlah = bobot.reduce((a, b) => a + b);
    final tinggiBaris = 18 + rng.nextDouble() * 10;
    final kiri = margin + 8;
    final lebarTabel = wPt - 2 * margin - 16;
    var y = margin + 0.1 * hPt;
    while (y + tinggiBaris < hPt - margin - 8) {
      var x = kiri;
      for (var c = 0; c < kolom; c++) {
        final lebar = lebarTabel * bobot[c] / jumlah;
        sel.add(KotakPt(x, y, lebar, tinggiBaris));
        x += lebar;
      }
      y += tinggiBaris;
    }
  }

  for (final k in sel) {
    r.garisKotak(k, 0.9, 35);
    if (rng.nextDouble() < 0.5) {
      r.isiKotak(k.x + 3, k.y + 3, k.w * (0.2 + 0.3 * rng.nextDouble()), 3, 90);
    } else if (rng.nextDouble() < 0.7) {
      r.goresan(rng, k, 45);
    }
  }
  // Teks cetak di luar tabel.
  for (var i = 0; i < 12; i++) {
    r.isiKotak(
      margin + 8 + rng.nextDouble() * wPt * 0.5,
      hPt - margin - 8 - rng.nextDouble() * 4,
      wPt * (0.1 + 0.2 * rng.nextDouble()),
      2.5,
      80,
    );
  }

  return (sel: sel, raster: r);
}

// ---------------------------------------------------------------------------
// Foto
// ---------------------------------------------------------------------------

({double r, double g, double b}) _warnaAlasDasar(
  SpesifikasiFoto s,
  math.Random rng,
) {
  if (s.warnaAlas != null) {
    final c = s.warnaAlas!;
    return (r: c.$1.toDouble(), g: c.$2.toDouble(), b: c.$3.toDouble());
  }
  double u(double a, double b) => a + (b - a) * rng.nextDouble();
  switch (s.alas) {
    case JenisAlas.gelap:
      final v = u(35, 95);
      return (r: v * u(0.85, 1.15), g: v * u(0.85, 1.15), b: v * u(0.85, 1.2));
    case JenisAlas.sedang:
      final v = u(100, 150);
      return (r: v * u(0.85, 1.1), g: v * u(0.9, 1.1), b: v * u(0.9, 1.15));
    case JenisAlas.kayuTerang:
      return (r: u(195, 220), g: u(160, 185), b: u(105, 140));
    case JenisAlas.krem:
      return (r: u(228, 236), g: u(220, 228), b: u(195, 210));
    case JenisAlas.putih:
      final v = u(238, 250);
      return (r: v, g: v - 1, b: v - 3);
  }
}

FotoSintetis hasilkanFotoSintetis(SpesifikasiFoto s) {
  final rng = math.Random(s.seed);
  final w = s.halamanPt.w;
  final h = s.halamanPt.h;
  final fw = s.lebarFoto;
  final fh = s.tinggiFoto;

  final halaman = _gambarHalaman(w, h, s.sel, rng);
  final raster = halaman.raster;
  final hm = s.homografi ?? homografiKamera(s);
  final inv = invers3(hm);

  final sudut = [
    proyeksi(hm, 0, 0),
    proyeksi(hm, w, 0),
    proyeksi(hm, w, h),
    proyeksi(hm, 0, h),
  ];
  double jarak(TitikHalaman a, TitikHalaman b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  final spp =
      (jarak(sudut[0], sudut[1]) / w + jarak(sudut[0], sudut[3]) / h) / 2;

  final alasDasar = _warnaAlasDasar(s, rng);
  final kertas = (r: 244.0, g: 241.0, b: 234.0);
  final teta = rng.nextDouble() * 2 * math.pi;
  final pita = rng.nextDouble() * 0.6 + 0.2;
  final tetaPita = teta + 1.2;
  final diagSetengah = math.sqrt(fw * fw / 4 + fh * fh / 4);
  final cosTeta = math.cos(teta);
  final sinTeta = math.sin(teta);
  final cosPita = math.cos(tetaPita);
  final sinPita = math.sin(tetaPita);
  final duaSigmaPita2 = 2 * math.pow(fw * 0.12, 2).toDouble();
  final skalaSombra = 0.012 * fw;

  // Derau frekuensi rendah untuk alas.
  final gx = fw ~/ 40 + 2;
  final gy = fh ~/ 40 + 2;
  final grid = [for (var i = 0; i < gx * gy; i++) rng.nextDouble() * 2 - 1];
  final arahUrat = rng.nextDouble() * math.pi;
  final frekUrat = 0.04 + 0.06 * rng.nextDouble();
  final cosUrat = math.cos(arahUrat);
  final sinUrat = math.sin(arahUrat);

  // Bercak "tangan" di salah satu tepi.
  var tanganX = 0.0;
  var tanganY = 0.0;
  var tanganR = 0.0;
  if (s.tanganTepi) {
    final sisi = rng.nextInt(4);
    final a = sudut[sisi];
    final b = sudut[(sisi + 1) % 4];
    final mx = (a.x + b.x) / 2;
    final my = (a.y + b.y) / 2;
    final cx = sudut.map((p) => p.x).reduce((p, q) => p + q) / 4;
    final cy = sudut.map((p) => p.y).reduce((p, q) => p + q) / 4;
    final jr = math.sqrt((mx - cx) * (mx - cx) + (my - cy) * (my - cy));
    tanganR =
        0.10 * (jarak(sudut[0], sudut[2]) + jarak(sudut[1], sudut[3])) / 2;
    tanganX = mx + (mx - cx) / jr * 0.3 * tanganR;
    tanganY = my + (my - cy) / jr * 0.3 * tanganR;
  }

  final rCh = Float32List(fw * fh);
  final gCh = Float32List(fw * fh);
  final bCh = Float32List(fw * fh);

  for (var py = 0; py < fh; py++) {
    for (var px = 0; px < fw; px++) {
      final x = px + 0.5;
      final y = py + 0.5;
      final wd = inv[6] * x + inv[7] * y + inv[8];
      var X = (inv[0] * x + inv[1] * y + inv[2]) / wd;
      final Y = (inv[3] * x + inv[4] * y + inv[5]) / wd;
      if (s.lengkung != 0) {
        final r = Y / h;
        final g = s.lengkung * 4 * r * (1 - r);
        X = w / 2 + (X - w / 2) / (1 + 2 * g);
      }

      // Alas.
      final gu = x / 40;
      final gv = y / 40;
      final iu = gu.floor();
      final iv = gv.floor();
      final fu = gu - iu;
      final fv = gv - iv;
      double g(int a, int b) => grid[(b * gx + a)];
      final noiseRendah =
          (g(iu, iv) * (1 - fu) + g(iu + 1, iv) * fu) * (1 - fv) +
          (g(iu, iv + 1) * (1 - fu) + g(iu + 1, iv + 1) * fu) * fv;
      var ar = alasDasar.r + 6 * noiseRendah;
      var ag = alasDasar.g + 6 * noiseRendah;
      var ab = alasDasar.b + 6 * noiseRendah;
      if (s.alas == JenisAlas.kayuTerang) {
        final urat = math.sin(
          2 * math.pi * frekUrat * (x * cosUrat + y * sinUrat) +
              3 * noiseRendah,
        );
        final k = 1 + 0.06 * urat;
        ar *= k;
        ag *= k;
        ab *= k;
      }

      // Bayangan tepi kertas di alas.
      final dxl = math.max(0.0, math.max(-X, X - w));
      final dyl = math.max(0.0, math.max(-Y, Y - h));
      final jarakLuar = math.sqrt(dxl * dxl + dyl * dyl) * spp;
      if (!s.bersih && jarakLuar > 0) {
        final sombra = 1 - 0.32 * math.exp(-jarakLuar / skalaSombra);
        ar *= sombra;
        ag *= sombra;
        ab *= sombra;
      }

      // Halaman.
      final dalam = math.min(math.min(X, w - X), math.min(Y, h - Y));
      final alfa = ((0.5 + dalam * spp).clamp(0.0, 1.0)).toDouble();
      var r = ar;
      var gg = ag;
      var b = ab;
      if (alfa > 0) {
        final rx = (X * raster.ppp - 0.5).clamp(0.0, raster.w - 1.0);
        final ry = (Y * raster.ppp - 0.5).clamp(0.0, raster.h - 1.0);
        final x0 = rx.floor();
        final y0 = ry.floor();
        final x1 = math.min(x0 + 1, raster.w - 1);
        final y1 = math.min(y0 + 1, raster.h - 1);
        final fx = rx - x0;
        final fy = ry - y0;
        final d = raster.d;
        final rw = raster.w;
        final v =
            (d[y0 * rw + x0] * (1 - fx) + d[y0 * rw + x1] * fx) * (1 - fy) +
            (d[y1 * rw + x0] * (1 - fx) + d[y1 * rw + x1] * fx) * fy;
        final t = v / 255;
        r = ar + (kertas.r * t - ar) * alfa;
        gg = ag + (kertas.g * t - ag) * alfa;
        b = ab + (kertas.b * t - ab) * alfa;
      }

      if (tanganR > 0) {
        final dx = x - tanganX;
        final dy = y - tanganY;
        final d = math.sqrt(dx * dx + dy * dy);
        final kulit = ((tanganR - d) / 2 + 0.5).clamp(0.0, 1.0);
        if (kulit > 0) {
          r += (205 - r) * kulit;
          gg += (160 - gg) * kulit;
          b += (130 - b) * kulit;
        }
      }

      // Cahaya.
      if (!s.bersih) {
        final proj =
            ((x - fw / 2) * cosTeta + (y - fh / 2) * sinTeta) / diagSetengah;
        var luz = 1 - s.gradienCahaya * (0.5 + 0.5 * proj);
        final r2 =
            ((x - fw / 2) * (x - fw / 2) + (y - fh / 2) * (y - fh / 2)) /
            (diagSetengah * diagSetengah);
        luz *= 1 - 0.2 * r2;
        if (s.bayanganTangan > 0) {
          final jar = (x - fw * pita) * cosPita + (y - fh * 0.5) * sinPita;
          luz *= 1 - s.bayanganTangan * math.exp(-(jar * jar) / duaSigmaPita2);
        }
        r *= luz;
        gg *= luz;
        b *= luz;
      }

      final o = py * fw + px;
      rCh[o] = r;
      gCh[o] = gg;
      bCh[o] = b;
    }
  }

  if (!s.bersih && s.blurPx >= 0.3) {
    for (final c in [rCh, gCh, bCh]) {
      _gauss(c, fw, fh, s.blurPx);
    }
  }

  final foto = img.Image(width: fw, height: fh);
  final bita = foto.toUint8List();
  final stride = foto.rowStride;
  final acak = math.Random(s.seed ^ 0x5bd1e995);
  // Irwin–Hall (jumlah 4 seragam) dinormalkan ke simpangan baku 1: cukup
  // untuk derau sensor dan jauh lebih murah daripada Box–Muller di JIT.
  double gauss() =>
      (acak.nextDouble() +
          acak.nextDouble() +
          acak.nextDouble() +
          acak.nextDouble() -
          2) *
      1.7320508;

  for (var py = 0; py < fh; py++) {
    var o = py * stride;
    for (var px = 0; px < fw; px++, o += 3) {
      final i = py * fw + px;
      final n = s.bersih ? 0.0 : s.noise;
      bita[o] = (rCh[i] + (n > 0 ? gauss() * n : 0)).round().clamp(0, 255);
      bita[o + 1] = (gCh[i] + (n > 0 ? gauss() * n : 0)).round().clamp(0, 255);
      bita[o + 2] = (bCh[i] + (n > 0 ? gauss() * n : 0)).round().clamp(0, 255);
    }
  }

  final akhir = s.bersih
      ? foto
      : img.decodeJpg(
          Uint8List.fromList(img.encodeJpg(foto, quality: s.jpegQ)),
        )!;

  return FotoSintetis(
    foto: akhir,
    homografi: hm,
    sudutBenar: sudut,
    sel: halaman.sel,
    halamanPt: s.halamanPt,
    raster: raster.d,
    rasterW: raster.w,
    rasterH: raster.h,
    pxPerPt: raster.ppp,
  );
}

/// Blur Gaussian separabel di tempat, tepi memantul ke piksel terdekat.
void _gauss(Float32List kanal, int w, int h, double sigma) {
  final radius = (sigma * 3).ceil();
  final inti = Float32List(2 * radius + 1);
  var jumlah = 0.0;
  for (var i = -radius; i <= radius; i++) {
    final v = math.exp(-(i * i) / (2 * sigma * sigma));
    inti[i + radius] = v;
    jumlah += v;
  }
  for (var i = 0; i < inti.length; i++) {
    inti[i] /= jumlah;
  }

  final tmp = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      for (var k = -radius; k <= radius; k++) {
        s += inti[k + radius] * kanal[y * w + (x + k).clamp(0, w - 1)];
      }
      tmp[y * w + x] = s;
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0;
      for (var k = -radius; k <= radius; k++) {
        s += inti[k + radius] * tmp[(y + k).clamp(0, h - 1) * w + x];
      }
      kanal[y * w + x] = s;
    }
  }
}

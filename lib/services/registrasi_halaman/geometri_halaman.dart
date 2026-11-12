import 'dart:math' as math;
import 'dart:typed_data';

/// Satu titik di bidang foto (piksel). Record struktural: sama tipenya dengan
/// `Titik` di `registrasi_jangkar_teks.dart`, tetapi didefinisikan sendiri
/// supaya berkas-berkas di folder ini murni Dart (bisa dikompilasi AOT tanpa
/// Flutter untuk pengukuran).
typedef TitikHalaman = ({double x, double y});

double jarakTitik(TitikHalaman a, TitikHalaman b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

double _silang(TitikHalaman o, TitikHalaman a, TitikHalaman b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Lambung cembung (Andrew monotone chain). Titik kembar dan titik segaris
/// dibuang. Urutan hasil searah di salah satu sistem sumbu; pemanggil tidak
/// boleh bergantung pada arahnya.
List<TitikHalaman> lambungCembung(List<TitikHalaman> masukan) {
  final p = [...masukan]
    ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (p.length < 3) return p;

  final h = <TitikHalaman>[];
  for (final t in p) {
    while (h.length >= 2 && _silang(h[h.length - 2], h.last, t) <= 0) {
      h.removeLast();
    }
    h.add(t);
  }

  final batas = h.length + 1;
  for (var i = p.length - 2; i >= 0; i--) {
    final t = p[i];
    while (h.length >= batas && _silang(h[h.length - 2], h.last, t) <= 0) {
      h.removeLast();
    }
    h.add(t);
  }
  h.removeLast();

  return h;
}

/// Sudut (radian, dalam [-π/4, π/4]) sumbu persegi panjang berluas terkecil
/// yang membungkus [lambung] — orientasi halaman di foto, dimodulokan ke
/// putaran terkecil. Persegi panjang pembungkus mengikuti sisi lambung, jadi
/// untuk halaman yang diproyeksi miring ia tetap sejajar sisi halaman dalam
/// beberapa derajat — cukup untuk memilih sudut mana "kiri-atas".
double sudutSumbuHalaman(List<TitikHalaman> lambung) {
  if (lambung.length < 3) return 0;

  var luasTerkecil = double.infinity;
  var sudutTerbaik = 0.0;

  for (var i = 0; i < lambung.length; i++) {
    final a = lambung[i];
    final b = lambung[(i + 1) % lambung.length];
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final panjang = math.sqrt(dx * dx + dy * dy);
    if (panjang < 1e-9) continue;

    final ux = dx / panjang;
    final uy = dy / panjang;
    var minU = double.infinity;
    var maxU = -double.infinity;
    var minV = double.infinity;
    var maxV = -double.infinity;
    for (final t in lambung) {
      final u = t.x * ux + t.y * uy;
      final v = -t.x * uy + t.y * ux;
      if (u < minU) minU = u;
      if (u > maxU) maxU = u;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    final luas = (maxU - minU) * (maxV - minV);
    if (luas < luasTerkecil) {
      luasTerkecil = luas;
      sudutTerbaik = math.atan2(dy, dx);
    }
  }

  const seperempatPutaran = math.pi / 2;

  return sudutTerbaik -
      (sudutTerbaik / seperempatPutaran).roundToDouble() * seperempatPutaran;
}

/// Empat sudut KASAR urutan kiri-atas, kanan-atas, kanan-bawah, kiri-bawah:
/// titik ekstrem pada empat arah diagonal dalam sumbu yang diputar sebesar
/// [sudutSumbu]. Prototipe memakai sumbu foto (min/max x+y, x-y) — benar hanya
/// bila halaman miring kecil; dengan sumbu halaman, kemiringan sampai ±45°
/// tetap memilih sudut yang benar.
///
/// `null` bila dua arah jatuh di titik yang sama (bentuk merosot).
List<TitikHalaman>? sudutKasar(List<TitikHalaman> titik, double sudutSumbu) {
  if (titik.length < 4) return null;

  final c = math.cos(sudutSumbu);
  final s = math.sin(sudutSumbu);

  var kiriAtas = 0;
  var kananAtas = 0;
  var kananBawah = 0;
  var kiriBawah = 0;
  var minJumlah = double.infinity;
  var maxJumlah = -double.infinity;
  var maxSelisih = -double.infinity;
  var minSelisih = double.infinity;

  for (var i = 0; i < titik.length; i++) {
    final t = titik[i];
    final u = t.x * c + t.y * s;
    final v = -t.x * s + t.y * c;
    final jumlah = u + v;
    final selisih = u - v;

    if (jumlah < minJumlah) {
      minJumlah = jumlah;
      kiriAtas = i;
    }
    if (jumlah > maxJumlah) {
      maxJumlah = jumlah;
      kananBawah = i;
    }
    if (selisih > maxSelisih) {
      maxSelisih = selisih;
      kananAtas = i;
    }
    if (selisih < minSelisih) {
      minSelisih = selisih;
      kiriBawah = i;
    }
  }

  final unik = {kiriAtas, kananAtas, kananBawah, kiriBawah};
  if (unik.length < 4) return null;

  return [
    titik[kiriAtas],
    titik[kananAtas],
    titik[kananBawah],
    titik[kiriBawah],
  ];
}

/// Garis hasil kuadrat-terkecil: titik tumpu ([px], [py]) + arah satuan
/// ([dx], [dy]).
class GarisTerfit {
  const GarisTerfit({
    required this.px,
    required this.py,
    required this.dx,
    required this.dy,
    required this.rms,
    required this.jumlah,
  });

  final double px;
  final double py;
  final double dx;
  final double dy;

  /// Simpangan baku jarak titik ke garis, setelah 5% pencilan terbesar
  /// dibuang. Ukuran "seberapa lurus" sisinya, dalam piksel.
  final double rms;
  final int jumlah;

  /// Jarak bertanda titik ke garis (sisi kiri arah [dx],[dy] positif di
  /// sumbu y-ke-bawah).
  double jarakBertanda(double x, double y) => (x - px) * -dy + (y - py) * dx;
}

/// Cocokkan garis ke [n] titik ([xs], [ys]) dengan kuadrat-terkecil tegak
/// lurus (total least squares) terboboti Huber (IRLS) — pengganti
/// `cv2.fitLine(DIST_HUBER)` di prototipe. Titik pencilan (noda, ujung sudut
/// yang melengkung) kehilangan bobot, jadi tidak menarik garis.
GarisTerfit? cocokkanGaris(
  Float64List xs,
  Float64List ys,
  int n, {
  int iterasi = 12,
}) {
  if (n < 2) return null;

  final bobot = Float64List(n)..fillRange(0, n, 1.0);
  final sisa = Float64List(n);
  final mutlak = Float64List(n);
  var mx = 0.0;
  var my = 0.0;
  var dx = 1.0;
  var dy = 0.0;

  for (var it = 0; it < iterasi; it++) {
    var sw = 0.0;
    var sx = 0.0;
    var sy = 0.0;
    for (var i = 0; i < n; i++) {
      sw += bobot[i];
      sx += bobot[i] * xs[i];
      sy += bobot[i] * ys[i];
    }
    if (sw <= 1e-12) return null;
    mx = sx / sw;
    my = sy / sw;

    var sxx = 0.0;
    var sxy = 0.0;
    var syy = 0.0;
    for (var i = 0; i < n; i++) {
      final a = xs[i] - mx;
      final b = ys[i] - my;
      sxx += bobot[i] * a * a;
      sxy += bobot[i] * a * b;
      syy += bobot[i] * b * b;
    }

    final teta = 0.5 * math.atan2(2 * sxy, sxx - syy);
    dx = math.cos(teta);
    dy = math.sin(teta);

    for (var i = 0; i < n; i++) {
      sisa[i] = (xs[i] - mx) * -dy + (ys[i] - my) * dx;
      mutlak[i] = sisa[i].abs();
    }

    // Skala kokoh: MAD * 1,4826, dengan lantai supaya data yang nyaris
    // sempurna tidak menolak titik karena beda 0,01 px.
    final urut = Float64List.fromList(mutlak)..sort();
    final median = urut[n ~/ 2];
    final sigma = math.max(1.4826 * median, 0.3);
    final c = 1.345 * sigma;

    for (var i = 0; i < n; i++) {
      bobot[i] = mutlak[i] <= c ? 1.0 : c / mutlak[i];
    }
  }

  // RMS terpangkas: 95% titik dengan jarak terkecil.
  for (var i = 0; i < n; i++) {
    mutlak[i] = ((xs[i] - mx) * -dy + (ys[i] - my) * dx).abs();
  }
  final urut = Float64List.fromList(mutlak)..sort();
  final simpan = math.max(2, (n * 0.95).ceil());
  var jumlahKuadrat = 0.0;
  for (var i = 0; i < simpan; i++) {
    jumlahKuadrat += urut[i] * urut[i];
  }

  return GarisTerfit(
    px: mx,
    py: my,
    dx: dx,
    dy: dy,
    rms: math.sqrt(jumlahKuadrat / simpan),
    jumlah: n,
  );
}

/// Perpotongan dua garis; `null` bila nyaris sejajar.
TitikHalaman? perpotongan(GarisTerfit a, GarisTerfit b) {
  final det = -a.dx * b.dy + b.dx * a.dy;
  if (det.abs() < 1e-6) return null;

  final rx = b.px - a.px;
  final ry = b.py - a.py;
  final t = (-rx * b.dy + b.dx * ry) / det;

  return (x: a.px + t * a.dx, y: a.py + t * a.dy);
}

/// Luas poligon (rumus tali sepatu), selalu positif.
double luasPoligon(List<TitikHalaman> p) {
  var jumlah = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i];
    final b = p[(i + 1) % p.length];
    jumlah += a.x * b.y - b.x * a.y;
  }

  return jumlah.abs() / 2;
}

/// Segi empat cembung ketat: semua perkalian silang sisi berurutan satu
/// tanda dan tidak nol.
bool segiEmpatCembung(List<TitikHalaman> q) {
  var positif = 0;
  var negatif = 0;
  for (var i = 0; i < q.length; i++) {
    final a = q[i];
    final b = q[(i + 1) % q.length];
    final c = q[(i + 2) % q.length];
    final s = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (s > 1e-9) {
      positif++;
    } else if (s < -1e-9) {
      negatif++;
    } else {
      return false;
    }
  }

  return positif == q.length || negatif == q.length;
}

/// Sudut dalam (derajat) di simpul [i].
double sudutDalamDeg(List<TitikHalaman> q, int i) {
  final a = q[(i + q.length - 1) % q.length];
  final b = q[i];
  final c = q[(i + 1) % q.length];
  final v1x = a.x - b.x;
  final v1y = a.y - b.y;
  final v2x = c.x - b.x;
  final v2y = c.y - b.y;
  final n1 = math.sqrt(v1x * v1x + v1y * v1y);
  final n2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (n1 < 1e-12 || n2 < 1e-12) return 0;

  final cosA = ((v1x * v2x + v1y * v2y) / (n1 * n2)).clamp(-1.0, 1.0);

  return math.acos(cosA) * 180 / math.pi;
}

/// Rasio rata-rata panjang sisi atas+bawah terhadap kiri+kanan di foto, urutan
/// kiri-atas, kanan-atas, kanan-bawah, kiri-bawah. Jujur hanya untuk foto yang
/// nyaris tegak lurus; [perkirakanRasioHalaman] mengoreksi perspektif.
double rasioPanjangSisi(List<TitikHalaman> q) {
  final lebar = (jarakTitik(q[0], q[1]) + jarakTitik(q[3], q[2])) / 2;
  final tinggi = (jarakTitik(q[0], q[3]) + jarakTitik(q[1], q[2])) / 2;

  return lebar / tinggi;
}

/// Rasio lebar/tinggi halaman ASLI (di bidang kertas) dari empat sudut
/// proyeksinya, urutan kiri-atas, kanan-atas, kanan-bawah, kiri-bawah.
///
/// Perbandingan panjang sisi di foto tidak jujur untuk foto miring: sisi
/// dekat tampak lebih panjang. Di sini dipakai rumus papan-tulis Zhang & He
/// (2007, "Whiteboard scanning and image enhancement"): sudut siku halaman
/// memberi satu persamaan untuk jarak fokus, lalu rasio dihitung dari arah
/// sisi atas dan sisi kiri dalam ruang kamera. Titik pokok dianggap di tengah
/// foto ([cx], [cy]) dan piksel persegi — asumsi wajar kamera ponsel.
///
/// ## Kapan jarak fokus TIDAK bisa ditaksir dari sudut
///
/// Bila sepasang sisi berhadapan sejajar di foto (kamera hanya dimiringkan
/// ke satu arah), persamaan fokusnya 0/0: bentuk segi empat tidak memuat
/// fokus. Bila perspektifnya sangat lemah, taksiran fokus didominasi derau.
/// Dalam kedua kasus dipakai [fokusPrior] (bawaan 0,85 × sisi terpanjang
/// foto, nilai umum kamera ponsel); taksiran dari sudut pun dijepit ke
/// 0,5–2 × prior supaya sudut yang tidak fisik tidak menghasilkan rasio liar.
/// Pada foto nyaris tegak lurus rasio praktis tidak bergantung pada fokus.
double perkirakanRasioHalaman(
  List<TitikHalaman> q,
  double cx,
  double cy, {
  double? fokusPrior,
}) {
  final prior = fokusPrior ?? 0.85 * 2 * math.max(cx, cy);

  // m1 = kiri-atas, m2 = kanan-atas, m3 = kiri-bawah, m4 = kanan-bawah.
  final m1 = [q[0].x, q[0].y, 1.0];
  final m2 = [q[1].x, q[1].y, 1.0];
  final m3 = [q[3].x, q[3].y, 1.0];
  final m4 = [q[2].x, q[2].y, 1.0];

  final m1m4 = _silang3(m1, m4);
  final k2Bawah = _titik3(_silang3(m2, m4), m3);
  final k3Bawah = _titik3(_silang3(m3, m4), m2);
  if (k2Bawah.abs() < 1e-12 || k3Bawah.abs() < 1e-12) {
    return rasioPanjangSisi(q);
  }

  final k2 = _titik3(m1m4, m3) / k2Bawah;
  final k3 = _titik3(m1m4, m2) / k3Bawah;

  final n2 = [for (var i = 0; i < 3; i++) k2 * m2[i] - m1[i]];
  final n3 = [for (var i = 0; i < 3; i++) k3 * m3[i] - m1[i]];

  final z2 = n2[2];
  final z3 = n3[2];

  var f = prior;
  if (z2.abs() >= 0.02 && z3.abs() >= 0.02) {
    final f2 =
        -((n2[0] - cx * z2) * (n3[0] - cx * z3) +
            (n2[1] - cy * z2) * (n3[1] - cy * z3)) /
        (z2 * z3);
    if (f2.isFinite && f2 > 0) {
      f = math.sqrt(f2).clamp(0.5 * prior, 2 * prior).toDouble();
    }
  }

  double kuadrat(List<double> n) =>
      (math.pow(n[0] - cx * n[2], 2) + math.pow(n[1] - cy * n[2], 2)) /
          (f * f) +
      n[2] * n[2];

  final rasio2 = kuadrat(n2) / kuadrat(n3);
  if (!rasio2.isFinite || rasio2 <= 0) return rasioPanjangSisi(q);

  return math.sqrt(rasio2);
}

List<double> _silang3(List<double> a, List<double> b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];

double _titik3(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

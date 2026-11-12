import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'geometri_halaman.dart';
import 'hasil_deteksi_halaman.dart';

/// Deteksi empat sudut halaman: tahap (a) sudut kasar dan (b) sudut halus,
/// plus pemeriksaan kewajaran. Diturunkan dari prototipe Python 12 Nov 2026
/// (di luar repo ini); ambang dan alasannya ada di KDoc `OpsiRegistrasiHalaman`
/// dan ringkasannya di `docs/pihak-ketiga-ocr.md`. Dart murni (paket `image`
/// yang sudah ada) — tanpa OpenCV, tanpa plugin native.
///
/// ## Alur
///
///  1. Perkecil foto ke lebar kerja (640), blur kotak 5×5. Tiga kanal dicoba
///     berurutan sampai ada yang lolos semua pemeriksaan: kecerahan (luma);
///     kanal RGB terendah (kertas putih tinggi di KEDUA kanal, alas
///     kayu/berwarna turun di kanal terendah); lalu kroma (kertas putih/abu
///     berkroma rendah, alas krem/kayu berkroma lebih tinggi — tidak
///     bergantung pada terang, jadi bayangan tidak menggesernya). Alas putih
///     atau abu-abu terang tidak bisa dipisahkan oleh ketiganya: GAGAL.
///  2. Penutupan abu-abu 7×7 (hapus garis tabel, bingkai, teks), lalu ambang
///     Otsu → mask "halaman terang"; komponen terhubung (8 tetangga)
///     terbesar. Pemisahan kelas Otsu harus ≥ 50 tingkat abu (kroma: 30):
///     di bawah itu "terang vs redup" akibat cahaya tak rata tak bisa
///     dibedakan dari "kertas vs alas" — gagal, jatuh ke kanal berikutnya.
///  3. Siluet luar komponen (titik ekstrem tiap baris dan kolom, jadi lubang
///     di dalam halaman tidak ikut) → lambung cembung → sudut kasar pada
///     arah diagonal sumbu halaman (min-area-rect), bukan sumbu foto.
///  4. Tiap sisi: titik siluet di antara dua sudut kasar (10%–90%) dicocokkan
///     garis kuadrat-terkecil Huber; sudut = perpotongan garis.
///  5. PERHALUS (tambahan terhadap prototipe): posisi tepi dicari ulang dari
///     puncak gradien kecerahan sepanjang normal sisi (48 posisi, sub-piksel),
///     lalu garis dicocokkan lagi. Siluet mask bergantung pada ambang global
///     — bayangan tangan atau cahaya miring menggesernya beberapa piksel.
///     Diukur 12 Nov 2026 pada 31 foto terdeteksi (dari 42 foto sintetis
///     variasi): tanpa langkah ini galat sudut maks 0,46% diagonal, dengan
///     langkah ini 0,08%. Puncak gradien tidak bergantung pada tingkat
///     terang mutlak.
///     Kelurusan sisi diukur DI SINI (RMS titik gradien): kertas melengkung
///     ≥ 2% lebar ditolak, bukan diluruskan.
///  6. Kewajaran (semua harus lolos, kalau tidak GAGAL — tidak menebak): tidak
///     ada sisi yang menempel di bingkai foto, sudut di dalam foto (toleransi
///     3% diagonal untuk ujung kertas yang terpotong), cembung, sudut dalam
///     60°–120°, luas ≥ 25%, sisi lurus, dan ada kontras di kedua sisi garis
///     tepi (mengenali "tepi" palsu berupa gradasi cahaya di alas terang).
///
/// ## Batas yang diketahui (BUKAN jaminan "tidak pernah salah")
///
/// Langkah 1–6 menolak yang TERLIHAT salah. Pada foto sintetis (Dart, 12 Nov
/// 2026) tidak ada sudut salah yang lolos DI DALAM matriks uji, tetapi satu
/// kelas salah-diam-diam sudah terukur dan lolos semua pemeriksaan:
///
///  - **Bantalan / tumpukan lebih besar dengan rasio sama.** Halaman di atas
///    lembar, map, atau tumpukan kertas yang menonjol 3–20% sisi di tiap sisi:
///    tepi LUAR bantalan segi empat yang sah, lurus, kontras, dan berrasio sama
///    dengan halaman, jadi terkunci sebagai halaman. Terukur: bantalan 6% →
///    galat 3,5–4,3% diagonal foto, 12% → 6,8–7,9% (terhadap halaman
///    sebenarnya; terhadap bantalan hanya 0,03–0,09%). Penutupan abu-abu
///    (langkah 2) justru menghapus garis tipis tepi halaman di dalamnya.
///  - Cue "tepi kedua sejajar di dalam 2–15% sisi" TIDAK dipakai: garis
///    bingkai cetak dan garis tabel formulir menghasilkan cue yang sama.
///    Diukur ad hoc 12 Nov 2026 (skrip tidak dikomit): kedalaman garis gelap
///    median per sisi di pita itu 32–195 pada 26 foto prototipe dan 26–123
///    pada halaman sintetis tanpa bantalan, sedangkan dengan bantalan 3–12%
///    −8–134. Rentangnya tumpang tindih, jadi ambang apa pun menolak halaman
///    sah atau meloloskan bantalan.
///
/// Karena itu keluaran modul ini adalah USULAN sudut. Registrasi jangkar teks
/// dan kode formulir (dari teks cetak di citra hasil warp) WAJIB menjadi
/// pemeriksa kedua SEBELUM sel dibaca; jangkar yang meleset dari posisi
/// templatenya = jatuh ke jalur lama. Foto nyata (bantalan, meja berkilap,
/// tangan, pantulan) belum diuji.
///
/// Fungsi ini sinkron dan murni; jalankan di isolate (lihat
/// `registrasi_halaman.dart`).
HasilDeteksiHalaman deteksiSudutHalaman(
  img.Image foto, {
  OpsiRegistrasiHalaman opsi = const OpsiRegistrasiHalaman(),
}) {
  if (foto.width < 64 || foto.height < 64) {
    return DeteksiHalamanGagal(
      AlasanGagalRegistrasi.fotoTidakTerbaca,
      'ukuran ${foto.width}x${foto.height}',
    );
  }

  final jam = Stopwatch()..start();
  final kecil = _kecilkan(foto, opsi.lebarKerja);
  final msKecil = jam.elapsedMicroseconds / 1000;

  DeteksiHalamanGagal? terjauh;
  final strategi = <(String, Uint8List)>[
    ('luma', kecil.luma),
    if (kecil.berwarna) ('minimum', kecil.minimum),
    if (kecil.berwarna) ('kroma', kecil.kroma),
  ];

  for (final (nama, kanal) in strategi) {
    final hasil = _cobaStrategi(nama, kanal, kecil, opsi);
    if (hasil is DeteksiHalamanBerhasil) {
      return DeteksiHalamanBerhasil(
        sudut: hasil.sudut,
        diagnostik: hasil.diagnostik.salinDengan(
          durasiKecilMs: msKecil,
          durasiDeteksiMs: jam.elapsedMicroseconds / 1000,
        ),
      );
    }

    final gagal = hasil as DeteksiHalamanGagal;
    // Alasan dari tahap yang lebih jauh lebih informatif — kecuali "terlalu
    // kecil": komponen bersih sebesar halaman di salah satu kanal adalah bukti
    // terkuat bahwa halamannya memang ada tetapi kecil, sedangkan kanal lain
    // yang gagal di tahap garis hanya menggarap mask yang berderau.
    final lebihBaik =
        terjauh == null ||
        (terjauh.alasan != AlasanGagalRegistrasi.halamanTerlaluKecil &&
            (gagal.alasan == AlasanGagalRegistrasi.halamanTerlaluKecil ||
                gagal.alasan.index > terjauh.alasan.index));
    if (lebihBaik) terjauh = gagal;
  }

  return terjauh!;
}

// ---------------------------------------------------------------------------
// Tahap 1: perkecil + blur
// ---------------------------------------------------------------------------

class _Kecil {
  const _Kecil({
    required this.luma,
    required this.minimum,
    required this.kroma,
    required this.w,
    required this.h,
    required this.skalaX,
    required this.skalaY,
    required this.berwarna,
  });

  final Uint8List luma;
  final Uint8List minimum;

  /// 255 − kroma (selisih kanal terbesar-terkecil dibagi terbesar, dipetakan
  /// 0–0,3 → 0–255): kertas putih/abu bernilai tinggi, alas berwarna rendah,
  /// APA PUN kecerahannya — bayangan dan gradasi cahaya tidak mengubah kroma.
  final Uint8List kroma;
  final int w;
  final int h;

  /// Piksel foto per piksel kerja.
  final double skalaX;
  final double skalaY;
  final bool berwarna;
}

img.Image _seragamkan(img.Image foto) {
  final cocok =
      foto.format == img.Format.uint8 &&
      !foto.hasPalette &&
      (foto.numChannels == 1 || foto.numChannels == 3 || foto.numChannels == 4);

  return cocok ? foto : foto.convert(format: img.Format.uint8, numChannels: 3);
}

/// Perkecil dengan rata-rata kotak (setiap piksel foto dihitung tepat sekali)
/// langsung di bita mentah — `getPixel` per piksel pada foto 12 MP membuat
/// objek jutaan kali.
_Kecil _kecilkan(img.Image foto, int lebarKerja) {
  final sumber = _seragamkan(foto);
  final sw = sumber.width;
  final sh = sumber.height;
  final w = math.min(lebarKerja, sw);
  final h = math.max(1, (sh * w / sw).round());
  final sx = sw / w;
  final sy = sh / h;
  final nc = sumber.numChannels;
  final byte = sumber.toUint8List();
  final stride = sumber.rowStride;

  final kolMulai = Int32List(w);
  final kolAkhir = Int32List(w);
  for (var x = 0; x < w; x++) {
    final a = (x * sx).floor().clamp(0, sw - 1);
    kolMulai[x] = a;
    kolAkhir[x] = math.min(sw, math.max(a + 1, ((x + 1) * sx).floor()));
  }

  final luma = Uint8List(w * h);
  final minimum = Uint8List(w * h);
  final kroma = Uint8List(w * h)..fillRange(0, w * h, 255);
  final aR = Int32List(w);
  final aG = Int32List(w);
  final aB = Int32List(w);

  for (var y = 0; y < h; y++) {
    final y0 = (y * sy).floor().clamp(0, sh - 1);
    final y1 = math.min(sh, math.max(y0 + 1, ((y + 1) * sy).floor()));
    aR.fillRange(0, w, 0);
    aG.fillRange(0, w, 0);
    aB.fillRange(0, w, 0);

    for (var yy = y0; yy < y1; yy++) {
      final dasar = yy * stride;
      if (nc == 1) {
        for (var x = 0; x < w; x++) {
          var s = 0;
          for (var xx = kolMulai[x]; xx < kolAkhir[x]; xx++) {
            s += byte[dasar + xx];
          }
          aR[x] += s;
        }
      } else {
        for (var x = 0; x < w; x++) {
          var r = 0;
          var g = 0;
          var b = 0;
          for (var xx = kolMulai[x]; xx < kolAkhir[x]; xx++) {
            final o = dasar + xx * nc;
            r += byte[o];
            g += byte[o + 1];
            b += byte[o + 2];
          }
          aR[x] += r;
          aG[x] += g;
          aB[x] += b;
        }
      }
    }

    final tinggiKotak = y1 - y0;
    final o = y * w;
    for (var x = 0; x < w; x++) {
      final n = tinggiKotak * (kolAkhir[x] - kolMulai[x]);
      final tengah = n >> 1;
      final r = (aR[x] + tengah) ~/ n;
      if (nc == 1) {
        luma[o + x] = r;
        minimum[o + x] = r;
      } else {
        final g = (aG[x] + tengah) ~/ n;
        final b = (aB[x] + tengah) ~/ n;
        luma[o + x] = (77 * r + 150 * g + 29 * b) >> 8;
        final terendah = math.min(r, math.min(g, b));
        minimum[o + x] = terendah;
        final tertinggi = math.max(r, math.max(g, b));
        if (tertinggi > 0) {
          final k = (tertinggi - terendah) * 850 ~/ tertinggi; // 255/0,3
          kroma[o + x] = 255 - (k > 255 ? 255 : k);
        }
      }
    }
  }

  return _Kecil(
    luma: luma,
    minimum: minimum,
    kroma: kroma,
    w: w,
    h: h,
    skalaX: sx,
    skalaY: sy,
    berwarna: nc != 1,
  );
}

/// Penutupan abu-abu (maks lalu min, jendela persegi [radius]*2+1): menghapus
/// struktur GELAP yang lebih tipis dari jendela — garis tabel, bingkai cetak,
/// teks, coretan — tanpa menggeser tepi halaman. Persegi panjang (juga yang
/// miring atau terproyeksi) tidak berubah karena penutupan hanya mengisi
/// takik cekung; sudut cembung dan sisi lurus tetap.
///
/// Tanpa langkah ini, garis tabel dan bingkai yang cukup tebal memecah mask
/// halaman, dan komponen terbesar bisa menjadi bagian DALAM bingkai: segi empat
/// yang tampak sah tetapi 3% diagonal terlalu kecil (terukur pada lebar kerja
/// 960 dan 1280).
Uint8List _tutup(Uint8List src, int w, int h, int radius) {
  Uint8List sapu(Uint8List a, bool datar, bool maks) {
    final hasil = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var terpilih = maks ? 0 : 255;
        for (var k = -radius; k <= radius; k++) {
          final v = datar
              ? a[y * w + (x + k).clamp(0, w - 1)]
              : a[(y + k).clamp(0, h - 1) * w + x];
          if (maks ? v > terpilih : v < terpilih) terpilih = v;
        }
        hasil[y * w + x] = terpilih;
      }
    }

    return hasil;
  }

  final dilasi = sapu(sapu(src, true, true), false, true);

  return sapu(sapu(dilasi, true, false), false, false);
}

/// Blur kotak 5×5 (tepi: piksel terdekat diulang), setara `cv2.blur`.
Uint8List _blur5(Uint8List src, int w, int h) {
  final datar = Uint16List(w * h);
  for (var y = 0; y < h; y++) {
    final dasar = y * w;
    for (var x = 0; x < w; x++) {
      var s = 0;
      for (var k = -2; k <= 2; k++) {
        s += src[dasar + (x + k).clamp(0, w - 1)];
      }
      datar[dasar + x] = s;
    }
  }

  final hasil = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0;
      for (var k = -2; k <= 2; k++) {
        s += datar[(y + k).clamp(0, h - 1) * w + x];
      }
      hasil[y * w + x] = (s + 12) ~/ 25;
    }
  }

  return hasil;
}

// ---------------------------------------------------------------------------
// Tahap 2: Otsu + komponen terbesar
// ---------------------------------------------------------------------------

/// Ambang Otsu. Pada dataran datar (rentang kosong di antara dua puncak
/// histogram, semua ambangnya sama baiknya) dipilih TENGAH dataran, bukan
/// ujung bawah: tepi halaman yang di-blur punya lereng, dan ambang di ujung
/// bawah menggemukkan mask separuh lebar lereng ke segala arah.
({int ambang, double pisah}) _otsu(Uint8List data) {
  final hist = List<int>.filled(256, 0);
  for (final v in data) {
    hist[v]++;
  }

  final total = data.length;
  var jumlahSemua = 0.0;
  for (var i = 0; i < 256; i++) {
    jumlahSemua += i * hist[i];
  }

  var wGelap = 0;
  var jumlahGelap = 0.0;
  var terbaik = -1.0;
  var awal = 0;
  var akhir = 0;
  var pisah = 0.0;

  for (var t = 0; t < 256; t++) {
    wGelap += hist[t];
    if (wGelap == 0) continue;
    final wTerang = total - wGelap;
    if (wTerang == 0) break;

    jumlahGelap += t * hist[t];
    final mGelap = jumlahGelap / wGelap;
    final mTerang = (jumlahSemua - jumlahGelap) / wTerang;
    final antarKelas =
        wGelap.toDouble() * wTerang * (mGelap - mTerang) * (mGelap - mTerang);

    if (antarKelas > terbaik) {
      terbaik = antarKelas;
      awal = t;
      akhir = t;
      pisah = mTerang - mGelap;
    } else if (antarKelas == terbaik) {
      akhir = t;
    }
  }

  return (ambang: (awal + akhir) ~/ 2, pisah: pisah);
}

/// Komponen terhubung (8 tetangga) terbesar dari mask 0/1, lewat isi-banjir
/// iteratif: tiap piksel masuk tumpukan paling banyak sekali, jadi tumpukan
/// `w*h` cukup dan tidak ada rekursi.
({Uint8List komponen, int luas}) _komponenTerbesar(
  Uint8List mask,
  int w,
  int h,
) {
  final total = w * h;
  final dikunjungi = Uint8List(total);
  final tumpukan = Int32List(total);
  var luasTerbaik = 0;
  var benihTerbaik = -1;

  int isi(int benih, Uint8List penanda, Uint8List? keluaran) {
    var sp = 0;
    tumpukan[sp++] = benih;
    penanda[benih] = 1;
    var luas = 0;

    while (sp > 0) {
      final p = tumpukan[--sp];
      luas++;
      keluaran?[p] = 1;
      final y = p ~/ w;
      final x = p - y * w;

      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final q = ny * w + nx;
          if (mask[q] == 1 && penanda[q] == 0) {
            penanda[q] = 1;
            tumpukan[sp++] = q;
          }
        }
      }
    }

    return luas;
  }

  for (var s = 0; s < total; s++) {
    if (mask[s] == 0 || dikunjungi[s] == 1) continue;
    final luas = isi(s, dikunjungi, null);
    if (luas > luasTerbaik) {
      luasTerbaik = luas;
      benihTerbaik = s;
    }
  }

  final komponen = Uint8List(total);
  if (benihTerbaik >= 0) {
    isi(benihTerbaik, Uint8List(total), komponen);
  }

  return (komponen: komponen, luas: luasTerbaik);
}

/// Titik siluet luar: tiap baris diambil piksel pertama dan terakhirnya, tiap
/// kolom piksel teratas dan terbawahnya. Lubang di dalam komponen (garis
/// tabel, teks) tidak menyumbang titik. Koordinat konvensi tepi-piksel.
({Float64List xs, Float64List ys, int n}) _siluet(
  Uint8List komp,
  int w,
  int h,
) {
  final xs = Float64List(2 * (w + h));
  final ys = Float64List(2 * (w + h));
  var n = 0;
  final kolAtas = Int32List(w)..fillRange(0, w, -1);
  final kolBawah = Int32List(w)..fillRange(0, w, -1);

  for (var y = 0; y < h; y++) {
    var kiri = -1;
    var kanan = -1;
    final dasar = y * w;
    for (var x = 0; x < w; x++) {
      if (komp[dasar + x] == 0) continue;
      if (kiri < 0) kiri = x;
      kanan = x;
      if (kolAtas[x] < 0) kolAtas[x] = y;
      kolBawah[x] = y;
    }
    if (kiri >= 0) {
      xs[n] = kiri.toDouble();
      ys[n++] = y + 0.5;
      xs[n] = kanan + 1.0;
      ys[n++] = y + 0.5;
    }
  }

  for (var x = 0; x < w; x++) {
    if (kolAtas[x] < 0) continue;
    xs[n] = x + 0.5;
    ys[n++] = kolAtas[x].toDouble();
    xs[n] = x + 0.5;
    ys[n++] = kolBawah[x] + 1.0;
  }

  return (xs: xs, ys: ys, n: n);
}

// ---------------------------------------------------------------------------
// Tahap 3: sudut halus + kewajaran
// ---------------------------------------------------------------------------

HasilDeteksiHalaman _cobaStrategi(
  String nama,
  Uint8List kanalMentah,
  _Kecil k,
  OpsiRegistrasiHalaman opsi,
) {
  final w = k.w;
  final h = k.h;
  // [kanal] sesudah garis dan teks cetak dihapus; ke sinilah semua tahap
  // berikutnya memandang.
  final kanal = opsi.penutupRadius > 0
      ? _tutup(kanalMentah, w, h, opsi.penutupRadius)
      : kanalMentah;
  final halus = _blur5(kanal, w, h);

  DeteksiHalamanGagal gagal(
    AlasanGagalRegistrasi alasan,
    String detail, [
    DiagnostikRegistrasi? diag,
  ]) => DeteksiHalamanGagal(alasan, '$nama: $detail', diag);

  final otsu = _otsu(halus);
  final pisahMin = nama == 'kroma' ? opsi.pisahMinKroma : opsi.pisahMinOtsu;
  if (otsu.pisah < pisahMin) {
    return gagal(
      AlasanGagalRegistrasi.kontrasKurang,
      'pemisahan kelas ${otsu.pisah.toStringAsFixed(1)} < $pisahMin',
    );
  }

  final mask = Uint8List(w * h);
  for (var i = 0; i < mask.length; i++) {
    mask[i] = halus[i] > otsu.ambang ? 1 : 0;
  }

  final komp = _komponenTerbesar(mask, w, h);
  final luasKomp = komp.luas / (w * h);
  if (luasKomp < opsi.luasMinKomponen) {
    // 10%–25%: kemungkinan besar halaman utuh yang terlalu kecil di foto;
    // di bawah itu lebih mungkin terpecah/tidak terlihat.
    return gagal(
      luasKomp >= 0.10
          ? AlasanGagalRegistrasi.halamanTerlaluKecil
          : AlasanGagalRegistrasi.halamanTidakTerdeteksi,
      'komponen terbesar ${(luasKomp * 100).toStringAsFixed(1)}% foto',
    );
  }
  if (luasKomp > opsi.luasMaksKomponen) {
    return gagal(
      AlasanGagalRegistrasi.kontrasKurang,
      'komponen terang ${(luasKomp * 100).toStringAsFixed(1)}% foto',
    );
  }

  final siluet = _siluet(komp.komponen, w, h);
  final titik = <TitikHalaman>[
    for (var i = 0; i < siluet.n; i++) (x: siluet.xs[i], y: siluet.ys[i]),
  ];
  final lambung = lambungCembung(titik);
  final sudutSumbu = sudutSumbuHalaman(lambung);
  final kasar = sudutKasar(lambung, sudutSumbu);
  if (kasar == null) {
    return gagal(
      AlasanGagalRegistrasi.bentukTidakWajar,
      'empat sudut kasar tidak berbeda',
    );
  }

  // ---- empat sisi ----------------------------------------------------------
  final garis = <GarisTerfit>[];
  for (var a = 0; a < 4; a++) {
    final p0 = kasar[a];
    final p1 = kasar[(a + 1) % 4];
    final panjang = jarakTitik(p0, p1);
    if (panjang < 8) {
      return gagal(AlasanGagalRegistrasi.bentukTidakWajar, 'sisi $a pendek');
    }
    final ux = (p1.x - p0.x) / panjang;
    final uy = (p1.y - p0.y) / panjang;
    final lebarJalur = 0.04 * panjang + 6;

    final xs = Float64List(siluet.n);
    final ys = Float64List(siluet.n);
    var n = 0;
    var diBingkai = 0;
    for (var i = 0; i < siluet.n; i++) {
      final rx = siluet.xs[i] - p0.x;
      final ry = siluet.ys[i] - p0.y;
      final t = (rx * ux + ry * uy) / panjang;
      if (t <= 0.1 || t >= 0.9) continue;
      if ((rx * uy - ry * ux).abs() >= lebarJalur) continue;
      if (siluet.xs[i] <= 0.5 ||
          siluet.xs[i] >= w - 0.5 ||
          siluet.ys[i] <= 0.5 ||
          siluet.ys[i] >= h - 0.5) {
        diBingkai++;
      }
      xs[n] = siluet.xs[i];
      ys[n++] = siluet.ys[i];
    }

    if (n > 0 && diBingkai > opsi.sisiDiBingkaiMaks * n) {
      return gagal(
        AlasanGagalRegistrasi.tepiTerpotong,
        'sisi $a: $diBingkai dari $n titik menempel di bingkai foto',
      );
    }

    if (n < math.max(20, (0.3 * panjang).round())) {
      return gagal(
        AlasanGagalRegistrasi.sisiTidakJelas,
        'sisi $a hanya $n titik',
      );
    }

    final g = cocokkanGaris(xs, ys, n);
    if (g == null) {
      return gagal(
        AlasanGagalRegistrasi.sisiTidakJelas,
        'sisi $a: garis gagal',
      );
    }
    garis.add(g);
  }

  final sudut = <TitikHalaman>[];
  for (var a = 0; a < 4; a++) {
    final p = perpotongan(garis[(a + 3) % 4], garis[a]);
    if (p == null) {
      return gagal(AlasanGagalRegistrasi.bentukTidakWajar, 'garis sejajar');
    }
    sudut.add(p);
  }

  var rms = [for (final g in garis) g.rms];
  final diagonal =
      (jarakTitik(sudut[0], sudut[2]) + jarakTitik(sudut[1], sudut[3])) / 2;
  final luasSegiEmpat = luasPoligon(sudut) / (w * h);

  var halusTepi = false;
  double? geserHalus;

  DiagnostikRegistrasi diag({
    List<double> kontras = const [],
    List<double> sudutDalam = const [],
  }) => DiagnostikRegistrasi(
    strategi: nama,
    ambangOtsu: otsu.ambang,
    pisahOtsu: otsu.pisah,
    luasKomponen: luasKomp,
    rmsSisiPx: rms,
    kontrasSisi: kontras,
    sudutDalamDeg: sudutDalam,
    luasSegiEmpat: luasSegiEmpat,
    halusTepi: halusTepi,
    geserHalusPx: geserHalus,
    lebarKerjaPx: w,
    tinggiKerjaPx: h,
  );

  // ---- kewajaran -----------------------------------------------------------
  var lewatMaks = 0.0;
  for (final s in sudut) {
    final lewat = [-s.x, s.x - w, -s.y, s.y - h].reduce(math.max);
    if (lewat > lewatMaks) lewatMaks = lewat;
  }
  if (lewatMaks > opsi.toleransiSudutLuar * diagonal) {
    return gagal(
      AlasanGagalRegistrasi.tepiTerpotong,
      'sudut ${lewatMaks.toStringAsFixed(1)} px di luar foto '
      '(${(lewatMaks / diagonal * 100).toStringAsFixed(1)}% diagonal)',
      diag(),
    );
  }

  if (!segiEmpatCembung(sudut)) {
    return gagal(
      AlasanGagalRegistrasi.bentukTidakWajar,
      'segi empat tidak cembung',
      diag(),
    );
  }

  final sudutDalam = [for (var i = 0; i < 4; i++) sudutDalamDeg(sudut, i)];
  if (sudutDalam.any(
    (d) => d < opsi.sudutDalamMinDeg || d > opsi.sudutDalamMaksDeg,
  )) {
    return gagal(
      AlasanGagalRegistrasi.bentukTidakWajar,
      'sudut dalam ${sudutDalam.map((d) => d.toStringAsFixed(0)).join('/')}°',
      diag(sudutDalam: sudutDalam),
    );
  }

  if (luasSegiEmpat < opsi.luasMinKomponen) {
    return gagal(
      AlasanGagalRegistrasi.halamanTerlaluKecil,
      'segi empat ${(luasSegiEmpat * 100).toStringAsFixed(1)}% foto',
      diag(sudutDalam: sudutDalam),
    );
  }

  // ---- (b2) perhalus: posisi tepi dari puncak gradien, bukan dari ambang ----
  // Siluet mask bergantung pada ambang global: bayangan tangan atau cahaya
  // miring menggeser garis ambang sampai beberapa piksel dari tepi kertas
  // yang sebenarnya, dan bercak yang menempel di tepi mencemari siluet.
  // Puncak gradien sepanjang normal tidak bergantung pada tingkat terang
  // mutlak dan melewati bercak. Kalau perhalusan menemukan tepi yang tidak
  // lurus atau sudut yang jauh berbeda dari siluet, itu GAGAL (tidak jatuh
  // kembali ke siluet yang tidak diuji). Hanya kalau datanya kurang
  // (kontras tepi rendah di > 40% posisi), siluet dipakai dengan ambang
  // kelurusan yang lebih ketat.
  var sudutAkhir = sudut;
  final halusan = _haluskanSudut(kanal, w, h, sudut, diagonal, opsi);
  if (halusan.tolak != null) {
    return gagal(halusan.tolak!, halusan.detail, diag(sudutDalam: sudutDalam));
  }
  if (halusan.sudut != null) {
    sudutAkhir = halusan.sudut!;
    halusTepi = true;
    geserHalus = halusan.geserMaks;
    rms = halusan.rms;
  } else {
    for (var a = 0; a < 4; a++) {
      if (rms[a] > opsi.rmsSisiMaksPx) {
        return gagal(
          AlasanGagalRegistrasi.sisiTidakLurus,
          'sisi $a RMS siluet ${rms[a].toStringAsFixed(2)} px',
          diag(sudutDalam: sudutDalam),
        );
      }
    }
  }

  final kontras = [
    for (var a = 0; a < 4; a++)
      _kontrasTepi(
        halus,
        w,
        h,
        sudutAkhir[a],
        sudutAkhir[(a + 1) % 4],
        sudutAkhir,
      ),
  ];
  for (var a = 0; a < 4; a++) {
    if (kontras[a] < opsi.kontrasTepiMin) {
      return gagal(
        AlasanGagalRegistrasi.sisiTidakJelas,
        'kontras sisi $a ${kontras[a].toStringAsFixed(1)} < '
        '${opsi.kontrasTepiMin}',
        diag(kontras: kontras, sudutDalam: sudutDalam),
      );
    }
  }

  return DeteksiHalamanBerhasil(
    sudut: [for (final s in sudutAkhir) (x: s.x * k.skalaX, y: s.y * k.skalaY)],
    diagnostik: diag(kontras: kontras, sudutDalam: sudutDalam),
  );
}

/// Perhalus empat sudut dengan mencari puncak gradien kecerahan sepanjang
/// normal tiap sisi ([langkah] posisi, tiap profil dirata-rata 7 titik
/// sepanjang tepi), lalu mencocokkan ulang garis (Huber).
///
/// Hasil: `sudut` terisi = perhalusan dipakai; `tolak` terisi = tepi terbukti
/// tidak lurus / sudut jauh dari siluet (gagal-aman); keduanya `null` = data
/// tidak cukup, pemanggil memakai siluet.
({
  List<TitikHalaman>? sudut,
  double geserMaks,
  List<double> rms,
  AlasanGagalRegistrasi? tolak,
  String detail,
})
_haluskanSudut(
  Uint8List kanal,
  int w,
  int h,
  List<TitikHalaman> awal,
  double diagonal,
  OpsiRegistrasiHalaman opsi,
) {
  const tidakCukup = (
    sudut: null,
    geserMaks: 0.0,
    rms: <double>[],
    tolak: null,
    detail: '',
  );
  const langkah = 48;
  const jendela = 8;
  const dasar = 2;
  const rentang = jendela + dasar;

  var cx = 0.0;
  var cy = 0.0;
  for (final s in awal) {
    cx += s.x / 4;
    cy += s.y / 4;
  }

  double sampel(double x, double y) {
    final u = (x - 0.5).clamp(0.0, w - 1.0);
    final v = (y - 0.5).clamp(0.0, h - 1.0);
    final x0 = u.floor();
    final y0 = v.floor();
    final x1 = math.min(x0 + 1, w - 1);
    final y1 = math.min(y0 + 1, h - 1);
    final fx = u - x0;
    final fy = v - y0;
    final atas = kanal[y0 * w + x0] * (1 - fx) + kanal[y0 * w + x1] * fx;
    final bawah = kanal[y1 * w + x0] * (1 - fx) + kanal[y1 * w + x1] * fx;

    return atas + (bawah - atas) * fy;
  }

  final garis = <GarisTerfit>[];
  final profil = Float64List(2 * rentang + 1);

  for (var a = 0; a < 4; a++) {
    final p0 = awal[a];
    final p1 = awal[(a + 1) % 4];
    final dx = p1.x - p0.x;
    final dy = p1.y - p0.y;
    final panjang = math.sqrt(dx * dx + dy * dy);
    if (panjang < 8) return tidakCukup;

    final ex = dx / panjang;
    final ey = dy / panjang;
    var nx = -ey;
    var ny = ex;
    if ((cx - p0.x) * nx + (cy - p0.y) * ny < 0) {
      nx = -nx;
      ny = -ny;
    }

    final xs = Float64List(langkah);
    final ys = Float64List(langkah);
    var n = 0;

    for (var i = 0; i < langkah; i++) {
      final t = 0.08 + 0.84 * i / (langkah - 1);
      final px = p0.x + dx * t;
      final py = p0.y + dy * t;

      for (var d = -rentang; d <= rentang; d++) {
        var jumlah = 0.0;
        for (var s = -3; s <= 3; s++) {
          jumlah += sampel(px + nx * d + ex * s, py + ny * d + ey * s);
        }
        profil[d + rentang] = jumlah / 7;
      }

      double gradien(int d) =>
          profil[d + dasar + rentang] - profil[d - dasar + rentang];

      var terbaik = -double.infinity;
      var dTerbaik = 0;
      for (var d = -jendela; d <= jendela; d++) {
        final g = gradien(d);
        if (g > terbaik) {
          terbaik = g;
          dTerbaik = d;
        }
      }
      if (terbaik < opsi.kontrasTepiMin) continue;

      // Puncak di batas jendela = tepi sebenarnya di luar jangkauan.
      if (dTerbaik.abs() >= jendela) continue;

      final gm = gradien(dTerbaik - 1);
      final gp = gradien(dTerbaik + 1);
      final penyebut = gm - 2 * terbaik + gp;
      final sub = penyebut.abs() < 1e-9
          ? 0.0
          : (0.5 * (gm - gp) / penyebut).clamp(-1.0, 1.0);
      final jarak = dTerbaik + sub;

      xs[n] = px + nx * jarak;
      ys[n++] = py + ny * jarak;
    }

    if (n < langkah * 0.6) return tidakCukup;
    final g = cocokkanGaris(xs, ys, n);
    if (g == null) return tidakCukup;
    if (g.rms > opsi.rmsHalusMaksPx) {
      return (
        sudut: null,
        geserMaks: 0.0,
        rms: const <double>[],
        tolak: AlasanGagalRegistrasi.sisiTidakLurus,
        detail:
            'sisi $a RMS gradien ${g.rms.toStringAsFixed(2)} px '
            '> ${opsi.rmsHalusMaksPx}',
      );
    }
    garis.add(g);
  }

  final sudut = <TitikHalaman>[];
  for (var a = 0; a < 4; a++) {
    final p = perpotongan(garis[(a + 3) % 4], garis[a]);
    if (p == null) return tidakCukup;
    sudut.add(p);
  }

  var geserMaks = 0.0;
  for (var a = 0; a < 4; a++) {
    geserMaks = math.max(geserMaks, jarakTitik(sudut[a], awal[a]));
  }
  if (geserMaks > 0.025 * diagonal || !segiEmpatCembung(sudut)) {
    return (
      sudut: null,
      geserMaks: geserMaks,
      rms: const <double>[],
      tolak: AlasanGagalRegistrasi.sisiTidakJelas,
      detail:
          'tepi gradien menyimpang ${geserMaks.toStringAsFixed(1)} px dari '
          'siluet',
    );
  }

  return (
    sudut: sudut,
    geserMaks: geserMaks,
    rms: [for (final g in garis) g.rms],
    tolak: null,
    detail: '',
  );
}

/// Median selisih kecerahan (dalam − luar) di sepanjang sisi [a]→[b]. "Dalam"
/// diukur 3–6 piksel dari garis; "luar" diukur DUA kali: 3–6 piksel (tepi
/// tajam) dan 8–14 piksel (lewati garis cetak tipis di luar tepi). Yang
/// dikembalikan yang terkecil dari keduanya.
///
/// Ukuran luar-jauh mengenali bingkai cetak di dalam halaman: tepi bingkai
/// punya kontras tajam (garis gelap di luarnya), tetapi di luar garis itu
/// ada margin putih, bukan alas. Titik yang jatuh di luar foto dilewati;
/// kalau kurang dari 6 titik sah, kontras dianggap 0.
double _kontrasTepi(
  Uint8List halus,
  int w,
  int h,
  TitikHalaman a,
  TitikHalaman b,
  List<TitikHalaman> sudut,
) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final panjang = math.sqrt(dx * dx + dy * dy);
  if (panjang < 1e-9) return 0;

  var cx = 0.0;
  var cy = 0.0;
  for (final s in sudut) {
    cx += s.x / sudut.length;
    cy += s.y / sudut.length;
  }

  // Normal ke dalam: ke arah titik berat.
  var nx = -dy / panjang;
  var ny = dx / panjang;
  if ((cx - a.x) * nx + (cy - a.y) * ny < 0) {
    nx = -nx;
    ny = -ny;
  }

  double? rata(double x, double y, double arah, int dari, int sampai) {
    var jumlah = 0.0;
    for (var d = dari; d <= sampai; d++) {
      final px = (x + arah * nx * d).floor();
      final py = (y + arah * ny * d).floor();
      if (px < 0 || py < 0 || px >= w || py >= h) return null;
      jumlah += halus[py * w + px];
    }

    return jumlah / (sampai - dari + 1);
  }

  final selisih = <double>[];
  const langkah = 24;
  for (var i = 0; i < langkah; i++) {
    final t = 0.12 + 0.76 * i / (langkah - 1);
    final x = a.x + dx * t;
    final y = a.y + dy * t;
    final dalam = rata(x, y, 1, 3, 6);
    final luarDekat = rata(x, y, -1, 3, 6);
    final luarJauh = rata(x, y, -1, 8, 14);
    if (dalam == null || luarDekat == null || luarJauh == null) continue;
    selisih.add(math.min(dalam - luarDekat, dalam - luarJauh));
  }
  if (selisih.length < 6) return 0;

  selisih.sort();

  return selisih[selisih.length ~/ 2];
}

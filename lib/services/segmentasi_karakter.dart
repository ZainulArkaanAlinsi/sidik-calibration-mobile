import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Segmentasi karakter tulisan tangan di SATU potongan sel — bahan untuk
/// pengenal digit sendiri yang BELUM ADA (sakelar `pakaiModelDigit`, mati).
///
/// Dart murni, tanpa dependency baru. Tidak mengklasifikasi apa pun, tidak
/// menyentuh warna/keyakinan sel, dan tidak dipanggil alur pindai: keluarannya
/// hanya potongan karakter 28×28 + kotaknya.
///
/// Langkah:
/// 1. abu-abu (luminans);
/// 2. buang GARIS KOTAK: baris/kolom yang lebih dari [_rasioGaris] gelap
///    (garis tabel lurus memanjang; angka tidak);
/// 3. binarisasi ADAPTIF: piksel tinta bila lebih gelap dari rata-rata
///    jendela lokalnya dikurangi [_selisihAdaptif] (bayangan & kertas kusam
///    tidak membuat seluruh sel hitam);
/// 4. komponen tersambung (8 tetangga), buang bintik di bawah luas minimum;
/// 5. gabung komponen yang bertumpuk horizontal (angka patah, mis. `5`);
/// 6. urut kiri → kanan;
/// 7. koma/titik dari UKURAN dan POSISI VERTIKAL relatif ke karakter besar;
/// 8. tiap karakter dinormalkan gaya MNIST: tinta terang di latar gelap,
///    muat di 20×20 dengan rasio tetap, di tengah kanvas 28×28.
List<KarakterSel> segmentasiKarakter(img.Image potongan) {
  final w = potongan.width, h = potongan.height;
  if (w < 3 || h < 3) return const [];

  // ---- 1. abu-abu ------------------------------------------------------------
  final abu = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = potongan.getPixel(x, y);
      abu[y * w + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(
        0,
        255,
      );
    }
  }

  // ---- 3. binarisasi adaptif (citra integral) --------------------------------
  final tinta = _binerAdaptif(abu, w, h);

  // ---- 2. buang garis kotak ----------------------------------------------------
  // Diputuskan dari citra BINER (garis tipis pucat tetap terdeteksi), lalu
  // seluruh baris/kolom garis dihapus beserta satu piksel tetangganya
  // (anti-alias garis).
  for (var y = 0; y < h; y++) {
    var n = 0;
    for (var x = 0; x < w; x++) {
      if (tinta[y * w + x] == 1) n++;
    }
    if (n > w * _rasioGaris) {
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        tinta.fillRange(yy * w, yy * w + w, 0);
      }
    }
  }
  for (var x = 0; x < w; x++) {
    var n = 0;
    for (var y = 0; y < h; y++) {
      if (tinta[y * w + x] == 1) n++;
    }
    if (n > h * _rasioGaris) {
      for (var dx = -1; dx <= 1; dx++) {
        final xx = x + dx;
        if (xx < 0 || xx >= w) continue;
        for (var y = 0; y < h; y++) {
          tinta[y * w + xx] = 0;
        }
      }
    }
  }

  // ---- 4. komponen tersambung -------------------------------------------------
  final luasMin = (h * h * 0.0015).ceil().clamp(3, 1 << 30);
  var komponen = _komponen(tinta, w, h, luasMin);
  if (komponen.isEmpty) return const [];

  // ---- 5. gabung yang bertumpuk horizontal -------------------------------------
  komponen.sort((a, b) => a.x0.compareTo(b.x0));
  komponen = _gabungBertumpuk(komponen);

  // ---- 7. koma / titik ----------------------------------------------------------
  final tinggiMaks = komponen
      .map((k) => k.tinggi)
      .reduce((a, b) => a > b ? a : b);
  final besar = [
    for (final k in komponen)
      if (k.tinggi >= tinggiMaks * 0.5) k,
  ];
  final tinggiTengah = _median([for (final k in besar) k.tinggi.toDouble()]);
  final lebarTengah = _median([for (final k in besar) k.lebar.toDouble()]);
  final dasar = _median([for (final k in besar) k.y1.toDouble()]);
  final atas = _median([for (final k in besar) k.y0.toDouble()]);

  final keluar = <KarakterSel>[];
  for (final k in komponen) {
    var jenis = JenisKarakter.tanda;
    final kecil = k.tinggi < tinggiTengah * 0.4 && k.lebar < lebarTengah * 0.7;
    final pusatY = (k.y0 + k.y1) / 2;
    final diBawah = pusatY > atas + (dasar - atas) * 0.6;

    if (kecil && diBawah) {
      // Koma: memanjang ke bawah atau turun melewati garis dasar angka.
      final turun = k.y1 > dasar + tinggiTengah * 0.08;
      jenis = (k.tinggi > k.lebar * 1.3 || turun)
          ? JenisKarakter.koma
          : JenisKarakter.titik;
    }

    keluar.add((
      jenis: jenis,
      kotak: (x: k.x0, y: k.y0, w: k.lebar, h: k.tinggi),
      piksel: _keMnist(k, w),
    ));
  }

  return keluar;
}

/// [segmentasiKarakter] di isolate latar — kerja per piksel.
Future<List<KarakterSel>> segmentasiKarakterDiIsolate(img.Image potongan) =>
    Isolate.run(() => segmentasiKarakter(potongan));

/// Satu karakter hasil segmentasi.
///
/// [piksel] = 28×28 = 784 byte abu-abu, baris demi baris; tinta TERANG (255)
/// di latar gelap (0), gaya MNIST. [kotak] dalam piksel potongan sel.
typedef KarakterSel = ({
  JenisKarakter jenis,
  ({int x, int y, int w, int h}) kotak,
  Uint8List piksel,
});

enum JenisKarakter {
  /// Goresan berukuran karakter — digit atau huruf; BELUM diklasifikasi.
  tanda,

  /// Koma desimal (kecil, di bawah, memanjang/turun melewati garis dasar).
  koma,

  /// Titik (kecil, di bawah, membulat).
  titik,
}

const _rasioGaris = 0.6;
const _selisihAdaptif = 12;
const sisiMnist = 28;
const _sisiIsi = 20;

Uint8List _binerAdaptif(Uint8List abu, int w, int h) {
  // Citra integral (w+1)×(h+1).
  final integral = Int64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var baris = 0;
    for (var x = 0; x < w; x++) {
      baris += abu[y * w + x];
      integral[(y + 1) * (w + 1) + x + 1] =
          integral[y * (w + 1) + x + 1] + baris;
    }
  }

  // Jendela kira-kira setinggi sel, ganjil, minimal 15 px.
  var r = (h ~/ 2).clamp(7, 64);
  if (r < 7) r = 7;

  final keluar = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final y0 = (y - r).clamp(0, h - 1), y1 = (y + r).clamp(0, h - 1);
    for (var x = 0; x < w; x++) {
      final x0 = (x - r).clamp(0, w - 1), x1 = (x + r).clamp(0, w - 1);
      final luas = (x1 - x0 + 1) * (y1 - y0 + 1);
      final jumlah =
          integral[(y1 + 1) * (w + 1) + x1 + 1] -
          integral[y0 * (w + 1) + x1 + 1] -
          integral[(y1 + 1) * (w + 1) + x0] +
          integral[y0 * (w + 1) + x0];
      final rata = jumlah / luas;
      if (abu[y * w + x] < rata - _selisihAdaptif) keluar[y * w + x] = 1;
    }
  }

  return keluar;
}

class _Komp {
  _Komp(this.x0, this.y0, this.x1, this.y1, this.titik);

  int x0, y0, x1, y1;
  final List<int> titik; // indeks piksel y*w+x

  int get lebar => x1 - x0 + 1;
  int get tinggi => y1 - y0 + 1;
}

List<_Komp> _komponen(Uint8List tinta, int w, int h, int luasMin) {
  final label = Int32List(w * h);
  final hasil = <_Komp>[];
  final antre = <int>[];

  for (var mulai = 0; mulai < w * h; mulai++) {
    if (tinta[mulai] == 0 || label[mulai] != 0) continue;

    final id = hasil.length + 1;
    label[mulai] = id;
    antre
      ..clear()
      ..add(mulai);
    final titik = <int>[];
    var x0 = w, y0 = h, x1 = -1, y1 = -1;

    while (antre.isNotEmpty) {
      final i = antre.removeLast();
      titik.add(i);
      final x = i % w, y = i ~/ w;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;

      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final j = yy * w + xx;
          if (tinta[j] == 1 && label[j] == 0) {
            label[j] = id;
            antre.add(j);
          }
        }
      }
    }

    if (titik.length >= luasMin) hasil.add(_Komp(x0, y0, x1, y1, titik));
  }

  return hasil;
}

List<_Komp> _gabungBertumpuk(List<_Komp> urut) {
  final keluar = <_Komp>[];
  for (final k in urut) {
    if (keluar.isNotEmpty) {
      final p = keluar.last;
      final tumpang = (p.x1 < k.x1 ? p.x1 : k.x1) - k.x0 + 1;
      final sempit = p.lebar < k.lebar ? p.lebar : k.lebar;
      if (tumpang > sempit * 0.5) {
        p
          ..x0 = p.x0 < k.x0 ? p.x0 : k.x0
          ..y0 = p.y0 < k.y0 ? p.y0 : k.y0
          ..x1 = p.x1 > k.x1 ? p.x1 : k.x1
          ..y1 = p.y1 > k.y1 ? p.y1 : k.y1
          ..titik.addAll(k.titik);
        continue;
      }
    }
    keluar.add(k);
  }
  return keluar;
}

double _median(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final t = s.length ~/ 2;
  return s.length.isOdd ? s[t] : (s[t - 1] + s[t]) / 2;
}

/// Komponen → 28×28 gaya MNIST (tinta 255 di latar 0), rasio dipertahankan.
Uint8List _keMnist(_Komp k, int w) {
  final sumber = img.Image(width: k.lebar, height: k.tinggi, numChannels: 1);
  for (final i in k.titik) {
    sumber.setPixelR(i % w - k.x0, i ~/ w - k.y0, 255);
  }

  final skala = _sisiIsi / (k.lebar > k.tinggi ? k.lebar : k.tinggi);
  final lb = (k.lebar * skala).round().clamp(1, _sisiIsi);
  final tg = (k.tinggi * skala).round().clamp(1, _sisiIsi);
  final kecil = img.copyResize(
    sumber,
    width: lb,
    height: tg,
    interpolation: img.Interpolation.average,
  );

  final keluar = Uint8List(sisiMnist * sisiMnist);
  final ox = (sisiMnist - lb) ~/ 2, oy = (sisiMnist - tg) ~/ 2;
  for (var y = 0; y < tg; y++) {
    for (var x = 0; x < lb; x++) {
      keluar[(oy + y) * sisiMnist + ox + x] = kecil.getPixel(x, y).r.toInt();
    }
  }

  return keluar;
}

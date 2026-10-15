// Membuat ikon notifikasi Android dari logo berwarna `assets/images/logo_pt_sidik.png`.
//
// Jalankan dari akar repo: `dart run tool/buat_ikon_notifikasi.dart`
//
// Android MEWAJIBKAN small icon monokrom: yang dibaca cuma kanal alpha, lalu
// diwarnai sistem. Logo berwarna dipakai apa adanya jadi kotak putih polos.
// Turunannya:
//   1. piksel "biru" (b - r > 60) = tinta logo; putih/abu = latar,
//   2. dari tinta itu hanya komponen terhubung yang BESAR yang dipertahankan
//      (pita + cincin lingkaran). Tulisan "sidik", pesawat, "CALIBRATION" dan
//      KAN dibuang: di 24dp semuanya cuma jadi bercak,
//   3. hasilnya siluet putih di atas transparan, dipotong rapat lalu dimuat
//      ke kanvas persegi 24dp dengan margin 2dp, dibuat di 5 kepadatan.
// Ikon besar (berwarna) = logo asli, dimuat ke kanvas persegi transparan 256 px.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _kepadatan = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

void main() {
  final sumber = img.decodePng(
    File('assets/images/logo_pt_sidik.png').readAsBytesSync(),
  )!;
  final w = sumber.width, h = sumber.height;

  bool tinta(int x, int y) {
    final p = sumber.getPixel(x, y);
    if (p.a < 128) return false;
    return p.b - p.r > 60;
  }

  // Komponen terhubung (4-arah).
  final label = List.filled(w * h, -1);
  final ukuran = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (label[y * w + x] != -1 || !tinta(x, y)) continue;
      final id = ukuran.length;
      var n = 0;
      final tumpuk = <int>[y * w + x];
      label[y * w + x] = id;
      while (tumpuk.isNotEmpty) {
        final i = tumpuk.removeLast();
        n++;
        final cx = i % w, cy = i ~/ w;
        for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = cx + dx, ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          if (label[ny * w + nx] != -1 || !tinta(nx, ny)) continue;
          label[ny * w + nx] = id;
          tumpuk.add(ny * w + nx);
        }
      }
      ukuran.add(n);
    }
  }
  // Pertahankan komponen >= 12% dari yang terbesar.
  final maks = ukuran.reduce(math.max);
  final simpan = {
    for (var i = 0; i < ukuran.length; i++)
      if (ukuran[i] >= maks * 0.12) i,
  };
  stdout.writeln('komponen: ${ukuran.length}, dipertahankan: ${simpan.length}');

  final mask = img.Image(width: w, height: h, numChannels: 4);
  var minX = w, minY = h, maxX = 0, maxY = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (simpan.contains(label[y * w + x])) {
        mask.setPixelRgba(x, y, 255, 255, 255, 255);
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }
  final potong = img.copyCrop(
    mask,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  img.Image kanvas(img.Image isi, int sisi, double margin) {
    final dalam = (sisi * (1 - 2 * margin)).round();
    final skala = dalam / math.max(isi.width, isi.height);
    final kecil = img.copyResize(
      isi,
      width: (isi.width * skala).round(),
      height: (isi.height * skala).round(),
      interpolation: img.Interpolation.average,
    );
    final out = img.Image(width: sisi, height: sisi, numChannels: 4);
    img.compositeImage(
      out,
      kecil,
      dstX: (sisi - kecil.width) ~/ 2,
      dstY: (sisi - kecil.height) ~/ 2,
    );
    return out;
  }

  final res = 'android/app/src/main/res';
  _kepadatan.forEach((nama, px) {
    final dir = Directory('$res/drawable-$nama')..createSync(recursive: true);
    File(
      '${dir.path}/ic_stat_sidik.png',
    ).writeAsBytesSync(img.encodePng(kanvas(potong, px, 2 / 24)));
  });

  final besar = kanvas(sumber, 256, 0.04);
  final dirBesar = Directory('$res/drawable-nodpi')
    ..createSync(recursive: true);
  File(
    '${dirBesar.path}/ic_notif_besar.png',
  ).writeAsBytesSync(img.encodePng(besar));
  // Pratinjau siluet di latar abu supaya bisa diperiksa mata.
  final pratinjau = img.Image(width: 192, height: 192)
    ..clear(img.ColorRgb8(90, 90, 90));
  img.compositeImage(pratinjau, kanvas(potong, 192, 2 / 24));
  File(
    '${Directory.systemTemp.path}/pratinjau_ic_stat_sidik.png',
  ).writeAsBytesSync(img.encodePng(pratinjau));
  stdout.writeln('selesai');
}

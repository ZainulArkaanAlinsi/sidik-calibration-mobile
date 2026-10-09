import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Rasio piksel gelap di BAGIAN DALAM satu kotak centang — PANDUAN §4: centang
/// dibaca dari tinta, BUKAN OCR. Angkanya dikirim apa adanya sebagai
/// `centang[].rasio_gelap`; yang memutuskan dicentang/kosong/ragu server
/// (`ocr.centang.ambang_*`), supaya aturannya sama di semua versi APK.
///
/// ## Kenapa bukan rasio seluruh kotak
///
/// Kotak centang TERCETAK punya bingkai. Bingkai 1 pt di kotak 8 pt sudah
/// ±35% luasnya — kotak kosong akan terbaca "tercentang" di ambang server
/// (≥ 0,15). Jadi yang diukur cuma isi di dalam bingkai.
///
/// ## Kenapa bingkainya dicari ulang, bukan dipercaya dari geometri
///
/// Homography yang lolos server masih boleh meleset ±1,5 pt rata-rata, dan
/// kotak centang cuma ±8 pt. Meleset 2 pt cukup buat menyeret satu sisi
/// bingkai masuk ke bagian dalam — centang palsu lagi. Maka posisi kotak
/// disetel lokal: geser kecil yang membuat KEEMPAT sisi bujursangkar paling
/// gelap. Tulisan di sebelah kotak (`TH-2`) tidak membentuk bujursangkar,
/// jadi tidak menang. Kalau bingkainya tidak cukup gelap untuk ditemukan
/// (cetakan abu-abu tipis), posisi geometri dipakai apa adanya — bingkai yang
/// tidak gelap juga tidak ikut terhitung sebagai tinta.
///
/// `null` = tidak bisa diukur (kotak terlalu kecil di citra, atau citranya
/// terlalu gelap untuk membedakan tinta dari kertas). Server memperlakukannya
/// MERAH "tidak terbaca" — bukan dianggap kosong.
double? rasioGelapCentang(
  img.Image warp, {
  required double x,
  required double y,
  required double w,
  required double h,
}) {
  final bw = w.round();
  final bh = h.round();
  if (bw < 6 || bh < 6) return null;

  final bx = x.round();
  final by = y.round();
  final r = math.max(3, (math.max(bw, bh) * 0.4).round());

  double lum(int px, int py) {
    if (px < 0 || py < 0 || px >= warp.width || py >= warp.height) return 255;
    final p = warp.getPixel(px, py);

    return p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
  }

  // Tingkat KERTAS = persentil 90 kecerahan di jendela pencarian. Ambang tinta
  // relatif terhadap kertas, bukan angka mati: foto di ruang redup membuat
  // kertas putih jadi abu-abu, dan ambang mati akan menghitung kertasnya
  // sendiri sebagai tinta.
  final contoh = <double>[
    for (var py = by - r; py < by + bh + r; py++)
      for (var px = bx - r; px < bx + bw + r; px++) lum(px, py),
  ]..sort();
  final kertas =
      contoh[(contoh.length * 0.9).floor().clamp(0, contoh.length - 1)];
  if (kertas < 60) return null;

  final ambang = kertas * 0.6;
  bool gelap(int px, int py) => lum(px, py) < ambang;

  // Skor bingkai di geseran (dx, dy): bagian dari keliling bujursangkar yang
  // gelap (toleransi tebal ±1 px).
  double skorBingkai(int dx, int dy) {
    final x0 = bx + dx;
    final y0 = by + dy;
    final x1 = x0 + bw - 1;
    final y1 = y0 + bh - 1;
    var kena = 0;
    var total = 0;

    bool gelapTebal(int px, int py, {required bool mendatar}) {
      for (var t = -1; t <= 1; t++) {
        if (mendatar ? gelap(px, py + t) : gelap(px + t, py)) return true;
      }

      return false;
    }

    for (var px = x0; px <= x1; px++) {
      total += 2;
      if (gelapTebal(px, y0, mendatar: true)) kena++;
      if (gelapTebal(px, y1, mendatar: true)) kena++;
    }
    for (var py = y0 + 1; py < y1; py++) {
      total += 2;
      if (gelapTebal(x0, py, mendatar: false)) kena++;
      if (gelapTebal(x1, py, mendatar: false)) kena++;
    }

    return total == 0 ? 0 : kena / total;
  }

  var geserX = 0;
  var geserY = 0;
  var skorTerbaik = skorBingkai(0, 0);

  for (var dy = -r; dy <= r; dy++) {
    for (var dx = -r; dx <= r; dx++) {
      final s = skorBingkai(dx, dy);
      // Seri dimenangkan geseran terkecil — posisi geometri lebih dipercaya
      // daripada geseran yang sama bagusnya.
      if (s > skorTerbaik ||
          (s == skorTerbaik &&
              dx.abs() + dy.abs() < geserX.abs() + geserY.abs())) {
        skorTerbaik = s;
        geserX = dx;
        geserY = dy;
      }
    }
  }

  // Bingkai tidak meyakinkan → posisi geometri apa adanya.
  if (skorTerbaik < 0.6) {
    geserX = 0;
    geserY = 0;
  }

  // Bagian dalam: masuk 20% dari tiap sisi (min 2 px) — melewati bingkai
  // berikut ketebalannya.
  final masuk = math.max(2, (math.min(bw, bh) * 0.2).round());
  final ix0 = bx + geserX + masuk;
  final iy0 = by + geserY + masuk;
  final ix1 = bx + geserX + bw - 1 - masuk;
  final iy1 = by + geserY + bh - 1 - masuk;
  if (ix1 - ix0 < 1 || iy1 - iy0 < 1) return null;

  var tinta = 0;
  var semua = 0;
  for (var py = iy0; py <= iy1; py++) {
    for (var px = ix0; px <= ix1; px++) {
      semua++;
      if (gelap(px, py)) tinta++;
    }
  }

  return semua == 0 ? null : tinta / semua;
}

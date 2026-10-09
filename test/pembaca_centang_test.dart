import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/services/pembaca_centang.dart';

/// Pembaca kotak centang formulir asli — rasio piksel gelap, BUKAN OCR
/// (PANDUAN-OCR-LEMBAR-KERJA.md §4).
///
/// Ambang yang dipakai buat menilai di sini SALINAN ambang server
/// (`config/ocr.php` → `ocr.centang.ambang_tercentang` 0,15 /
/// `ambang_kosong` 0,05, repo API 3222d1b). HP tidak memutuskan — tapi angka
/// yang dikirimnya harus jatuh di sisi yang benar dari ambang itu.
///
/// Ukuran kotak ditiru dari formulir pH di kanvas 3 px/pt: kotak centang
/// ±8,3×8 pt (`kotak_centang` draf: w 0,01051 × 792, h 0,01299 × 612) ≈
/// 25×24 px, bingkai cetak ±1 pt ≈ 3 px.
void main() {
  const tercentang = 0.15;
  const kosong = 0.05;

  // Kotak menurut GEOMETRI (yang dikirim server).
  const x = 60.0, y = 50.0, w = 25.0, h = 24.0;

  img.Image kanvas() {
    final c = img.Image(width: 160, height: 130);
    img.fill(c, color: img.ColorRgb8(226, 224, 220));

    return c;
  }

  void bingkai(img.Image c, {int dx = 0, int dy = 0}) {
    img.drawRect(
      c,
      x1: x.toInt() + dx,
      y1: y.toInt() + dy,
      x2: (x + w).toInt() - 1 + dx,
      y2: (y + h).toInt() - 1 + dy,
      color: img.ColorRgb8(30, 30, 30),
      thickness: 3,
    );
  }

  void silang(img.Image c, {int dx = 0, int dy = 0}) {
    final tinta = img.ColorRgb8(20, 30, 90);
    img.drawLine(
      c,
      x1: x.toInt() + 5 + dx,
      y1: y.toInt() + 5 + dy,
      x2: (x + w).toInt() - 6 + dx,
      y2: (y + h).toInt() - 6 + dy,
      color: tinta,
      thickness: 3,
    );
    img.drawLine(
      c,
      x1: (x + w).toInt() - 6 + dx,
      y1: y.toInt() + 5 + dy,
      x2: x.toInt() + 5 + dx,
      y2: (y + h).toInt() - 6 + dy,
      color: tinta,
      thickness: 3,
    );
  }

  double? baca(img.Image c) => rasioGelapCentang(c, x: x, y: y, w: w, h: h);

  test('kotak kosong: bingkai cetaknya TIDAK dihitung tinta', () {
    final c = kanvas();
    bingkai(c);

    // Rasio seluruh kotak di sini ±35% — kalau bingkainya ikut, kotak kosong
    // terbaca "tercentang".
    expect(baca(c), lessThanOrEqualTo(kosong));
  });

  test('kotak bertanda silang → di atas ambang tercentang', () {
    final c = kanvas();
    bingkai(c);
    silang(c);

    expect(baca(c), greaterThanOrEqualTo(tercentang));
  });

  test('coretan tipis pendek → di zona ragu (antara dua ambang)', () {
    final c = kanvas();
    bingkai(c);
    img.drawLine(
      c,
      x1: x.toInt() + 8,
      y1: y.toInt() + 11,
      x2: x.toInt() + 16,
      y2: y.toInt() + 12,
      color: img.ColorRgb8(40, 40, 110),
      thickness: 2,
    );

    final r = baca(c)!;
    expect(r, greaterThan(kosong));
    expect(r, lessThan(tercentang));
  });

  test(
    'geometri meleset 4 px: bingkai dicari ulang, kotak kosong tetap kosong',
    () {
      // ±1,3 pt di 3 px/pt — masih di bawah residual yang diterima server
      // rata-ratanya, tapi cukup untuk menyeret satu sisi bingkai ke dalam.
      final c = kanvas();
      bingkai(c, dx: 4, dy: -3);

      expect(baca(c), lessThanOrEqualTo(kosong));
    },
  );

  test('geometri meleset 4 px: kotak bersilang tetap tercentang', () {
    final c = kanvas();
    bingkai(c, dx: 4, dy: -3);
    silang(c, dx: 4, dy: -3);

    expect(baca(c), greaterThanOrEqualTo(tercentang));
  });

  test('tulisan "TH-2" di sebelah kotak tidak dikira bingkai', () {
    final c = kanvas();
    bingkai(c);
    // Huruf tebal mepet di kanan kotak, seperti label pilihan TH-n.
    img.fillRect(
      c,
      x1: (x + w).toInt() + 3,
      y1: y.toInt() + 2,
      x2: (x + w).toInt() + 6,
      y2: (y + h).toInt() - 3,
      color: img.ColorRgb8(25, 25, 25),
    );

    expect(baca(c), lessThanOrEqualTo(kosong));
  });

  test(
    'kotak terlalu kecil atau citra terlalu gelap → null, bukan "kosong"',
    () {
      final c = kanvas();
      expect(rasioGelapCentang(c, x: x, y: y, w: 4, h: 4), isNull);

      final gelap = img.Image(width: 160, height: 130);
      img.fill(gelap, color: img.ColorRgb8(30, 30, 30));
      expect(baca(gelap), isNull);
    },
  );
}

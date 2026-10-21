import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/services/segmentasi_karakter.dart';

/// Segmentasi karakter di potongan sel SINTETIS: angka digambar dengan font
/// bitmap paket `image`, dikurung garis kotak tabel, di kertas agak kusam.
void main() {
  img.Image sel(String teks, {bool kotak = true, int lebar = 260}) {
    final c = img.Image(width: lebar, height: 80);
    img.fill(c, color: img.ColorRgb8(225, 222, 215));
    // Bayangan di kiri — binarisasi global akan menghitamkannya.
    for (var y = 0; y < 80; y++) {
      for (var x = 0; x < 40; x++) {
        final v = 170 + x;
        c.setPixelRgb(x, y, v, v, v - 5);
      }
    }
    if (kotak) {
      img.drawRect(
        c,
        x1: 1,
        y1: 1,
        x2: lebar - 2,
        y2: 78,
        color: img.ColorRgb8(30, 30, 30),
        thickness: 2,
      );
    }
    img.drawString(
      c,
      teks,
      font: img.arial48,
      x: 50,
      y: 12,
      color: img.ColorRgb8(20, 20, 60),
    );
    return c;
  }

  test('49,99 dalam kotak: 5 karakter, urut, koma di indeks 2', () {
    final k = segmentasiKarakter(sel('49,99'));

    expect(k.map((e) => e.jenis), [
      JenisKarakter.tanda,
      JenisKarakter.tanda,
      JenisKarakter.koma,
      JenisKarakter.tanda,
      JenisKarakter.tanda,
    ]);
    for (var i = 1; i < k.length; i++) {
      expect(k[i].kotak.x, greaterThan(k[i - 1].kotak.x));
    }
    for (final c in k) {
      expect(c.piksel, hasLength(sisiMnist * sisiMnist));
      expect(c.piksel.any((p) => p > 128), isTrue);
    }
  });

  test('50.12: titik terdeteksi sebagai titik', () {
    final k = segmentasiKarakter(sel('50.12'));

    expect(k, hasLength(5));
    expect(k[2].jenis, JenisKarakter.titik);
    expect(k.where((e) => e.jenis != JenisKarakter.tanda), hasLength(1));
  });

  test('garis kotak tidak menjadi karakter', () {
    final tanpa = segmentasiKarakter(sel('7', kotak: false));
    final dengan = segmentasiKarakter(sel('7'));

    expect(tanpa, hasLength(1));
    expect(dengan, hasLength(1));
  });

  test('sel kosong (hanya kotak) → nol karakter', () {
    expect(segmentasiKarakter(sel('')), isEmpty);
  });

  test('versi isolate sama dengan versi langsung', () async {
    final c = sel('3,5');
    final a = segmentasiKarakter(c);
    final b = await segmentasiKarakterDiIsolate(c);

    expect(b.map((e) => e.jenis), a.map((e) => e.jenis));
    expect(b.map((e) => e.kotak), a.map((e) => e.kotak));
  });
}

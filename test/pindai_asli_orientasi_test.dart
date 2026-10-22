import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';

/// Penggabungan panggang-EXIF + putar (hemat memori di HP RAM kecil) WAJIB
/// menghasilkan piksel yang identik dengan jalur lama dua langkah
/// `copyRotate(bakeOrientation(foto), s)` — kalau beda, potongan sel yang
/// dibaca OCR ikut bergeser.
void main() {
  img.Image fotoUji(int orientasi) {
    // Persegi panjang (bukan persegi) supaya tertukarnya lebar/tinggi kelihatan;
    // tiap piksel unik supaya permutasi yang salah pasti ketahuan.
    final f = img.Image(width: 7, height: 4);
    for (var y = 0; y < f.height; y++) {
      for (var x = 0; x < f.width; x++) {
        f.setPixelRgb(x, y, x * 30, y * 60, (x + y * 7) * 8);
      }
    }
    f.exif.imageIfd.orientation = orientasi;
    return f;
  }

  void samaPersis(img.Image a, img.Image b, String alasan) {
    expect(a.width, b.width, reason: alasan);
    expect(a.height, b.height, reason: alasan);
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        final pa = a.getPixel(x, y);
        final pb = b.getPixel(x, y);
        expect(
          [pa.r, pa.g, pa.b],
          [pb.r, pb.g, pb.b],
          reason: '$alasan ($x,$y)',
        );
      }
    }
  }

  for (final orientasi in [1, 2, 3, 4, 5, 6, 7, 8]) {
    for (final sudut in [0, 90, 180, 270]) {
      test('orientasi $orientasi + putar $sudut = jalur lama', () {
        final lama = img.copyRotate(
          img.bakeOrientation(fotoUji(orientasi)),
          angle: sudut,
        );
        final baru = tegakkanDanPutar(fotoUji(orientasi), sudut);

        samaPersis(baru, lama, 'o$orientasi s$sudut');
        if (orientasi != 1) {
          expect(baru.exif.imageIfd.orientation, isNull);
        }
      });
    }
  }

  test('foto asli tidak diubah', () {
    final f = fotoUji(6);
    tegakkanDanPutar(f, 90);
    expect(f.width, 7);
    expect(f.exif.imageIfd.orientation, 6);
  });
}

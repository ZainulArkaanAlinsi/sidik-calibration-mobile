import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/ocr_angka/pagar_tinta.dart';

/// Pagar tinta: crop praktis kosong tidak dikirim ke model. Angka ambangnya dari
/// set uji sintetis (lihat docs/ocr-angka-onnx.md); di sini hanya perilakunya.
void main() {
  img.Image kertas({int w = 160, int h = 60, int abu = 235}) {
    final i = img.Image(width: w, height: h, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(abu, abu, abu));
    return i;
  }

  void tulis(img.Image i, int x0, int x1, int y0, int y1, [int abu = 30]) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        i.setPixelRgb(x, y, abu, abu, abu);
      }
    }
  }

  test('kertas polos -> tidak ada tinta', () {
    final u = PagarTinta.ukur(kertas());

    expect(u.gelap, 0.0);
    expect(u.kontras, closeTo(0.0, 1e-9));
    expect(PagarTinta.adaTinta(u), isFalse);
  });

  test(
    'kertas gelap atau terang merata tetap polos (kertas = persentil 90)',
    () {
      for (final abu in [90, 160, 250]) {
        expect(
          PagarTinta.adaTinta(PagarTinta.ukur(kertas(abu: abu))),
          isFalse,
          reason: 'abu $abu',
        );
      }
    },
  );

  test('goresan di tengah -> ada tinta', () {
    final i = kertas();
    tulis(i, 60, 66, 15, 45); // goresan vertikal tebal 6 px

    final u = PagarTinta.ukur(i);
    expect(u.gelap, greaterThan(0.02));
    expect(u.kontras, greaterThan(0.5));
    expect(PagarTinta.adaTinta(u), isTrue);
  });

  test(
    'goresan tipis tapi gelap tetap lolos (tidak boleh membuang tulisan)',
    () {
      final i = kertas(w: 200, h: 80);
      tulis(i, 98, 99, 20, 60); // 1 px lebar, 40 px tinggi di jendela tengah

      expect(PagarTinta.adaTinta(PagarTinta.ukur(i)), isTrue);
    },
  );

  test(
    'tinta di pinggiran (garis sel) diabaikan: kotak + isi kosong -> tidak ada tinta',
    () {
      final i = kertas();
      tulis(i, 0, 3, 0, 60); // garis kiri
      tulis(i, 157, 160, 0, 60); // garis kanan
      tulis(i, 0, 160, 0, 3); // garis atas
      tulis(i, 0, 160, 57, 60); // garis bawah

      expect(PagarTinta.adaTinta(PagarTinta.ukur(i)), isFalse);
    },
  );

  test(
    'garis tengah menyilang LOLOS pagar (ditahan gerbang format, bukan pagar ini)',
    () {
      final i = kertas();
      tulis(i, 0, 160, 29, 31, 60); // garis mendatar tipis menyilang

      // Batas yang diketahui: ukuran tinta tidak membedakan garis dari tulisan
      // tanpa membuang jawaban benar (lihat docs/ocr-angka-onnx.md).
      expect(PagarTinta.adaTinta(PagarTinta.ukur(i)), isTrue);
    },
  );

  test('citra tanpa piksel: tidak ada tinta, tidak melempar', () {
    final u = PagarTinta.ukur(img.Image(width: 0, height: 0));

    expect(PagarTinta.adaTinta(u), isFalse);
  });

  test('citra kecil sekali tidak melempar', () {
    final u = PagarTinta.ukur(kertas(w: 3, h: 3));
    expect(u.gelap, 0.0);
  });

  test('ambang: kedua ukuran harus rendah untuk ditolak', () {
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.0, kontras: 0.0)),
      isFalse,
    );
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.0, kontras: 0.5)),
      isTrue,
    );
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.2, kontras: 0.0)),
      isTrue,
    );
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.002, kontras: 0.02)),
      isTrue,
      reason: 'tepat di ambang: lolos',
    );
  });
}

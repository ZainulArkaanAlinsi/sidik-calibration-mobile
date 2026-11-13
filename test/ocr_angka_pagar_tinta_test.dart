import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/ocr_angka/pagar_tinta.dart';

/// Pagar tinta: crop praktis kosong tidak dikirim ke model. Sejak 13 Nov 2026
/// HANYA `gelap` yang menentukan (cabang kontras kena tekstur kertas di foto
/// nyata); ambangnya sementara, dari dua foto (lihat `PagarTinta.gelapMin`).
/// Di sini hanya perilakunya.
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
    'goresan 1 px di crop lebar KINI tidak lolos (dulu lolos lewat cabang kontras)',
    () {
      final i = kertas(w: 200, h: 80);
      tulis(i, 98, 99, 20, 60); // 1 px lebar, 40 px tinggi di jendela tengah

      final u = PagarTinta.ukur(i);
      // Kontras tinggi (satu goresan gelap di kertas polos) tetapi porsi gelap
      // ±0,005 < gelapMin. Batas yang diketahui dari keputusan 13 Nov 2026.
      expect(u.gelap, lessThan(PagarTinta.gelapMin));
      expect(PagarTinta.adaTinta(u), isFalse);
    },
  );

  test(
    'goresan tipis di crop yang sudah dipangkas ke tinta (hasil PemotongSel) lolos',
    () {
      final i = kertas(w: 60, h: 60);
      tulis(i, 29, 31, 10, 50); // 2 px × 40 px, crop hanya sedikit lebih besar

      expect(PagarTinta.adaTinta(PagarTinta.ukur(i)), isTrue);
    },
  );

  test(
    'tekstur kertas berkontras tinggi tanpa tinta: TIDAK lolos (cabang kontras dicabut)',
    () {
      // Kertas ±200 dengan derau ±30: persentil 98 − median besar, tapi tidak
      // ada piksel yang segelap tinta (> 0,30 di bawah kertas).
      final rnd = math.Random(3);
      final i = img.Image(width: 160, height: 60, numChannels: 3);
      for (var y = 0; y < 60; y++) {
        for (var x = 0; x < 160; x++) {
          final v = 200 + rnd.nextInt(61) - 30;
          i.setPixelRgb(x, y, v, v, v);
        }
      }

      final u = PagarTinta.ukur(i);
      expect(
        u.kontras,
        greaterThan(0.05),
        reason: 'cabang lama akan meloloskan',
      );
      expect(u.gelap, 0.0);
      expect(PagarTinta.adaTinta(u), isFalse);
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

  test(
    'ambang dikunci dari DUA sisi pada kerapatan antara (0,014 ditolak, 0,026 lolos)',
    () {
      // Jendela tengah 100×100 dengan margin 15% = 70×70 = 4.900 piksel. Blok
      // gelap penuh di dalamnya: 7×10 = 70 piksel -> 0,0143; 7×18 = 126 -> 0,0257.
      img.Image blok(int tinggi) {
        final i = kertas(w: 100, h: 100);
        tulis(i, 40, 47, 30, 30 + tinggi);

        return i;
      }

      final sedikit = PagarTinta.ukur(blok(10));
      final cukup = PagarTinta.ukur(blok(18));

      expect(sedikit.gelap, closeTo(70 / 4900, 1e-9));
      expect(cukup.gelap, closeTo(126 / 4900, 1e-9));
      // Ambang yang terlalu rendah (mis. 0,005) meloloskan yang pertama; yang
      // terlalu tinggi (mis. 0,04) menolak yang kedua.
      expect(
        PagarTinta.adaTinta(sedikit),
        isFalse,
        reason: '0,014 < gelapMin: dianggap kosong',
      );
      expect(
        PagarTinta.adaTinta(cukup),
        isTrue,
        reason: '0,026 >= gelapMin: berisi',
      );
    },
  );

  test('ambang: hanya gelap yang menentukan', () {
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.0, kontras: 0.0)),
      isFalse,
    );
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.0, kontras: 0.5)),
      isFalse,
      reason: 'kontras tidak lagi menyelamatkan crop',
    );
    expect(
      PagarTinta.adaTinta(const UkuranTinta(gelap: 0.2, kontras: 0.0)),
      isTrue,
    );
    expect(
      PagarTinta.adaTinta(
        const UkuranTinta(gelap: PagarTinta.gelapMin, kontras: 0.0),
      ),
      isTrue,
      reason: 'tepat di ambang: lolos',
    );
    expect(
      PagarTinta.adaTinta(
        UkuranTinta(gelap: PagarTinta.gelapMin - 1e-6, kontras: 0.9),
      ),
      isFalse,
    );
    expect(
      PagarTinta.adaTinta(UkuranTinta(gelap: double.nan, kontras: 0.9)),
      isFalse,
      reason: 'NaN ditahan, bukan lolos',
    );
  });
}

import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/skema_dinamis.dart';
import 'package:sidik_calibration/widgets/dinamis/sorot_kotak_foto.dart';

/// Kesalahan di sini jenisnya paling jahat: sorotannya TETAP MUNCUL, cuma
/// menunjuk sel yang keliru. Teknisi yang membandingkan angka dengan kotak yang
/// salah bakal "membetulkan" angka yang sebenarnya sudah benar.
void main() {
  KotakBatas kotak(double x, double y, double l, double t) =>
      KotakBatas(x: x, y: y, lebar: l, tinggi: t);

  group('skala murni (tanpa letterbox)', () {
    test('citra dan tampilan serasio: cuma diskalakan', () {
      // 1000x500 -> 500x250, skala 0.5, nggak ada bilah kosong.
      final r = kotakTampil(
        kotak: kotak(100, 200, 40, 20),
        ukuranCitra: const Size(1000, 500),
        ukuranTampil: const Size(500, 250),
      )!;

      expect(r.left, 50);
      expect(r.top, 100);
      expect(r.width, 20);
      expect(r.height, 10);
    });

    test('ukuran sama: kotaknya nggak bergeser sama sekali', () {
      final r = kotakTampil(
        kotak: kotak(10, 20, 30, 40),
        ukuranCitra: const Size(800, 600),
        ukuranTampil: const Size(800, 600),
      )!;

      expect(r, const Rect.fromLTWH(10, 20, 30, 40));
    });
  });

  group('letterbox — bagian yang paling gampang kelewat', () {
    test('citra POTRET di kotak lebar: bilah kosong KIRI-KANAN', () {
      // Citra 500x1000 di kotak 400x400.
      // skala = min(400/500, 400/1000) = 0.4
      // lebar tampil = 200 -> bilah kiri = (400-200)/2 = 100
      // tinggi tampil = 400 -> bilah atas = 0
      final r = kotakTampil(
        kotak: kotak(0, 0, 50, 50),
        ukuranCitra: const Size(500, 1000),
        ukuranTampil: const Size(400, 400),
      )!;

      expect(
        r.left,
        100,
        reason: 'tanpa offset, sorotan meleset 100px ke kiri',
      );
      expect(r.top, 0);
      expect(r.width, 20);
      expect(r.height, 20);
    });

    test('citra LANSKAP di kotak tinggi: bilah kosong ATAS-BAWAH', () {
      // Citra 1000x500 di kotak 400x400.
      // skala = min(0.4, 0.8) = 0.4 -> tinggi tampil 200 -> bilah atas 100
      final r = kotakTampil(
        kotak: kotak(0, 0, 100, 100),
        ukuranCitra: const Size(1000, 500),
        ukuranTampil: const Size(400, 400),
      )!;

      expect(r.left, 0);
      expect(r.top, 100, reason: 'tanpa offset, sorotan meleset 100px ke atas');
      expect(r.width, 40);
      expect(r.height, 40);
    });

    test('sudut kanan-bawah citra mendarat di sudut kanan-bawah tampilan', () {
      // Bukti offset & skalanya konsisten di ujung yang jauh dari titik nol —
      // salah tanda pada offset masih lolos kalau cuma menguji pojok kiri atas.
      final r = kotakTampil(
        kotak: kotak(490, 990, 10, 10),
        ukuranCitra: const Size(500, 1000),
        ukuranTampil: const Size(400, 400),
      )!;

      expect(r.right, 300, reason: 'tepi kanan citra = 100 + 200');
      expect(r.bottom, 400);
    });
  });

  group('kotak yang koordinatnya nggak masuk akal', () {
    test('sepenuhnya di luar citra -> null, BUKAN dijepit ke tepi', () {
      final r = kotakTampil(
        kotak: kotak(2000, 2000, 50, 50),
        ukuranCitra: const Size(1000, 500),
        ukuranTampil: const Size(400, 400),
      );

      expect(
        r,
        isNull,
        reason:
            'dijepit ke tepi, sorotannya menunjuk tempat salah dengan yakin',
      );
    });

    test('lewat tepi sebagian tetap digambar', () {
      // Wajar: sel yang mepet tepi kertas.
      final r = kotakTampil(
        kotak: kotak(950, 100, 100, 50),
        ukuranCitra: const Size(1000, 500),
        ukuranTampil: const Size(1000, 500),
      );

      expect(r, isNotNull);
      expect(r!.left, 950);
    });

    test('ukuran citra nol nggak bikin pembagian nol', () {
      expect(
        kotakTampil(
          kotak: kotak(10, 10, 10, 10),
          ukuranCitra: Size.zero,
          ukuranTampil: const Size(400, 400),
        ),
        isNull,
      );

      expect(
        kotakTampil(
          kotak: kotak(10, 10, 10, 10),
          ukuranCitra: const Size(400, 400),
          ukuranTampil: Size.zero,
        ),
        isNull,
      );
    });
  });
}

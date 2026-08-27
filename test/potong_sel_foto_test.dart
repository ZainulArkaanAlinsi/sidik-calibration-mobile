import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/peta_tabel_foto.dart';
import 'package:sidik_calibration/services/potong_sel_foto.dart';

/// Kotak sel → citra sel. Tahap pertama model pengenal angka sendiri.
///
/// ## Yang dijaga di sini
///
/// Potongan yang MELESET lebih berbahaya daripada potongan yang nggak ada,
/// dan alasannya sama seperti di `kotak_sel_geometri_test.dart`: potongan
/// meleset tetap dipasangkan dengan angka yang diketik teknisi, jadi modelnya
/// belajar bahwa coretan tetangga bernama angka sel ini. Salah yang percaya
/// diri, dan datanya sendiri yang bohong.
///
/// Makanya test di sini menguji ISI potongannya, bukan cuma ukurannya — citra
/// contohnya sengaja diberi warna beda per sel supaya potongan yang bergeser
/// ketahuan dari piksel yang terbawa.
void main() {
  /// Citra contoh: tiap sel diberi satu warna sendiri, jadi potongan yang
  /// bergeser langsung ketahuan.
  ///
  /// Petaknya 100×50, tiga kolom × dua baris, mulai dari (0,0).
  img.Image citraPetak() {
    final citra = img.Image(width: 300, height: 100);

    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 300; x++) {
        final kolom = x ~/ 100;
        final baris = y ~/ 50;

        citra.setPixelRgb(x, y, 40 + kolom * 60, 40 + baris * 60, 128);
      }
    }

    return citra;
  }

  KotakSelFoto kotak(double l, double t, double w, double h) => (
    titikUkur: 100.0,
    repeatNo: 1,
    fieldId: 'pembacaan',
    kotak: Rect.fromLTWH(l, t, w, h),
    teks: null,
  );

  /// Warna di tengah potongan — sidik jari petak asalnya.
  ({int r, int g, int b}) tengah(img.Image p) {
    final piksel = p.getPixel(p.width ~/ 2, p.height ~/ 2);

    return (r: piksel.r.toInt(), g: piksel.g.toInt(), b: piksel.b.toInt());
  }

  test('potongannya persis sebesar kotaknya', () {
    final hasil = const PotongSelFoto().potong(
      citra: citraPetak(),
      kotak: [kotak(10, 10, 80, 40)],
    );

    expect(hasil.gagal, 0);
    expect(hasil.potongan, hasLength(1));
    expect(hasil.potongan.first.potongan.width, 80);
    expect(hasil.potongan.first.potongan.height, 40);
  });

  test('potongannya diambil dari PETAK YANG BENAR, bukan yang bergeser', () {
    // Ini inti berkas ini. Ukuran yang benar dengan isi yang salah itu
    // kegagalan yang paling mahal, dan satu-satunya yang bisa membedakannya
    // isi pikselnya.
    final hasil = const PotongSelFoto().potong(
      citra: citraPetak(),
      kotak: [
        kotak(110, 10, 80, 30), // petak kolom 1, baris 0
        kotak(210, 60, 80, 30), // petak kolom 2, baris 1
      ],
    );

    expect(hasil.potongan, hasLength(2));

    // kolom 1 baris 0 → r = 40 + 1*60 = 100, g = 40 + 0*60 = 40
    expect(tengah(hasil.potongan[0].potongan), (r: 100, g: 40, b: 128));

    // kolom 2 baris 1 → r = 40 + 2*60 = 160, g = 40 + 1*60 = 100
    expect(tengah(hasil.potongan[1].potongan), (r: 160, g: 100, b: 128));
  });

  test('asal-usul selnya ikut terbawa', () {
    // Tanpa ini potongan cuma tumpukan gambar tanpa nama, dan nggak ada cara
    // memasangkannya dengan angka yang diketik teknisi.
    final asal = kotak(10, 10, 80, 40);

    final hasil = const PotongSelFoto().potong(
      citra: citraPetak(),
      kotak: [asal],
    );

    expect(hasil.potongan.first.kotak, asal);
  });

  group('kotak yang nggak muat', () {
    test('yang lewat tepi kanan DIBUANG, bukan dijepit masuk', () {
      // Dijepit, yang keluar bukan sel ini melainkan potongan yang bergeser —
      // isinya sebagian sel tetangga, tapi tetap dilabeli angka sel ini.
      final hasil = const PotongSelFoto().potong(
        citra: citraPetak(),
        kotak: [kotak(250, 10, 80, 40)], // 250 + 80 = 330 > 300
      );

      expect(hasil.potongan, isEmpty);
      expect(hasil.gagal, 1);
    });

    test('yang tepinya negatif juga dibuang', () {
      final hasil = const PotongSelFoto().potong(
        citra: citraPetak(),
        kotak: [kotak(-10, 10, 80, 40)],
      );

      expect(hasil.potongan, isEmpty);
      expect(hasil.gagal, 1);
    });

    test('yang lewat tepi bawah juga dibuang', () {
      final hasil = const PotongSelFoto().potong(
        citra: citraPetak(),
        kotak: [kotak(10, 80, 80, 40)], // 80 + 40 = 120 > 100
      );

      expect(hasil.potongan, isEmpty);
      expect(hasil.gagal, 1);
    });

    test('ukuran nol dibuang, bukan bikin potongan kosong', () {
      final hasil = const PotongSelFoto().potong(
        citra: citraPetak(),
        kotak: [kotak(10, 10, 0.4, 40)], // membulat jadi 0
      );

      expect(hasil.potongan, isEmpty);
      expect(hasil.gagal, 1);
    });

    test('yang muat tetap dipotong walau ada tetangganya yang dibuang', () {
      // Penjaga arah: "diperketat" gampang jadi "semuanya hilang".
      final hasil = const PotongSelFoto().potong(
        citra: citraPetak(),
        kotak: [
          kotak(10, 10, 80, 40),
          kotak(250, 10, 80, 40), // ini yang keluar
          kotak(110, 10, 80, 40),
        ],
      );

      expect(hasil.potongan, hasLength(2));
      expect(hasil.gagal, 1);
    });
  });

  test('tepat menyentuh tepi masih diterima', () {
    // Batasnya inklusif: kotak yang berhenti PAS di tepi citra itu sah, dan
    // menolaknya berarti membuang kolom terakhir tiap foto yang bingkainya rapi.
    final hasil = const PotongSelFoto().potong(
      citra: citraPetak(),
      kotak: [kotak(220, 60, 80, 40)], // 300 & 100, pas di tepi
    );

    expect(hasil.gagal, 0);
    expect(hasil.potongan, hasLength(1));
  });

  test('daftar kosong: nol potongan, nol gagal', () {
    final hasil = const PotongSelFoto().potong(
      citra: citraPetak(),
      kotak: const [],
    );

    expect(hasil.potongan, isEmpty);
    expect(hasil.gagal, 0);
  });
}

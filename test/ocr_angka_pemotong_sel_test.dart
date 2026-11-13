import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/ocr_angka/pagar_tinta.dart';
import 'package:sidik_calibration/services/ocr_angka/pemotong_sel.dart';

/// Pemotong sel v2 pada halaman SINTETIS yang meniru kegagalan foto nyata:
/// angka melewati garis atas/bawah, palang "7" menempel garis, dua nol menyatu,
/// titik hilang/besar, strip "—", coretan, sel kosong bertekstur kertas, sel
/// kosong bergaris, bayangan, garis tegak yang masuk jendela. TIDAK ada foto
/// atau potongan sel nyata di sini.
///
/// Geometri: tabel garis tebal 3 px; baris setinggi 44 px (garis di y = 60,
/// 104, 148, 192), kolom selebar 220 px (garis di x = 40, 260, 480). Kotak sel
/// persis di antara garis, seperti kotak dari templat.
void main() {
  const h = 44;
  const garisX = [40, 260, 480];

  KotakPiksel sel(
    int baris,
    int kolom, {
    double geserX = 0,
    double tinggi = 44,
  }) => (
    x: garisX[kolom] + 2.0 + geserX,
    y: 60.0 + h * baris + 1,
    w: 218,
    h: tinggi,
  );

  /// Goresan tebal: cap persegi di sepanjang ruas.
  void garis(
    img.Image i,
    double x0,
    double y0,
    double x1,
    double y1, {
    int tebal = 4,
    int abu = 40,
  }) {
    final n = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil() * 2 + 1;
    final a = tebal ~/ 2;
    for (var k = 0; k <= n; k++) {
      final cx = (x0 + (x1 - x0) * k / n).round();
      final cy = (y0 + (y1 - y0) * k / n).round();
      for (var dy = -a; dy < tebal - a; dy++) {
        for (var dx = -a; dx < tebal - a; dx++) {
          final px = cx + dx, py = cy + dy;
          if (px >= 0 && py >= 0 && px < i.width && py < i.height) {
            i.setPixelRgb(px, py, abu, abu, abu);
          }
        }
      }
    }
  }

  /// Halaman 700×300: kertas [abu], derau, bayangan mendatar, garis tabel.
  img.Image halaman({
    int abu = 232,
    int derau = 0,
    bool bayangan = false,
    bool tabel = true,
  }) {
    final rnd = math.Random(7);
    final i = img.Image(width: 700, height: 300, numChannels: 3);
    for (var y = 0; y < i.height; y++) {
      for (var x = 0; x < i.width; x++) {
        // Bayangan: kertas 235 di kiri → 110 di kanan (rasio 0,47 seperti foto
        // Piston: p5/p95 = 0,40).
        var v = bayangan ? (235 - (x / 700.0) * 125).round() : abu;
        if (derau > 0) v += rnd.nextInt(2 * derau + 1) - derau;
        i.setPixelRgb(x, y, v, v, v);
      }
    }
    if (tabel) {
      for (var r = 0; r < 4; r++) {
        garis(i, 30, 60.0 + h * r, 500, 60.0 + h * r, tebal: 3, abu: 50);
      }
      for (final x in garisX) {
        garis(
          i,
          x.toDouble(),
          60,
          x.toDouble(),
          60.0 + h * 3,
          tebal: 3,
          abu: 50,
        );
      }
    }

    return i;
  }

  void elips(
    img.Image i,
    double cx,
    double cy,
    double rx,
    double ry, {
    int tebal = 4,
  }) {
    const n = 48;
    for (var k = 0; k < n; k++) {
      final a0 = 2 * math.pi * k / n, a1 = 2 * math.pi * (k + 1) / n;
      garis(
        i,
        cx + rx * math.cos(a0),
        cy + ry * math.sin(a0),
        cx + rx * math.cos(a1),
        cy + ry * math.sin(a1),
        tebal: tebal,
      );
    }
  }

  void titik(img.Image i, double cx, double cy, int sisi) =>
      garis(i, cx, cy, cx, cy, tebal: sisi);

  /// Piksel crop (di koordinat HALAMAN) bertinta?
  bool tinta(HasilPotongSel r, int px, int py) {
    final c = r.crop;
    if (c == null) return false;
    final x = px - r.kiri, y = py - r.atas;
    if (x < 0 || y < 0 || x >= c.width || y >= c.height) return false;

    return c.getPixel(x, y).r <= 198;
  }

  HasilPotongSel potong(img.Image i, KotakPiksel k) =>
      PemotongSel.potongSemua(i, [k]).single;

  group('sel kosong tetap kosong', () {
    test('sel kosong dengan garis tabel (atas, bawah, kiri, kanan)', () {
      final r = potong(halaman(), sel(0, 0));

      expect(r.crop, isNull);
      expect(r.takYakin, isFalse);
    });

    test('sel kosong bertekstur kertas (derau) dan bintik kecil', () {
      final i = halaman(derau: 12);
      // Bintik 2×2 (debu/titik pena): di bawah batas luas komponen.
      titik(i, 120, 83, 2);
      titik(i, 200, 70, 2);

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNull, reason: 'bintik dan tekstur bukan tulisan');
      expect(r.takYakin, isFalse);
    });

    test(
      'debu 3×3 sendirian: di atas batas bintik tapi luas total terlalu kecil',
      () {
        final i = halaman();
        titik(i, 120, 83, 3); // 9 px: lolos batas komponen (±6), bukan tulisan

        final r = potong(i, sel(0, 0));

        expect(r.crop, isNull);
        expect(r.takYakin, isFalse);
      },
    );

    test('garis tabel yang agak miring tidak menjadi tulisan', () {
      final i = halaman(tabel: false);
      // Garis atas dan bawah miring 1 px per 110 px (±0,5°).
      garis(i, 30, 60, 500, 64, tebal: 3, abu: 50);
      garis(i, 30, 104, 500, 108, tebal: 3, abu: 50);
      garis(i, 40, 60, 40, 150, tebal: 3, abu: 50);
      garis(i, 260, 60, 260, 150, tebal: 3, abu: 50);

      // Kotak sel mengikuti tengah garis (rata-rata): geser 2 px dari kedua ujung.
      final r = potong(i, (x: 42, y: 63, w: 218, h: 44));

      expect(r.crop, isNull);
    });

    test(
      'sel kosong di bawah bayangan lebar tetap kosong; yang berisi terbaca',
      () {
        final i = halaman(bayangan: true);
        // Kolom kanan (kertas redup ±115) berisi angka "1".
        garis(i, 380, 70, 380, 98, tebal: 4, abu: 30);

        expect(
          potong(i, sel(0, 0)).crop,
          isNull,
          reason: 'kiri terang, kosong',
        );
        expect(
          potong(i, sel(1, 1)).crop,
          isNull,
          reason: 'kanan redup (gray < 198), tanpa normalisasi akan jadi tinta',
        );
        expect(potong(i, sel(0, 1)).crop, isNotNull);
      },
    );
  });

  group('angka yang melewati garis tidak terpotong', () {
    test('goresan tegak melintasi garis atas DAN bawah tetap utuh', () {
      final i = halaman();
      // Dari 4 px di atas garis atas sampai 4 px di bawah garis bawah.
      garis(i, 150, 56, 150, 109, tebal: 4, abu: 30);

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(r.takYakin, isFalse, reason: 'tingginya 1,3 baris: masih wajar');
      for (var y = 56; y <= 109; y++) {
        expect(
          tinta(r, 150, y),
          isTrue,
          reason: 'y=$y (garis di 59–61, 103–105)',
        );
      }
    });

    test('palang "7" menempel garis atas: palang dan diagonal tersambung', () {
      final i = halaman();
      // Palang tepat di atas garis (baris 54–57), diagonal turun melewati garis.
      garis(i, 140, 56, 170, 56, tebal: 4, abu: 30);
      garis(i, 170, 56, 150, 100, tebal: 4, abu: 30);

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(tinta(r, 155, 55), isTrue, reason: 'palang atas ada');
      // Diagonal di tengah band garis atas (59–61): x ≈ 168.
      expect(tinta(r, 168, 60), isTrue, reason: 'jembatan di garis');
      expect(tinta(r, 167, 62), isTrue);
      expect(r.takYakin, isFalse);
    });

    test('dua nol menyatu tetap SATU potongan (kedua nol ada)', () {
      final i = halaman();
      elips(i, 140, 83, 10, 15);
      elips(i, 158, 83, 10, 15); // bersentuhan dengan nol pertama

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(tinta(r, 130, 83), isTrue, reason: 'sisi kiri nol pertama');
      expect(tinta(r, 168, 83), isTrue, reason: 'sisi kanan nol kedua');
      expect(r.takYakin, isFalse);
    });

    test('titik besar ikut; titik hilang (bintik) tidak melebarkan crop', () {
      final i = halaman();
      garis(i, 120, 70, 120, 96, tebal: 4); // "1"
      titik(i, 134, 94, 7); // titik besar (7×7)
      titik(i, 200, 75, 2); // bintik jauh di kanan

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(tinta(r, 134, 94), isTrue, reason: 'titik besar dipertahankan');
      expect(
        r.kiri + r.crop!.width,
        lessThan(190),
        reason: 'bintik di x=200 tidak ikut: crop tidak menjangkaunya',
      );
    });
  });

  group('hanya komponen milik baris', () {
    test('angka baris di atasnya yang masuk jendela dibuang', () {
      final i = halaman();
      // Baris 0 punya "8" (y 64–92) yang bagian bawahnya jatuh di jendela
      // meluber baris 1 (jendela mulai di y = 105 − 26 = 79), tapi tidak
      // menyentuh garis: pusatnya di luar pita baris 1.
      elips(i, 150, 78, 10, 12);
      elips(i, 150, 127, 10, 14); // "0" milik baris 1

      final r = potong(i, sel(1, 0));

      expect(r.crop, isNotNull);
      expect(tinta(r, 150, 127 - 14), isTrue, reason: 'angka baris sendiri');
      expect(
        tinta(r, 150, 85),
        isFalse,
        reason: 'bagian "8" baris 0 di jendela',
      );
      expect(tinta(r, 150, 90), isFalse, reason: 'milik baris 0');
      expect(r.atas, greaterThanOrEqualTo(100));
      expect(r.takYakin, isFalse);
    });

    test('angka baris atas yang TERSAMBUNG ke angka baris ini: tidak yakin', () {
      final i = halaman();
      // Ekor "8" baris 0 turun menembus garis dan menyambung ke "0" baris 1:
      // satu komponen setinggi ±1,5 baris yang menyentuh tepi atas jendela.
      // Kegagalan nyata Piston (digit baris sebelah ikut crop); pemotong tidak
      // boleh diam. (Bila "8" itu hanya MENEMPEL garis, komponennya milik baris
      // 0 dan dibuang: tidak perlu tanda.)
      elips(i, 150, 78, 10, 12);
      elips(i, 150, 127, 10, 14);
      garis(i, 150, 88, 150, 113, tebal: 4);

      final r = potong(i, sel(1, 0));

      expect(r.takYakin, isTrue);
    });
  });

  group('tulisan bukan garis tabel dan bukan angka', () {
    test(
      'strip "—" di tengah sel TIDAK dihapus sebagai garis; ditandai garis datar',
      () {
        final i = halaman();
        garis(i, 100, 83, 240, 83, tebal: 4);

        final r = potong(i, sel(0, 0));

        expect(r.crop, isNotNull, reason: 'garis datar di tengah = tulisan');
        expect(r.sebabTakYakin, SebabPemotongTakYakin.garisDatar);
      },
    );

    test('coretan tebal di dalam sel: ada tinta, bukan kosong', () {
      final i = halaman();
      for (var k = 0; k < 14; k++) {
        garis(
          i,
          100.0 + k * 10,
          k.isEven ? 68 : 98,
          110.0 + k * 10,
          k.isEven ? 98 : 68,
          tebal: 5,
        );
      }

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(r.luasTinta, greaterThan(0.5 * h * h));
      expect(PagarTinta.adaTinta(PagarTinta.ukur(r.crop!)), isTrue);
    });

    test('coretan yang menembus baris atas-bawah: tidak yakin', () {
      final i = halaman();
      for (var k = 0; k < 10; k++) {
        garis(
          i,
          100.0 + k * 12,
          k.isEven ? 42 : 128,
          112.0 + k * 12,
          k.isEven ? 128 : 42,
          tebal: 5,
        );
      }

      final r = potong(i, sel(0, 0));

      expect(r.takYakin, isTrue);
    });

    test('gumpalan tinggi menyentuh jendela atas/bawah: tidak yakin', () {
      final i = halaman();
      // Balok 22 px lebar: bukan garis tegak (lebar > 0,3 baris).
      garis(i, 150, 30, 150, 135, tebal: 22);

      final r = potong(i, sel(0, 0));

      expect(
        r.sebabTakYakin,
        SebabPemotongTakYakin.tintaMelewatiJendelaVertikal,
      );
    });

    test('angka terpotong di tepi samping jendela: tidak yakin', () {
      final i = halaman();
      // Kotak mulai x=42, margin 5 → jendela mulai x=47; "0" berpusat di x=48.
      elips(i, 48, 83, 10, 15, tebal: 5);

      final r = potong(i, sel(0, 0));

      expect(r.sebabTakYakin, SebabPemotongTakYakin.tintaMenempelTepiSamping);
    });

    test('kotak terlalu kecil: tidak yakin, tanpa crop', () {
      final r = potong(halaman(), sel(0, 0, tinggi: 8));

      expect(r.sebabTakYakin, SebabPemotongTakYakin.kotakTerlaluKecil);
      expect(r.crop, isNull);
    });
  });

  group('garis tegak tabel yang masuk jendela', () {
    test(
      'kotak bergeser 6 px: garis kiri masuk jendela, sel kosong tetap kosong',
      () {
        final r = potong(halaman(), sel(0, 0, geserX: -6));

        expect(r.crop, isNull);
        expect(r.takYakin, isFalse);
      },
    );

    test('sel berisi: garis tegak tidak ikut crop', () {
      final i = halaman();
      garis(i, 150, 70, 150, 96, tebal: 4);

      final r = potong(i, sel(0, 0, geserX: -6));

      expect(r.crop, isNotNull);
      expect(r.kiri, greaterThan(100), reason: 'garis kiri di x=40 tidak ikut');
      expect(r.takYakin, isFalse);
    });

    test('garis tegak TEBAL (6 px) yang masuk jendela juga dibuang', () {
      final i = halaman(tabel: false);
      // Garis kiri tebal di x=47–52 (jendela mulai x=47): lebarnya di atas batas
      // "serpihan tipis", jadi hanya aturan garis tegak tinggi yang menangkapnya.
      garis(i, 50, 20, 50, 200, tebal: 6, abu: 50);
      garis(i, 150, 70, 150, 96, tebal: 4);

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNotNull);
      expect(r.kiri, greaterThan(100), reason: 'garis tebal tidak ikut crop');
      expect(r.takYakin, isFalse);
    });

    test('serpihan garis tegak setinggi satu baris di tepi dibuang', () {
      final i = halaman(tabel: false);
      // 3 px × 44 px di tepi kiri jendela: lebih rendah dari batas garis tegak
      // tinggi (1,2 baris), jadi aturan "serpihan tipis" yang menangkapnya.
      garis(i, 48, 70, 48, 114, tebal: 3, abu: 50);

      final r = potong(i, sel(0, 0));

      expect(r.crop, isNull, reason: 'serpihan bukan tulisan');
    });

    test(
      'bintik kecil menempel tepi jendela tidak melebarkan crop atau menandai',
      () {
        final i = halaman(tabel: false);
        garis(i, 150, 70, 150, 96, tebal: 4);
        garis(i, 48, 80, 48, 90, tebal: 2, abu: 50); // 2 × 10 px di tepi kiri

        final r = potong(i, sel(0, 0));

        expect(r.crop, isNotNull);
        expect(
          r.takYakin,
          isFalse,
          reason: 'bintik di tepi bukan angka terpotong',
        );
        expect(r.kiri, greaterThan(100));
      },
    );

    test('goresan tegak tinggi di TENGAH sel bukan garis tabel', () {
      final i = halaman();
      garis(i, 150, 56, 150, 108, tebal: 3); // 1,2 baris, tipis, tapi di tengah

      expect(potong(i, sel(0, 0)).crop, isNotNull);
    });
  });

  group('penyangga kerja dan normalisasi', () {
    test(
      'hasil satu sel tidak bergantung pada sel yang diproses sebelumnya',
      () {
        final i = halaman();
        for (var k = 0; k < 14; k++) {
          garis(
            i,
            100.0 + k * 10,
            k.isEven ? 68 : 98,
            110.0 + k * 10,
            k.isEven ? 98 : 68,
            tebal: 5,
          );
        }
        garis(i, 300, 70, 300, 96, tebal: 4); // sel (0,1): "1" kecil

        final sendiri = PemotongSel.potongSemua(i, [sel(0, 1)]).single;
        final sesudahBesar = PemotongSel.potongSemua(i, [
          sel(0, 0),
          sel(0, 1),
        ])[1];

        expect(sesudahBesar.crop, isNotNull);
        expect(sesudahBesar.crop!.width, sendiri.crop!.width);
        expect(sesudahBesar.crop!.height, sendiri.crop!.height);
        expect(
          Uint8List.sublistView(sesudahBesar.crop!.getBytes()),
          orderedEquals(sendiri.crop!.getBytes()),
        );
        expect(sesudahBesar.kiri, sendiri.kiri);
        expect(sesudahBesar.atas, sendiri.atas);
      },
    );

    test(
      'kotak sembarang (di luar halaman, kecil, raksasa) tidak melempar',
      () {
        final i = halaman();
        garis(i, 150, 70, 150, 96, tebal: 4);
        final rnd = math.Random(11);
        final kotak = <KotakPiksel>[
          for (var k = 0; k < 150; k++)
            (
              x: rnd.nextDouble() * 900 - 100,
              y: rnd.nextDouble() * 500 - 100,
              w: rnd.nextDouble() * 400,
              h: rnd.nextDouble() * 120,
            ),
          (x: -50, y: -50, w: 2000, h: 2000), // jauh melewati halaman
          (x: 0, y: 0, w: 0, h: 0),
          (x: 699, y: 299, w: 10, h: 10), // pojok kanan-bawah
        ];

        final hasil = PemotongSel.potongSemua(i, kotak);

        expect(hasil, hasLength(kotak.length));
        for (final r in hasil) {
          final c = r.crop;
          if (c != null) {
            expect(c.width, greaterThan(0));
            expect(c.height, greaterThan(0));
          }
        }
      },
    );

    test('tanpa kotak: daftar kosong', () {
      expect(PemotongSel.potongSemua(halaman(), const []), isEmpty);
    });

    test(
      'normalisasi meratakan bayangan: kertas ≈ 255 di terang maupun redup',
      () {
        final p = HalamanTernormal.dari(
          halaman(bayangan: true, tabel: false),
          kernelLatarPx: 80,
        );
        final kiri = Uint8List(40 * 20);
        final kanan = Uint8List(40 * 20);
        p.isiNorm(100, 100, 140, 120, kiri);
        p.isiNorm(560, 100, 600, 120, kanan);

        // Pembagian latar tidak persis 255 (dilatasi condong ke sisi terang),
        // tapi kertas redup (gray ±115 di kanan) kembali jauh di atas ambang
        // tinta 198.
        expect(kiri.every((v) => v >= 230), isTrue);
        expect(
          kanan.every((v) => v >= 230),
          isTrue,
          reason: 'redup pun dibagi latar',
        );
      },
    );
  });
}

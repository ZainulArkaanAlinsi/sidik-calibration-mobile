import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pindai_lembar.dart';

/// Mesin pindai lembar kerja — bagian yang jalan DI HP.
///
/// Yang diuji di sini bukan "OCR-nya pinter", tapi hal yang jauh lebih
/// menentukan: **potongan sel mendarat di kotak yang benar**. Angka yang
/// kebaca sempurna lalu ditaruh di baris sebelah jauh lebih berbahaya daripada
/// angka yang nggak kebaca — yang kedua kelihatan, yang pertama nyampe
/// sertifikat.
///
/// Fotonya dibikin sintetis supaya bisa diuji tanpa kamera dan tanpa kertas:
/// lembar rata → dimiringkan seperti difoto dari sudut → diselaraskan lagi →
/// diadu ke koordinat aslinya.
void main() {
  const mesin = PindaiLembar();

  // Ukuran referensi template asli: 1654x2339 @200dpi (A4). Diperkecil 4x biar
  // test-nya cepat — yang diuji perbandingannya, bukan angkanya.
  const lebar = 414;
  const tinggi = 585;
  const ukuranMarker = 22;

  /// Posisi marker di ruang template, urut kiri-atas → kanan-atas →
  /// kanan-bawah → kiri-bawah (id 0..3), sama dengan berkas geometri.
  final tujuan = <Sudut>[
    (x: 22.0, y: 22.0),
    (x: lebar - 22.0, y: 22.0),
    (x: lebar - 22.0, y: tinggi - 22.0),
    (x: 22.0, y: tinggi - 22.0),
  ];

  /// Lembar kerja tiruan: kertas putih, 4 marker hitam di sudut, dan satu
  /// "coretan" hitam di sel yang kita tentukan.
  img.Image lembar({required List<({double x, double y, double w, double h})> sel, int? isiSel}) {
    final citra = img.Image(width: lebar, height: tinggi);
    img.fill(citra, color: img.ColorRgb8(255, 255, 255));

    for (final m in tujuan) {
      img.fillRect(
        citra,
        x1: (m.x - ukuranMarker / 2).round(),
        y1: (m.y - ukuranMarker / 2).round(),
        x2: (m.x + ukuranMarker / 2).round(),
        y2: (m.y + ukuranMarker / 2).round(),
        color: img.ColorRgb8(0, 0, 0),
      );
    }

    // Kotak selnya digambar tipis (abu), coretannya pejal (hitam) — biar
    // bedanya kelihatan waktu crop-nya diperiksa.
    for (var i = 0; i < sel.length; i++) {
      final s = sel[i];
      img.drawRect(
        citra,
        x1: s.x.round(),
        y1: s.y.round(),
        x2: (s.x + s.w).round(),
        y2: (s.y + s.h).round(),
        color: img.ColorRgb8(150, 150, 150),
      );

      if (isiSel == i) {
        img.fillRect(
          citra,
          x1: (s.x + s.w * 0.3).round(),
          y1: (s.y + s.h * 0.3).round(),
          x2: (s.x + s.w * 0.7).round(),
          y2: (s.y + s.h * 0.7).round(),
          color: img.ColorRgb8(0, 0, 0),
        );
      }
    }

    return citra;
  }

  /// Bikin "foto" dari lembar rata: dimiringkan, digeser, dan dikasih pinggiran
  /// — seperti hasil jepretan HP yang nggak pernah tegak lurus sempurna.
  img.Image fotoMiring(img.Image rata, {double miring = 0.06}) {
    final w = (rata.width * 1.4).round();
    final h = (rata.height * 1.4).round();
    final hasil = img.Image(width: w, height: h);
    img.fill(hasil, color: img.ColorRgb8(210, 210, 210));

    final geserX = (w - rata.width) / 2;
    final geserY = (h - rata.height) / 2;

    for (var y = 0; y < rata.height; y++) {
      for (var x = 0; x < rata.width; x++) {
        // Perspektif sederhana: makin ke bawah, makin melebar ke kanan.
        final skala = 1 + miring * (y / rata.height);
        final tx = (geserX + (x - rata.width / 2) * skala + rata.width / 2).round();
        final ty = (geserY + y * (1 + miring * 0.4 * (x / rata.width))).round();

        if (tx < 0 || ty < 0 || tx >= w || ty >= h) continue;
        hasil.setPixel(tx, ty, rata.getPixel(x, y));
      }
    }

    return hasil;
  }

  group('cari marker', () {
    test('empat sudut ketemu di foto yang miring', () {
      final foto = fotoMiring(lembar(sel: const []));
      final marker = mesin.cariMarker(foto);

      expect(marker, isNotNull);
      expect(marker, hasLength(4));

      // Urutannya DIPATOK posisi, bukan urutan penemuan: kiri-atas paling kiri
      // & paling atas, kanan-bawah sebaliknya. Kalau urutannya kebalik, seluruh
      // lembar kegambar terbalik dan tiap angka mendarat di sel yang salah.
      expect(marker![0].x, lessThan(marker[1].x));
      expect(marker[0].y, lessThan(marker[3].y));
      expect(marker[2].x, greaterThan(marker[3].x));
      expect(marker[2].y, greaterThan(marker[1].y));
    });

    test('kertas tanpa marker balik null, bukan sudut karangan', () {
      final polos = img.Image(width: lebar, height: tinggi);
      img.fill(polos, color: img.ColorRgb8(255, 255, 255));

      // Tanpa empat sudut nggak ada cara meratakan fotonya. Meratakan pakai
      // tiga sudut berarti menebak yang keempat — persis tebakan yang bikin
      // angka mendarat di sel sebelah.
      expect(mesin.cariMarker(polos), isNull);
    });
  });

  group('warp & potong sel', () {
    test('sel yang dicoret di foto miring tetap kepotong di kunci yang benar', () {
      // Tiga sel berjejer. Yang dicoret INDEX 1 — kalau grid meleset satu
      // kolom, yang kepotong bakal sel 0 atau 2, dan itu yang mau ketahuan.
      final sel = <({double x, double y, double w, double h})>[
        (x: 100, y: 250, w: 60, h: 40),
        (x: 170, y: 250, w: 60, h: 40),
        (x: 240, y: 250, w: 60, h: 40),
      ];

      final foto = fotoMiring(lembar(sel: sel, isiSel: 1));
      final marker = mesin.cariMarker(foto)!;

      final hasil = mesin.warp(
        foto,
        marker,
        lebar: lebar,
        tinggi: tinggi,
        tujuan: tujuan,
      );

      // Residual kecil = keempat titik itu memang sudut lembar, bukan bayangan
      // nyasar. Server nolak di atas 2 px.
      expect(hasil.residualPx, lessThan(2.0));

      double gelap(int i) {
        final crop = mesin.potongSel(
          hasil.citra,
          x: sel[i].x,
          y: sel[i].y,
          w: sel[i].w,
          h: sel[i].h,
        );

        var n = 0;
        for (var y = 0; y < crop.height; y++) {
          for (var x = 0; x < crop.width; x++) {
            final p = crop.getPixel(x, y);
            if (p.r * 0.299 + p.g * 0.587 + p.b * 0.114 < 100) n++;
          }
        }

        return n / (crop.width * crop.height);
      }

      // Sel yang dicoret jelas lebih gelap dari tetangganya — artinya
      // potongannya mendarat di kotak yang benar.
      expect(gelap(1), greaterThan(0.10));
      expect(gelap(0), lessThan(0.02));
      expect(gelap(2), lessThan(0.02));
    });

    test('margin motong garis kotaknya, bukan isinya', () {
      // Garis kotak yang ikut kepotong gampang kebaca ML Kit sebagai `1` atau
      // `-`. Crop harus lebih kecil dari selnya.
      final citra = img.Image(width: 100, height: 100);
      img.fill(citra, color: img.ColorRgb8(255, 255, 255));

      final crop = mesin.potongSel(citra, x: 10, y: 10, w: 50, h: 40);

      expect(crop.width, lessThan(50));
      expect(crop.height, lessThan(40));
    });
  });

  group('mutu foto', () {
    test('foto buram skor blur-nya jauh lebih rendah dari yang tajam', () {
      final tajam = lembar(sel: const [
        (x: 100, y: 250, w: 60, h: 40),
      ], isiSel: 0);

      final buram = img.gaussianBlur(tajam.clone(), radius: 3);

      final mutuTajam = mesin.mutu(tajam);
      final mutuBuram = mesin.mutu(buram);

      expect(mutuBuram.blur, lessThan(mutuTajam.blur));

      // Kertas putih: kecerahannya tinggi, glare-nya rendah. Angkanya dikirim
      // apa adanya — yang MUTUSIN lolos atau nggak tetap server.
      expect(mutuTajam.kecerahan, greaterThan(200));
      expect(mutuTajam.glare, lessThan(1.0));
    });
  });

  group('homografi', () {
    test('titik sudut mendarat persis di tujuannya', () {
      final sumber = <Sudut>[
        (x: 10, y: 12),
        (x: 300, y: 20),
        (x: 310, y: 400),
        (x: 5, y: 380),
      ];

      final citra = img.Image(width: 320, height: 420);
      img.fill(citra, color: img.ColorRgb8(255, 255, 255));

      final hasil = mesin.warp(
        citra,
        sumber,
        lebar: lebar,
        tinggi: tinggi,
        tujuan: tujuan,
      );

      // Residual ~0: transformasinya memang memetakan keempat sudut ke
      // tujuannya. Kalau ini meleset, seluruh potongan sel ikut meleset.
      expect(hasil.residualPx, lessThan(0.01));
    });
  });


  group('payload kiriman', () {
    const payload = PayloadPindai();

    /// SEMUA sel template dikirim, termasuk yang kosong & yang nggak kebaca.
    ///
    /// Sel yang nggak ikut bikin server nolak SELURUH lembar — dan itu memang
    /// aturannya: sel yang hilang tanpa suara lebih bahaya daripada scan yang
    /// ditolak terang-terangan.
    test('semua sel ikut, yang kosong pun', () {
      final kotak = {
        'holmium|1|1|pembacaan': (x: 10.0, y: 20.0, w: 60.0, h: 40.0),
        'holmium|1|2|pembacaan': (x: 80.0, y: 20.0, w: 60.0, h: 40.0),
        'holmium|1|3|pembacaan': (x: 150.0, y: 20.0, w: 60.0, h: 40.0),
      };

      final body = payload.susun(
        templateId: 'spectrophotometer',
        templateVersi: 1,
        // Cuma satu sel yang kebaca — dua sisanya kosong di kertasnya.
        sel: {
          'holmium|1|1|pembacaan': (
            teks: '280',
            keyakinan: null,
            didalamKotak: true,
          ),
        },
        kotak: kotak,
        bukti: {
          for (final k in kotak.keys)
            k: (titikUkur: 279.6, standardId: 25),
        },
        marker: const [
          (x: 10.0, y: 10.0),
          (x: 400.0, y: 12.0),
          (x: 402.0, y: 570.0),
          (x: 8.0, y: 568.0),
        ],
        residualPx: 0.8,
        ukuranReferensi: (w: 414, h: 585),
        mutu: (blur: 168.2, kecerahan: 142.0, glare: 0.01),
        sudutMiringDeg: 1.4,
        pxPerSelTinggi: 61,
        qrIsi: 'spectrophotometer|v1',
      );

      final sel = (body['sel'] as List).cast<Map<String, dynamic>>();

      expect(sel, hasLength(3));
      expect(
        sel.map((s) => s['teks_mentah']).toList(),
        ['280', null, null],
      );
    });

    /// Kunci dipecah APA ADANYA, nggak disusun ulang dari indeks tampilan.
    test('kunci dipecah jadi tabel/baris/repeat/field tanpa ditebak', () {
      final body = payload.susun(
        templateId: 'ph_meter',
        templateVersi: 1,
        sel: const {},
        kotak: {
          'sesudah_adjustment|3|5|suhu': (x: 1.0, y: 2.0, w: 3.0, h: 4.0),
        },
        bukti: const {},
        marker: const [],
        residualPx: 0.5,
        ukuranReferensi: (w: 414, h: 585),
        mutu: (blur: 100, kecerahan: 140, glare: 0),
        sudutMiringDeg: 0,
        pxPerSelTinggi: 50,
      );

      final sel = (body['sel'] as List).first as Map<String, dynamic>;

      expect(sel['tabel_id'], 'sesudah_adjustment');
      expect(sel['baris_ke'], 3);
      expect(sel['repeat_no'], 5);
      expect(sel['field_id'], 'suhu');
    });

    /// Teks dikirim APA ADANYA — nggak dibersihin, dan yang paling penting:
    /// nggak ditambahin koma supaya "kelihatan wajar".
    test('teks ngawur nggak dibetulin di HP', () {
      final body = payload.susun(
        templateId: 'refractometer',
        templateVersi: 1,
        sel: {
          'a|1|1|pembacaan': (
            teks: '133659',
            keyakinan: null,
            didalamKotak: true,
          ),
        },
        kotak: {'a|1|1|pembacaan': (x: 0.0, y: 0.0, w: 10.0, h: 10.0)},
        bukti: const {},
        marker: const [],
        residualPx: 0.5,
        ukuranReferensi: (w: 414, h: 585),
        mutu: (blur: 100, kecerahan: 140, glare: 0),
        sudutMiringDeg: 0,
        pxPerSelTinggi: 50,
      );

      final sel = (body['sel'] as List).first as Map<String, dynamic>;

      // `1,33659` itu tebakan. Yang mutusin dia angka atau bukan cuma server.
      expect(sel['teks_mentah'], '133659');
    });

    /// Skor mutu dikirim apa adanya, nggak dibulatkan: ambangnya milik server,
    /// dan membulatkan di sini bikin foto pas-pasan lolos/ketolak beda dari
    /// yang seharusnya.
    test('skor mutu nggak dibulatkan', () {
      final body = payload.susun(
        templateId: 'ph_meter',
        templateVersi: 1,
        sel: const {},
        kotak: const {},
        bukti: const {},
        marker: const [],
        residualPx: 0.83741,
        ukuranReferensi: (w: 414, h: 585),
        mutu: (blur: 89.7431, kecerahan: 142.55, glare: 0.0123),
        sudutMiringDeg: 1.4567,
        pxPerSelTinggi: 61.2,
      );

      final kualitas = body['kualitas'] as Map<String, dynamic>;

      expect(kualitas['blur_laplacian'], 89.7431);
      expect(kualitas['rasio_glare'], 0.0123);
      expect((body['geometri'] as Map)['residual_reproyeksi_px'], 0.83741);
    });
  });

  test('foto sangat miring residualnya tetap kecil sesudah diratakan', () {
    // Perspektif lebih ekstrem dari jepretan wajar. Yang diuji: mesinnya nggak
    // diam-diam "berhasil" dengan grid yang meleset.
    final foto = fotoMiring(lembar(sel: const []), miring: 0.18);
    final marker = mesin.cariMarker(foto);

    expect(marker, isNotNull);

    final hasil = mesin.warp(
      foto,
      marker!,
      lebar: lebar,
      tinggi: tinggi,
      tujuan: tujuan,
    );

    expect(hasil.residualPx, lessThan(2.0));
    expect(hasil.citra.width, lebar);
    expect(hasil.citra.height, tinggi);
  });

  test('sudut kemiringan foto kehitung dari posisi markernya', () {
    final foto = fotoMiring(lembar(sel: const []));
    final marker = mesin.cariMarker(foto)!;

    // Sudut dihitung dari sisi atas (marker 0 → 1). Dikirim ke server sebagai
    // `sudut_kemiringan_deg`; ambangnya (±8°) milik server, bukan HP.
    final sudut = math.atan2(
          marker[1].y - marker[0].y,
          marker[1].x - marker[0].x,
        ) *
        180 /
        math.pi;

    expect(sudut.abs(), lessThan(8));
  });
}

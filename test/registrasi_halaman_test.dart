// Page registration (Fase 2): geometri, gagal-aman, API dan warp. Akurasi pada
// kumpulan foto sintetis ada di `registrasi_halaman_akurasi_test.dart`.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/registrasi_halaman/geometri_halaman.dart';
import 'package:sidik_calibration/services/registrasi_halaman/registrasi_halaman.dart';

import 'support/foto_sintetis_halaman.dart';
import 'support/ukur_registrasi_halaman.dart';

const _letter = (w: 612.0, h: 792.0);
const _legal = (w: 612.0, h: 1008.0);

List<TitikHalaman> _persegiPutar(
  double cx,
  double cy,
  double a,
  double b,
  double derajat,
) {
  final t = derajat * math.pi / 180;
  final c = math.cos(t);
  final s = math.sin(t);
  TitikHalaman r(double x, double y) =>
      (x: cx + x * c - y * s, y: cy + x * s + y * c);

  return [r(-a, -b), r(a, -b), r(a, b), r(-a, b)];
}

/// Foto 480×640 dengan halaman Letter di segi empat [kuad] (kiri-atas,
/// kanan-atas, kanan-bawah, kiri-bawah), pencahayaan ringan.
FotoSintetis _fotoDariKuad(
  List<TitikHalaman> kuad, {
  int seed = 1,
  JenisAlas alas = JenisAlas.gelap,
  double lengkung = 0,
  bool tangan = false,
}) {
  final hm = homografiDari4([
    (x: 0.0, y: 0.0),
    (x: _letter.w, y: 0.0),
    (x: _letter.w, y: _letter.h),
    (x: 0.0, y: _letter.h),
  ], kuad)!;

  return hasilkanFotoSintetis(
    SpesifikasiFoto(
      seed: seed,
      lebarFoto: 480,
      tinggiFoto: 640,
      alas: alas,
      homografi: hm,
      lengkung: lengkung,
      tanganTepi: tangan,
      blurPx: 0.5,
      noise: 4,
      jpegQ: 80,
    ),
  );
}

HasilRegistrasiHalaman _daftar(FotoSintetis f, {int? putaran}) =>
    registrasiHalaman(
      f.foto,
      halamanPt: f.halamanPt,
      skala: 0.5,
      putaranKuadran: putaran,
    );

void main() {
  group('geometri', () {
    test('lambung cembung membuang titik dalam dan titik segaris', () {
      final titik = <TitikHalaman>[
        (x: 0, y: 0),
        (x: 10, y: 0),
        (x: 10, y: 10),
        (x: 0, y: 10),
        (x: 5, y: 5),
        (x: 5, y: 0), // di sisi
        (x: 2, y: 8),
        (x: 0, y: 0), // kembar
      ];

      expect(lambungCembung(titik), hasLength(4));
    });

    test('sudutSumbuHalaman = putaran terkecil persegi panjang', () {
      for (final deg in [0.0, 10.0, 35.0, -35.0, 44.0, -44.0]) {
        final lambung = lambungCembung(_persegiPutar(300, 200, 80, 120, deg));
        expect(
          sudutSumbuHalaman(lambung) * 180 / math.pi,
          closeTo(deg, 1e-6),
          reason: 'putaran $deg°',
        );
      }
      // 60° ≡ -30° (modulo 90°).
      final lambung = lambungCembung(_persegiPutar(300, 200, 80, 120, 60));
      expect(sudutSumbuHalaman(lambung) * 180 / math.pi, closeTo(-30, 1e-6));
    });

    test('sudutKasar urut kiri-atas, kanan-atas, kanan-bawah, kiri-bawah '
        'sampai putaran 44°', () {
      for (final deg in [0.0, 10.0, 35.0, -35.0, 44.0]) {
        final benar = _persegiPutar(300, 200, 80, 120, deg);
        final lambung = lambungCembung(benar);
        final kasar = sudutKasar(lambung, sudutSumbuHalaman(lambung))!;

        for (var i = 0; i < 4; i++) {
          expect(kasar[i].x, closeTo(benar[i].x, 1e-6), reason: '$deg° #$i x');
          expect(kasar[i].y, closeTo(benar[i].y, 1e-6), reason: '$deg° #$i y');
        }
      }
    });

    test('cocokkanGaris tahan pencilan', () {
      const n = 110;
      final xs = Float64List(n);
      final ys = Float64List(n);
      for (var i = 0; i < n; i++) {
        final x = i.toDouble();
        xs[i] = x;
        // garis y = 0,5x + 3, derau deterministik ±0,2, 5 titik pencilan +15
        // (< 5%: RMS terpangkas membuangnya).
        ys[i] = 0.5 * x + 3 + 0.2 * math.sin(i * 12.9898) + (i >= 105 ? 15 : 0);
      }

      final g = cocokkanGaris(xs, ys, n)!;
      final sudut = math.atan2(g.dy, g.dx);
      final lurus = sudut > math.pi / 2 ? sudut - math.pi : sudut;

      expect(lurus, closeTo(math.atan(0.5), 0.01));
      expect(g.jarakBertanda(50, 28).abs(), lessThan(0.3));
      expect(g.rms, lessThan(0.4));
    });

    test('perpotongan dua garis; sejajar = null', () {
      GarisTerfit garis(double px, double py, double derajat) {
        final t = derajat * math.pi / 180;

        return GarisTerfit(
          px: px,
          py: py,
          dx: math.cos(t),
          dy: math.sin(t),
          rms: 0,
          jumlah: 2,
        );
      }

      final p = perpotongan(garis(0, 5, 0), garis(7, 0, 90))!;
      expect(p.x, closeTo(7, 1e-9));
      expect(p.y, closeTo(5, 1e-9));
      expect(perpotongan(garis(0, 5, 0), garis(0, 9, 0)), isNull);
    });

    test('segi empat cembung dan sudut dalam', () {
      final persegi = <TitikHalaman>[
        (x: 0, y: 0),
        (x: 10, y: 0),
        (x: 10, y: 10),
        (x: 0, y: 10),
      ];
      expect(segiEmpatCembung(persegi), isTrue);
      expect(sudutDalamDeg(persegi, 2), closeTo(90, 1e-9));
      expect(luasPoligon(persegi), closeTo(100, 1e-9));

      final dasi = <TitikHalaman>[
        (x: 0, y: 0),
        (x: 10, y: 10),
        (x: 10, y: 0),
        (x: 0, y: 10),
      ];
      expect(segiEmpatCembung(dasi), isFalse);

      final cekung = <TitikHalaman>[
        (x: 0, y: 0),
        (x: 10, y: 0),
        (x: 4, y: 4),
        (x: 0, y: 10),
      ];
      expect(segiEmpatCembung(cekung), isFalse);
    });

    test('rasio halaman dari sudut proyeksi (Zhang-He) benar walau miring', () {
      // Kamera lubang-jarum dengan titik pokok di tengah foto: asumsi rumus.
      // Toleransi: 1% bila fokus bisa ditaksir dari sudut (dua titik hilang);
      // 4% bila sepasang sisi sejajar di foto (kamera dimiringkan ke satu arah
      // saja) — fokus tidak ada di bentuknya dan dipakai nilai prior 0,85.
      for (final (pitch, yaw, roll, toleransi) in [
        (0.0, 0.0, 0.0, 0.01),
        (25.0, 0.0, 0.0, 0.04),
        (0.0, 20.0, 10.0, 0.04),
        (25.0, 15.0, 30.0, 0.01),
        (35.0, -20.0, -15.0, 0.01),
        (15.0, 10.0, 80.0, 0.01),
      ]) {
        final spek = SpesifikasiFoto(
          seed: 0,
          lebarFoto: 1200,
          tinggiFoto: 1600,
          pitchDeg: pitch,
          yawDeg: yaw,
          rollDeg: roll,
          isi: 0.85,
          fRel: 0.9,
        );
        final h = homografiKamera(spek);
        final q = [
          proyeksi(h, 0, 0),
          proyeksi(h, _letter.w, 0),
          proyeksi(h, _letter.w, _letter.h),
          proyeksi(h, 0, _letter.h),
        ];
        final benar = _letter.w / _letter.h;
        final zh = perkirakanRasioHalaman(q, 600, 800);

        expect(
          zh / benar,
          closeTo(1, toleransi),
          reason: 'pitch $pitch yaw $yaw roll $roll: $zh vs $benar',
        );
      }
    });

    test(
      'rasio panjang sisi meleset pada foto sangat miring; Zhang-He tidak',
      () {
        final spek = const SpesifikasiFoto(
          seed: 0,
          lebarFoto: 1200,
          tinggiFoto: 1600,
          pitchDeg: 40,
          yawDeg: 20,
          isi: 0.85,
          fRel: 0.9,
        );
        final h = homografiKamera(spek);
        final q = [
          proyeksi(h, 0, 0),
          proyeksi(h, _letter.w, 0),
          proyeksi(h, _letter.w, _letter.h),
          proyeksi(h, 0, _letter.h),
        ];
        final benar = _letter.w / _letter.h;

        expect((rasioPanjangSisi(q) / benar - 1).abs(), greaterThan(0.08));
        expect(
          (perkirakanRasioHalaman(q, 600, 800) / benar - 1).abs(),
          lessThan(0.01),
        );
      },
    );

    test('jajar genjang tanpa perspektif jatuh ke rasio panjang sisi', () {
      final q = <TitikHalaman>[
        (x: 100, y: 100),
        (x: 400, y: 120),
        (x: 410, y: 520),
        (x: 110, y: 500),
      ];

      expect(
        perkirakanRasioHalaman(q, 250, 300),
        closeTo(rasioPanjangSisi(q), 1e-9),
      );
    });
  });

  group('deteksi: foto bersih', () {
    test('halaman miring di meja gelap: sudut dalam 0,15% diagonal', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 11,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 12,
          pitchDeg: 8,
          yawDeg: -6,
          isi: 0.85,
          blurPx: 0.5,
          noise: 3,
        ),
      );

      final hasil = deteksiSudutHalaman(f.foto);

      expect(hasil, isA<DeteksiHalamanBerhasil>());
      final b = hasil as DeteksiHalamanBerhasil;
      final uk = ukurSudut('bersih', f, b.sudut);
      expect(uk.galatSudutPctFoto, lessThan(0.15));
      expect(b.diagnostik.halusTepi, isTrue);
      expect(b.diagnostik.strategi, 'luma');
    });

    test('koordinat dalam piksel FOTO ASLI, bukan citra kerja 640 px', () {
      for (final lebar in [320, 960]) {
        final f = hasilkanFotoSintetis(
          SpesifikasiFoto(
            seed: 5,
            lebarFoto: lebar,
            tinggiFoto: (lebar * 4 / 3).round(),
            rollDeg: -9,
            pitchDeg: 10,
            isi: 0.85,
            blurPx: lebar / 1000,
            noise: 3,
          ),
        );

        final hasil = deteksiSudutHalaman(f.foto);

        expect(hasil, isA<DeteksiHalamanBerhasil>(), reason: 'lebar $lebar');
        final uk = ukurSudut(
          'l$lebar',
          f,
          (hasil as DeteksiHalamanBerhasil).sudut,
        );
        expect(
          uk.galatSudutPctFoto,
          lessThan(0.2),
          reason: 'lebar $lebar → ${uk.galatSudutPctFoto}',
        );
      }
    });
  });

  group('gagal-aman: tidak meluruskan, tidak menebak', () {
    test('foto rata satu warna → kontras kurang', () {
      final polos = img.Image(width: 400, height: 300);
      img.fill(polos, color: img.ColorRgb8(120, 120, 120));

      final hasil = deteksiSudutHalaman(polos);

      expect(hasil, isA<DeteksiHalamanGagal>());
      expect(
        (hasil as DeteksiHalamanGagal).alasan,
        AlasanGagalRegistrasi.kontrasKurang,
      );
    });

    test('gambar terlalu kecil → foto tidak terbaca', () {
      final hasil = deteksiSudutHalaman(img.Image(width: 30, height: 30));

      expect(
        (hasil as DeteksiHalamanGagal).alasan,
        AlasanGagalRegistrasi.fotoTidakTerbaca,
      );
    });

    test('halaman kecil di foto → terlalu kecil', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 3,
          lebarFoto: 480,
          tinggiFoto: 640,
          isi: 0.45,
        ),
      );

      final hasil = _daftar(f);

      expect(
        (hasil as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.halamanTerlaluKecil,
      );
    });

    test('satu sisi keluar utuh dari foto → tepi terpotong', () {
      final f = _fotoDariKuad(const [
        (x: -130.0, y: 90.0),
        (x: 400.0, y: 80.0),
        (x: 410.0, y: 580.0),
        (x: -140.0, y: 590.0),
      ]);

      final hasil = _daftar(f);

      expect(hasil, isA<RegistrasiHalamanGagal>());
      expect(
        (hasil as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.tepiTerpotong,
      );
    });

    test('ujung sudut terpotong kecil (≈1% diagonal) masih diterima', () {
      final f = _fotoDariKuad(const [
        (x: -6.0, y: 80.0),
        (x: 420.0, y: 70.0),
        (x: 430.0, y: 560.0),
        (x: 50.0, y: 570.0),
      ]);

      final hasil = _daftar(f);

      expect(hasil, isA<RegistrasiHalamanBerhasil>(), reason: '$hasil');
      final uk = ukurSudut(
        'potong-kecil',
        f,
        (hasil as RegistrasiHalamanBerhasil).sudutFoto,
      );
      expect(uk.galatSudutPctFoto, lessThan(0.3));
    });

    test('bentuk sangat condong (sudut dalam < 60°) → bentuk tidak wajar', () {
      final f = _fotoDariKuad(const [
        (x: 300.0, y: 80.0),
        (x: 470.0, y: 80.0),
        (x: 180.0, y: 560.0),
        (x: 10.0, y: 560.0),
      ]);

      final hasil = _daftar(f);

      expect(hasil, isA<RegistrasiHalamanGagal>());
      expect(
        (hasil as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.bentukTidakWajar,
        reason: '$hasil',
      );
    });

    test('kertas melengkung 3% → sisi tidak lurus; 0,5% masih diterima', () {
      const kuad = [
        (x: 60.0, y: 80.0),
        (x: 420.0, y: 70.0),
        (x: 430.0, y: 560.0),
        (x: 50.0, y: 570.0),
      ];

      final melengkung = _daftar(_fotoDariKuad(kuad, lengkung: 0.03));
      expect(melengkung, isA<RegistrasiHalamanGagal>());
      expect(
        (melengkung as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.sisiTidakLurus,
        reason: '$melengkung',
      );

      final f = _fotoDariKuad(kuad, lengkung: 0.005);
      final hampirLurus = _daftar(f);
      expect(hampirLurus, isA<RegistrasiHalamanBerhasil>());
      final uk = ukurSudut(
        'lengkung-kecil',
        f,
        (hampirLurus as RegistrasiHalamanBerhasil).sudutFoto,
      );
      expect(uk.galatSudutPctFoto, lessThan(0.3));
    });

    test('alas putih: ditolak (tidak ada pemisah dari kertas; 4 seed)', () {
      for (var i = 0; i < 4; i++) {
        final f = hasilkanFotoSintetis(
          SpesifikasiFoto(
            seed: 700 + i,
            lebarFoto: 480,
            tinggiFoto: 640,
            alas: JenisAlas.putih,
            rollDeg: i * 5.0 - 5,
            pitchDeg: 8,
            isi: 0.88,
          ),
        );

        final hasil = _daftar(f);

        // Kalau suatu saat diterima, sudutnya wajib benar — tetapi pada seed
        // ini tidak ada yang lolos, dan itu yang dikunci di sini.
        expect(hasil, isA<RegistrasiHalamanGagal>(), reason: 'putih #$i');
      }
    });

    test('alas krem: diterima dengan sudut benar (atau ditolak)', () {
      var diterima = 0;
      for (var i = 0; i < 4; i++) {
        final f = hasilkanFotoSintetis(
          SpesifikasiFoto(
            seed: 710 + i,
            lebarFoto: 480,
            tinggiFoto: 640,
            alas: JenisAlas.krem,
            rollDeg: i * 5.0 - 5,
            pitchDeg: 8,
            isi: 0.88,
          ),
        );

        final hasil = deteksiSudutHalaman(f.foto);

        if (hasil is DeteksiHalamanBerhasil) {
          diterima++;
          final uk = ukurSudut('krem$i', f, hasil.sudut);
          expect(uk.galatSudutPctFoto, lessThan(0.3), reason: 'krem #$i');
        }
      }
      // Sebagian boleh ditolak (gagal-aman), bukan salah.
      expect(diterima, greaterThanOrEqualTo(2));
    });

    test(
      'bercak seperti tangan di tepi: ditolak atau sudutnya tetap benar',
      () {
        for (var i = 0; i < 4; i++) {
          final f = hasilkanFotoSintetis(
            SpesifikasiFoto(
              seed: 800 + i,
              lebarFoto: 480,
              tinggiFoto: 640,
              alas: JenisAlas.values[i % 3],
              rollDeg: i * 4.0 - 6,
              pitchDeg: 10,
              isi: 0.85,
              tanganTepi: true,
            ),
          );
          final hasil = _daftar(f);
          if (hasil is RegistrasiHalamanBerhasil) {
            final uk = ukurSudut('tangan$i', f, hasil.sudutFoto);
            expect(uk.galatSudutPctFoto, lessThan(0.5), reason: 'tangan #$i');
          }
        }
      },
    );

    test('rasio halaman jauh dari formulir → rasio tidak cocok', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 21,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 5,
          isi: 0.88,
        ),
      );

      // Foto Letter potret (0,77); formulir Legal potret = 0,61 (-21%).
      final legal = registrasiHalaman(f.foto, halamanPt: _legal, skala: 0.5);
      expect(
        (legal as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.rasioTidakCocok,
      );
    });

    test(
      'Letter vs A4 (selisih 9%) tidak dibedakan: rasio hanya kewajaran',
      () {
        final f = hasilkanFotoSintetis(
          const SpesifikasiFoto(
            seed: 22,
            lebarFoto: 480,
            tinggiFoto: 640,
            rollDeg: -4,
            isi: 0.88,
          ),
        );

        final hasil = registrasiHalaman(
          f.foto,
          halamanPt: (w: 595.2, h: 841.8),
          skala: 0.5,
        );

        expect(hasil, isA<RegistrasiHalamanBerhasil>());
      },
    );
  });

  group('API', () {
    test('lanskap difoto potret: putaran ganjil, sudut tetap benar', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 31,
          halamanPt: (w: 792.0, h: 612.0),
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 88,
          pitchDeg: 6,
          isi: 0.88,
        ),
      );
      final hasil = registrasiHalaman(f.foto, halamanPt: f.halamanPt, skala: 1);

      expect(hasil, isA<RegistrasiHalamanBerhasil>(), reason: '$hasil');
      final b = hasil as RegistrasiHalamanBerhasil;
      expect(b.putaranKuadran.isOdd, isTrue);
      expect(b.citra.width, 792);
      expect(b.citra.height, 612);
      expect(ukurSudut('l', f, b.sudutFoto).galatSudutPctFoto, lessThan(0.25));

      // Arah 90° dan 180° tidak bisa ditentukan dari bentuk: pemanggil yang
      // tidak menemukan teks cetak boleh meminta urutan lain dari sudut yang
      // SAMA (tanpa deteksi ulang). Dari sudut berurut-halaman, putaran 2 =
      // halaman terbalik 180°.
      final terbalik =
          luruskanHalaman(
                f.foto,
                b.sudutFoto,
                halamanPt: f.halamanPt,
                skala: 1,
                putaranKuadran: 2,
              )
              as RegistrasiHalamanBerhasil;
      final lurus =
          luruskanHalaman(
                f.foto,
                b.sudutFoto,
                halamanPt: f.halamanPt,
                skala: 1,
                putaranKuadran: 0,
              )
              as RegistrasiHalamanBerhasil;
      var terbesar = 0.0;
      for (var y = 10; y < 602; y += 37) {
        for (var x = 10; x < 782; x += 41) {
          final a = lurus.citra.getPixel(x, y).luminance;
          final c = terbalik.citra.getPixel(791 - x, 611 - y).luminance;
          terbesar = math.max(terbesar, (a - c).abs().toDouble());
        }
      }
      expect(
        terbesar,
        lessThan(20),
        reason: 'selisih piksel terbesar $terbesar',
      );
    });

    test('hasil warp: citra baru tanpa EXIF, bukan foto asli', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 41,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 6,
        ),
      );
      f.foto.exif.imageIfd.imageDescription = 'SIDIK-ARSIP-SALINAN-v1';

      final hasil = _daftar(f) as RegistrasiHalamanBerhasil;

      expect(identical(hasil.citra, f.foto), isFalse);
      // Penanda salinan arsip (Fase 1) tidak boleh terbawa ke citra warp:
      // piksel baru dibuat dari nol.
      expect(hasil.citra.exif.imageIfd.imageDescription, isNull);
      expect(hasil.citra.numChannels, 3);
      expect(hasil.citra.format, img.Format.uint8);
      expect(hasil.citra.width, (612 * 0.5).round());
      expect(hasil.citra.height, (792 * 0.5).round());
    });

    test('EXIF orientasi dipanggang sebelum deteksi', () {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 51,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 7,
          pitchDeg: 8,
          isi: 0.88,
        ),
      );
      // Sensor menyimpan foto miring 90° dan EXIF orientasi 6 memintanya
      // diputar kembali — begitulah foto kamera potret disimpan.
      final tersimpan = img.copyRotate(f.foto, angle: -90);
      tersimpan.exif.imageIfd.orientation = 6;

      final asli = _daftar(f) as RegistrasiHalamanBerhasil;
      final lewatExif = registrasiHalaman(
        tersimpan,
        halamanPt: f.halamanPt,
        skala: 0.5,
      );

      expect(lewatExif, isA<RegistrasiHalamanBerhasil>(), reason: '$lewatExif');
      final b = lewatExif as RegistrasiHalamanBerhasil;
      for (var i = 0; i < 4; i++) {
        expect(b.sudutFoto[i].x, closeTo(asli.sudutFoto[i].x, 2));
        expect(b.sudutFoto[i].y, closeTo(asli.sudutFoto[i].y, 2));
      }
    });

    test(
      'JPEG kamera dengan EXIF orientasi 6: dipanggang di isolate',
      () async {
        final f = hasilkanFotoSintetis(
          const SpesifikasiFoto(
            seed: 52,
            lebarFoto: 480,
            tinggiFoto: 640,
            rollDeg: -6,
            pitchDeg: 9,
            isi: 0.88,
          ),
        );
        final tersimpan = img.copyRotate(f.foto, angle: -90);
        tersimpan.exif.imageIfd.orientation = 6;
        final jpeg = Uint8List.fromList(img.encodeJpg(tersimpan, quality: 90));
        // Pastikan EXIF-nya memang ikut tertulis (kalau tidak, ujinya palsu).
        expect(img.decodeJpgExif(jpeg)?.imageIfd.orientation, 6);

        final tegak = _daftar(f) as RegistrasiHalamanBerhasil;
        final hasil = await registrasiHalamanDariBitaDiIsolate(
          jpeg,
          halamanPt: f.halamanPt,
          skala: 0.5,
        );

        expect(hasil, isA<RegistrasiHalamanBerhasil>(), reason: '$hasil');
        final b = hasil as RegistrasiHalamanBerhasil;
        for (var i = 0; i < 4; i++) {
          expect(b.sudutFoto[i].x, closeTo(tegak.sudutFoto[i].x, 3));
          expect(b.sudutFoto[i].y, closeTo(tegak.sudutFoto[i].y, 3));
        }
      },
    );

    test('registrasiHalamanDiIsolate = hasil sinkron', () async {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 61,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: -8,
        ),
      );
      final sinkron = _daftar(f) as RegistrasiHalamanBerhasil;

      final isolat = await registrasiHalamanDiIsolate(
        f.foto,
        halamanPt: f.halamanPt,
        skala: 0.5,
      );

      expect(isolat, isA<RegistrasiHalamanBerhasil>());
      final b = isolat as RegistrasiHalamanBerhasil;
      for (var i = 0; i < 4; i++) {
        expect(b.sudutFoto[i].x, closeTo(sinkron.sudutFoto[i].x, 1e-9));
        expect(b.sudutFoto[i].y, closeTo(sinkron.sudutFoto[i].y, 1e-9));
      }
      expect(b.citra.width, sinkron.citra.width);
    });

    test('dari bita JPEG/PNG; sampah → foto tidak terbaca', () async {
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 71,
          lebarFoto: 480,
          tinggiFoto: 640,
          rollDeg: 3,
        ),
      );

      final jpeg = Uint8List.fromList(img.encodeJpg(f.foto, quality: 85));
      final dariJpeg = await registrasiHalamanDariBitaDiIsolate(
        jpeg,
        halamanPt: f.halamanPt,
        skala: 0.5,
      );
      expect(dariJpeg, isA<RegistrasiHalamanBerhasil>(), reason: '$dariJpeg');

      final png = Uint8List.fromList(img.encodePng(f.foto));
      expect(
        await registrasiHalamanDariBitaDiIsolate(
          png,
          halamanPt: f.halamanPt,
          skala: 0.5,
        ),
        isA<RegistrasiHalamanBerhasil>(),
      );

      final sampah = await registrasiHalamanDariBitaDiIsolate(
        Uint8List.fromList(List.generate(500, (i) => i % 251)),
        halamanPt: f.halamanPt,
      );
      expect(
        (sampah as RegistrasiHalamanGagal).alasan,
        AlasanGagalRegistrasi.fotoTidakTerbaca,
      );
    });

    test('warp menaruh isi halaman di tempat yang benar (bukan diputar)', () {
      // Foto tanpa degradasi apa pun: yang diuji adalah geometri warp itu
      // sendiri. Pembanding = halaman bersih yang diskalakan ke kanvas warp.
      final f = hasilkanFotoSintetis(
        const SpesifikasiFoto(
          seed: 81,
          lebarFoto: 960,
          tinggiFoto: 1280,
          rollDeg: 9,
          pitchDeg: 12,
          yawDeg: -8,
          isi: 0.88,
          bersih: true,
        ),
      );
      final hasil =
          registrasiHalaman(f.foto, halamanPt: f.halamanPt, skala: 1.5)
              as RegistrasiHalamanBerhasil;
      final warp = hasil.citra;

      // Rata-rata blok 8×8: garis tabel 1 px yang bergeser setengah piksel
      // tidak mengubah rata-rata blok, sedangkan salah putar/cermin mengubahnya
      // total.
      double selisih(bool balik) {
        var jumlah = 0.0;
        var n = 0;
        // Abaikan 3% tepi: bayangan tepi kertas dan sampel di luar foto.
        final x0 = (warp.width * 0.03).round();
        final y0 = (warp.height * 0.03).round();
        for (var by = y0; by + 8 <= warp.height - y0; by += 8) {
          for (var bx = x0; bx + 8 <= warp.width - x0; bx += 8) {
            var lumWarp = 0.0;
            var lumHarap = 0.0;
            for (var y = by; y < by + 8; y++) {
              for (var x = bx; x < bx + 8; x++) {
                lumWarp += warp.getPixel(x, y).luminance;
                var rx = ((x + 0.5) / warp.width * f.rasterW).floor();
                var ry = ((y + 0.5) / warp.height * f.rasterH).floor();
                if (balik) {
                  rx = f.rasterW - 1 - rx;
                  ry = f.rasterH - 1 - ry;
                }
                // Kertas di foto = nilai raster × 241,1/255.
                lumHarap += f.raster[ry * f.rasterW + rx] * 241.1 / 255;
              }
            }
            jumlah += (lumWarp - lumHarap).abs() / 64;
            n++;
          }
        }

        return jumlah / n;
      }

      final benar = selisih(false);
      final terbalik = selisih(true);

      expect(benar, lessThan(6), reason: 'selisih rata-rata blok $benar');
      expect(
        benar,
        lessThan(terbalik * 0.6),
        reason: 'benar $benar vs terbalik 180° $terbalik',
      );
    });
  });
}

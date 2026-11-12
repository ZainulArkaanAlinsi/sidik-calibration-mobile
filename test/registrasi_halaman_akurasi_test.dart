// Akurasi page registration pada foto SINTETIS (Dart murni; lihat
// `test/support/foto_sintetis_halaman.dart`): matriks variasi (rotasi,
// tilt/perspektif kamera lubang-jarum, blur, derau, JPEG, cahaya tak rata,
// bayangan tangan) di alas gelap, sedang, dan kayu terang berwarna, lalu alas
// terang (krem, putih). Geometri 26 foto prototipe ada di
// `registrasi_halaman_prototipe_test.dart`.
//
// Target dari spesifikasi: galat sudut maks ≤ 0,5% diagonal foto, ≥ 99% sel
// IoU ≥ 0,7 sesudah warp, dan KEGAGALAN selalu gagal-aman.
//
// Batas jujur: ini foto sintetis. Foto nyata (meja berkilap, kertas
// melengkung, tangan, pantulan lampu) belum diuji.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/registrasi_halaman/registrasi_halaman.dart';

import 'support/foto_sintetis_halaman.dart';
import 'support/registrasi_halaman_uji.dart';
import 'support/ukur_registrasi_halaman.dart';

void main() {
  test(
    'matriks variasi: alas gelap, sedang, kayu terang, lanskap-di-potret',
    () {
      final rng = math.Random(2026);
      double u(double a, double b) => a + (b - a) * rng.nextDouble();
      const halaman = [
        (w: 612.0, h: 792.0), // Letter potret
        (w: 595.2, h: 841.8), // A4 potret
        (w: 792.0, h: 612.0), // Letter lanskap
        (w: 841.8, h: 595.2), // A4 lanskap
        (w: 612.0, h: 1008.0), // Legal
      ];

      final semua = <UkuranFoto>[];
      final perKelompok = <String, List<UkuranFoto>>{};

      void jalankan(String kelompok, int i, SpesifikasiFoto spek) {
        final f = hasilkanFotoSintetis(spek);
        final h = registrasiHalaman(
          f.foto,
          halamanPt: spek.halamanPt,
          skala: 0.5,
        );
        final uk = ukurHasil('${kelompok}_$i', f, h);
        semua.add(uk);
        (perKelompok[kelompok] ??= []).add(uk);
      }

      for (final alas in [
        (JenisAlas.gelap, 6),
        (JenisAlas.sedang, 4),
        (JenisAlas.kayuTerang, 4),
      ]) {
        for (var i = 0; i < alas.$2; i++) {
          final hal = halaman[i % halaman.length];
          final lanskap = hal.w > hal.h;
          jalankan(
            alas.$1.name,
            i,
            SpesifikasiFoto(
              seed: 500 + semua.length,
              halamanPt: hal,
              lebarFoto: lanskap ? 640 : 480,
              tinggiFoto: lanskap ? 480 : 640,
              alas: alas.$1,
              rollDeg: u(-25, 25),
              pitchDeg: u(0, 22),
              yawDeg: u(-18, 18),
              isi: u(0.86, 0.93),
              geserX: u(-1, 1),
              geserY: u(-1, 1),
              fRel: u(0.75, 1.1),
              gradienCahaya: u(0.05, 0.3),
              bayanganTangan: rng.nextBool() ? u(0.1, 0.4) : 0,
              blurPx: u(0.3, 1.0),
              noise: u(3, 11),
              jpegQ: 55 + rng.nextInt(35),
            ),
          );
        }
      }

      // Lanskap difoto potret (terputar ~90°).
      for (var i = 0; i < 4; i++) {
        jalankan(
          'lanskapDiPotret',
          i,
          SpesifikasiFoto(
            seed: 600 + i,
            halamanPt: halaman[2 + i % 2],
            lebarFoto: 480,
            tinggiFoto: 640,
            rollDeg: (i.isEven ? 90 : -90) + u(-10, 10),
            pitchDeg: u(0, 15),
            yawDeg: u(-10, 10),
            isi: u(0.86, 0.92),
            geserX: u(-1, 1),
            geserY: u(-1, 1),
            blurPx: 0.5,
            noise: 5,
            jpegQ: 70,
          ),
        );
      }

      for (final e in perKelompok.entries) {
        laporUkur(RingkasanUkur(e.key, e.value));
      }
      final ringkasan = RingkasanUkur('semua', semua);
      laporUkur(ringkasan);

      // Deteksi: sebagian kecil boleh ditolak (halaman terlalu kecil di foto
      // yang diputar), tetapi TIDAK ADA yang salah.
      expect(ringkasan.fraksiTerdeteksi, greaterThanOrEqualTo(0.9));
      for (final alasan in ringkasan.alasanGagal.keys) {
        expect(alasan, 'halamanTerlaluKecil');
      }
      expect(ringkasan.galatMaksPctFoto, lessThanOrEqualTo(0.5));
      expect(ringkasan.fraksiSelIou07, greaterThanOrEqualTo(0.99));
      expect(ringkasan.fraksiSelGeser025, 0);
    },
  );

  test(
    'alas terang: krem diterima lewat kroma, putih ditolak, tidak ada salah',
    () {
      final rng = math.Random(77);
      double u(double a, double b) => a + (b - a) * rng.nextDouble();

      UkuranFoto jalankan(String nama, JenisAlas alas, int seed) {
        final spek = SpesifikasiFoto(
          seed: seed,
          lebarFoto: 480,
          tinggiFoto: 640,
          alas: alas,
          rollDeg: u(-20, 20),
          pitchDeg: u(0, 20),
          yawDeg: u(-15, 15),
          isi: u(0.86, 0.93),
          geserX: u(-1, 1),
          geserY: u(-1, 1),
          gradienCahaya: u(0.05, 0.3),
          bayanganTangan: rng.nextBool() ? u(0.1, 0.35) : 0,
          blurPx: u(0.3, 1.0),
          noise: u(3, 10),
          jpegQ: 60 + rng.nextInt(30),
        );
        final f = hasilkanFotoSintetis(spek);

        return ukurHasil(
          nama,
          f,
          registrasiHalaman(f.foto, halamanPt: spek.halamanPt, skala: 0.5),
        );
      }

      final krem = [
        for (var i = 0; i < 8; i++)
          jalankan('krem_$i', JenisAlas.krem, 1200 + i),
      ];
      final putih = [
        for (var i = 0; i < 4; i++)
          jalankan('putih_$i', JenisAlas.putih, 1300 + i),
      ];
      final rKrem = RingkasanUkur('alas krem', krem);
      final rPutih = RingkasanUkur('alas putih', putih);
      laporUkur(rKrem);
      laporUkur(rPutih);

      // Krem: sebagian diterima, yang diterima benar, sisanya ditolak.
      expect(rKrem.ok.length, greaterThanOrEqualTo(4));
      expect(rKrem.galatMaksPctFoto, lessThanOrEqualTo(0.3));
      expect(rKrem.fraksiSelIou07, greaterThanOrEqualTo(0.99));
      // Putih: yang diterima (kalau ada) tetap benar.
      for (final u in rPutih.ok) {
        expect(u.galatSudutPctFoto, lessThanOrEqualTo(0.5), reason: u.nama);
      }
    },
  );
}

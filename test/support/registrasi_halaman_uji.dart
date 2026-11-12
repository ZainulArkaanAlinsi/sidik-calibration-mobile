// Pembantu bersama uji akurasi page registration yang memakai tipe hasil
// registrasi (jadi bergantung Flutter, berbeda dari `ukur_registrasi_halaman`
// yang murni Dart).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:sidik_calibration/services/registrasi_halaman/registrasi_halaman.dart';

import 'foto_sintetis_halaman.dart';
import 'ukur_registrasi_halaman.dart';

UkuranFoto ukurHasil(String nama, FotoSintetis f, HasilRegistrasiHalaman h) =>
    switch (h) {
      RegistrasiHalamanBerhasil() => ukurSudut(
        nama,
        f,
        h.sudutFoto,
        msDeteksi: h.diagnostik.durasiDeteksiMs,
        msWarp: h.durasiWarpMs,
        putaran: h.putaranKuadran,
      ),
      RegistrasiHalamanGagal() => ukurSudut(
        nama,
        f,
        null,
        alasan: h.alasan.name,
      ),
    };

// Dicetak supaya angkanya ada di log CI; bukan bagian assert.
// ignore: avoid_print
void laporUkur(RingkasanUkur r) => print('[registrasi_halaman] $r');

List<Map<String, dynamic>> muatPrototipe() {
  final data =
      jsonDecode(
            File(
              'test/fixtures/registrasi_halaman/geometri_prototipe.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  return (data['foto'] as List).cast<Map<String, dynamic>>();
}

/// Foto ke-[n] prototipe dengan kanvas diskalakan [sk]: homografi sebenarnya
/// dan kotak sel dari kunci jawaban, sisanya (meja, cahaya, bayangan) diundi
/// dari parameter degradasi prototipe.
FotoSintetis fotoPrototipe(Map<String, dynamic> g, int n, double sk) {
  // Warna meja prototipe (sintesis.py: latar()).
  const meja = [(70, 90, 110), (110, 95, 80), (95, 100, 105), (60, 70, 65)];
  const px2pt = 72 / 250;
  final rng = math.Random(n);
  final kanvas = (g['kanvas'] as List).cast<num>();
  final hp = (g['halaman_pt'] as List).cast<num>();
  final deg = g['deg'] as Map<String, dynamic>;
  final berat = deg['berat'] as bool;
  final hRaster = (g['H'] as List)
      .cast<num>()
      .map((e) => e.toDouble())
      .toList();
  // piksel raster 250 dpi → piksel foto kanvas penuh → kanvas ×[sk].
  final hPt = kali3(kali3([sk, 0, 0, 0, sk, 0, 0, 0, 1], hRaster), [
    1 / px2pt,
    0,
    0,
    0,
    1 / px2pt,
    0,
    0,
    0,
    1,
  ]);

  return hasilkanFotoSintetis(
    SpesifikasiFoto(
      seed: 4000 + n,
      halamanPt: (w: hp[0].toDouble(), h: hp[1].toDouble()),
      lebarFoto: (kanvas[0] * sk).round(),
      tinggiFoto: (kanvas[1] * sk).round(),
      warnaAlas: meja[rng.nextInt(meja.length)],
      gradienCahaya: berat
          ? 0.25 + 0.2 * rng.nextDouble()
          : 0.1 + 0.18 * rng.nextDouble(),
      bayanganTangan: rng.nextBool() ? 0.15 + 0.15 * rng.nextDouble() : 0,
      blurPx: (deg['blur_sigma'] as num) * sk,
      noise: (deg['noise_sigma'] as num).toDouble(),
      jpegQ: g['jpeg_q'] as int,
      homografi: hPt,
      sel: [
        for (final b in (g['sel'] as List))
          KotakPt(
            (b[0] as num) * px2pt,
            (b[1] as num) * px2pt,
            (b[2] as num) * px2pt,
            (b[3] as num) * px2pt,
          ),
      ],
    ),
  );
}

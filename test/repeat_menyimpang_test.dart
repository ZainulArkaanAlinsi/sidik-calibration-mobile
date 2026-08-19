import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Satu digit yang ketuker waktu ngetik.
///
/// **Kejadian nyata `CAL/2026/08/0043`.** Titik 738,5 diketik
/// `738,63 / 783,52 / 738,52` — `783,52` itu `738,52` dengan digit 3 & 8
/// tertukar. Nilainya cuma 6% dari nominalnya, jadi penjaga orde
/// ([TitikState.adaPembacaanJauhDariTitik], faktor 10x) lolos mulus, dan
/// `bukan_kelipatan_resolusi` juga lolos karena 783,52 kelipatan 0,01.
///
/// Buat alat yang U95-nya lahir per KELOMPOK (Spectrophotometer), satu angka
/// itu menaikkan U95 SEMBILAN titik saudaranya dari 0,40 nm ke 84,84 nm — 212x
/// CMC lab. Sertifikatnya tetap terbit, dan angka itu sampai ke pelanggan
/// sebagai klaim ketidakpastian resmi.
void main() {
  LembarKerjaState buatState() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaSpectro()),
    clientRequestId: 'uji-menyimpang',
  );

  void isi(TitikState titik, List<double> nilai) {
    for (var i = 0; i < nilai.length; i++) {
      titik.kotak('sesudah_adjustment', 'pembacaan', i).text = '${nilai[i]}';
    }
  }

  test('digit ketuker ketahuan — 783,52 di baris 738,5', () {
    final state = buatState();
    final titik = state.titik[738.5]!;

    isi(titik, [738.63, 783.52, 738.52]);

    expect(titik.adaRepeatMenyimpang, isTrue);
    expect(state.titikRepeatMenyimpang.map((t) => t.titikUkur), contains(738.5));

    // Penjaga LAMA nggak nangkep ini, dan itu justru alasan penjaga baru ada:
    // 783,52 cuma 1,06x nominalnya, jauh di bawah ambang 10x.
    expect(titik.adaPembacaanJauhDariTitik, isFalse);

    state.dispose();
  });

  test('pembacaan wajar nggak ke-flag', () {
    final state = buatState();
    final titik = state.titik[738.5]!;

    // Angka master: sebarannya 0,11 nm di alat resolusi 0,01 nm — wajar.
    isi(titik, [738.63, 738.52, 738.52]);

    expect(titik.adaRepeatMenyimpang, isFalse);
    expect(state.titikRepeatMenyimpang, isEmpty);

    state.dispose();
  });

  test('alat yang beneran nggak stabil tetap boleh dikirim', () {
    final state = buatState();
    final titik = state.titik[738.5]!;

    // Sebaran 3 nm — jelek buat alat resolusi 0,01, dan itu TEMUAN kalibrasi
    // yang sah. Yang ditahan salah ketik, bukan alat pelanggan yang buruk.
    isi(titik, [738.6, 741.5, 739.8]);

    expect(titik.adaRepeatMenyimpang, isFalse);

    state.dispose();
  });

  test('dua pembacaan nggak cukup buat nuduh salah satunya', () {
    final state = buatState();
    final titik = state.titik[738.5]!;

    // Dengan dua angka, nggak ada cara tahu mana yang nyasar — dua-duanya
    // sama-sama "beda dari yang satunya".
    isi(titik, [738.63, 783.52]);

    expect(titik.adaRepeatMenyimpang, isFalse);

    state.dispose();
  });

  test('blok %T pakai ambangnya sendiri (resolusi 0,001)', () {
    final state = buatState();
    final titik = state.titik[9.9]!;

    // Resolusi %T 0,001 → ambangnya 1,0. Sebaran 2 %T di sini mustahil,
    // padahal angka yang sama di alat nm masih wajar.
    isi(titik, [9.668, 11.661, 9.666]);

    expect(titik.adaRepeatMenyimpang, isTrue);

    state.dispose();
  });
}

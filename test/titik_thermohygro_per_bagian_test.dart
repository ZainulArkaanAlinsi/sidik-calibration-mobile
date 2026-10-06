import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';

/// Titik ukur yang diatur teknisi berlaku per BAGIAN, bukan untuk seluruh
/// lembar.
///
/// Audit 6 Okt 2026: Thermohygro punya dua bagian bertitik-bisa-diubah —
/// Suhu (°C) dan Kelembaban (%RH). Daftar titik kustomnya cuma satu, jadi
/// mengubah titik suhu ikut menimpa titik %RH: pembacaan kelembaban
/// tercatat di set point suhu, tanpa error apa pun.
void main() {
  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaThermohygro()),
    clientRequestId: 'uji-titik-th',
  );

  List<double> titikBagian(LembarKerjaState isian, String kode) {
    final bagian = isian.bentuk.bagian.firstWhere((b) => b.kode == kode);
    return [for (final b in isian.barisTabel(bagian.tabel.first)) b.titikUkur];
  }

  test('ubah titik suhu tidak menyentuh titik kelembaban', () {
    final isian = isianBaru();
    final rhAwal = titikBagian(isian, 'hasil_kelembaban');
    expect(rhAwal, isNotEmpty);

    isian.aturTitik([15, 20, 25, 30, 35, 40], bagian: 'hasil_suhu');

    expect(titikBagian(isian, 'hasil_suhu'), [15, 20, 25, 30, 35, 40]);
    expect(
      titikBagian(isian, 'hasil_kelembaban'),
      rhAwal,
      reason: 'titik %RH ikut tertimpa titik suhu',
    );
  });

  test('ubah titik kelembaban tidak menyentuh titik suhu', () {
    final isian = isianBaru();
    final suhuAwal = titikBagian(isian, 'hasil_suhu');

    isian.aturTitik([40, 60, 80], bagian: 'hasil_kelembaban');

    expect(titikBagian(isian, 'hasil_kelembaban'), [40, 60, 80]);
    expect(titikBagian(isian, 'hasil_suhu'), suhuAwal);
    expect(isian.titikBerlakuUntuk('hasil_kelembaban'), [40, 60, 80]);
    expect(isian.titikBerlakuUntuk('hasil_suhu'), suhuAwal);
  });
}

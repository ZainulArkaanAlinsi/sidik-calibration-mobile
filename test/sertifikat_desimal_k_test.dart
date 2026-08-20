import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/certificate_snapshot.dart';

/// Faktor cakupan `k` dicetak dengan desimal yang ditentukan DOKUMEN, bukan
/// konvensi metrologi.
///
/// Master menyimpan nilai penuh tapi selnya diformat `0`: DO Meter menyimpan
/// 1,9718365067798587 di `SERTIFIKAT!V26` dan mencetak `2`; Spectrophotometer
/// menyimpan 3,1824… dan mencetak `3`.
///
/// Waktu layar sertifikat mematok dua desimal, admin memutuskan menerbitkan
/// sambil menatap `1,97` padahal PDF yang dikirim ke pelanggan menulis `2`.
/// Satu sertifikat, dua angka — dan selisih semacam itu baru ketahuan waktu
/// ada yang membandingkan dua dokumen berdampingan.
void main() {
  BarisHasilSertifikat titik(Map<String, dynamic> tambahan) =>
      BarisHasilSertifikat.fromJson({
        'titik_ke': 1,
        'standard_value': 8.77,
        'unit_under_test': 8.824,
        'correction': -0.054,
        'u95': 0.16,
        ...tambahan,
      });

  test('desimal_k kebaca dari snapshot', () {
    final t = titik({'faktor_cakupan_k': 1.9718365067798587, 'desimal_k': 0});

    expect(t.faktorCakupanK, 1.9718365067798587);
    expect(t.desimalK, 0);
  });

  /// Sertifikat yang terbit SEBELUM backend mengirim field ini nggak boleh
  /// berubah bunyi. `null` = perilaku lama.
  test('tanpa desimal_k, nilainya null — bukan dipaksa nol', () {
    final t = titik({'faktor_cakupan_k': 2.0});

    expect(t.desimalK, isNull);
  });

  /// Nilai mentahnya TETAP presisi penuh. Yang diatur cuma berapa digit yang
  /// ditulis — nggak ada pembulatan data yang ikut tersimpan.
  test('nilai k tetap utuh walau cetaknya dipangkas', () {
    final t = titik({'faktor_cakupan_k': 1.9718365067798587, 'desimal_k': 0});

    expect(t.faktorCakupanK, isNot(2.0));
    expect(t.faktorCakupanK, closeTo(1.9718365, 0.0000001));
  });
}

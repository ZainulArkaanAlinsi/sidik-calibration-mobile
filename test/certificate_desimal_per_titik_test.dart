import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/certificate_snapshot.dart';

/// Desimal PER TITIK di tabel Calibration Report.
///
/// Angka acuannya disalin dari Excel master PT Sidik buat Turbidimeter, jadi
/// yang diuji bukan "kodenya jalan" tapi "keluarannya sama persis dengan kertas
/// yang dipegang pelanggan":
///
///   Standard Value | Unit Under Test | Correction | U95% (±)
///   1,00           | 1,05            | -0,05      | 0,041
///   100            | 101             | -1         | 3,1
///
/// Sebelum ini seluruh tabel kepaksa ikut SATU angka desimal dari
/// `equipments.resolusi`, jadi baris kedua kecetak `100,00` / `101,00` / `-1,00`
/// — dua digit yang alatnya nggak bisa tampilkan. Turbidimeter resolusinya
/// 0,01 di bawah 10 NTU, 0,1 di 10–100, dan 1 di atas itu (tertulis di
/// Capacity/Graduation sertifikat asli 0189-CAL-624).
void main() {
  BarisHasilSertifikat baris(Map<String, dynamic> json) =>
      BarisHasilSertifikat.fromJson(json);

  group('desimal per titik', () {
    test('dipakai kalau backend ngirim, ngalahin desimal sertifikat', () {
      final b = baris({
        'titik_ke': 2,
        'standard_value': 100,
        'unit_under_test': 101,
        'correction': -1,
        'u95': 3.1,
        'desimal': 0,
      });

      // Sertifikatnya bilang 2, tapi titik ini 0 — yang menang yang per titik.
      expect(b.desimalEfektif(2), 0);
      expect(b.standardValue.toStringAsFixed(b.desimalEfektif(2)), '100');
      expect(b.unitUnderTest.toStringAsFixed(b.desimalEfektif(2)), '101');
      expect(b.correction.toStringAsFixed(b.desimalEfektif(2)), '-1');
    });

    test('titik resolusi halus tetap 2 desimal', () {
      final b = baris({
        'titik_ke': 1,
        'standard_value': 1,
        'unit_under_test': 1.05,
        'correction': -0.05,
        'u95': 0.041,
        'desimal': 2,
      });

      expect(b.standardValue.toStringAsFixed(b.desimalEfektif(2)), '1.00');
      expect(b.unitUnderTest.toStringAsFixed(b.desimalEfektif(2)), '1.05');
      expect(b.correction.toStringAsFixed(b.desimalEfektif(2)), '-0.05');
    });

    /// Sertifikat pH yang udah terbit TIDAK BOLEH berubah gara-gara perbaikan
    /// ini. `012-CAL-524` kecetak 2 desimal di semua titik — kalau tiba-tiba
    /// jadi `10,1`, dokumen resmi yang udah dipegang pelanggan jadi beda dari
    /// yang ada di app.
    test('snapshot lama tanpa desimal per titik → pakai desimal sertifikat', () {
      final b = baris({
        'titik_ke': 3,
        'standard_value': 9.9788769,
        'unit_under_test': 10.11,
        'correction': -0.1311231,
        'u95': 0.031,
      });

      expect(b.desimal, isNull);
      expect(b.desimalEfektif(2), 2);
      expect(b.standardValue.toStringAsFixed(b.desimalEfektif(2)), '9.98');
      expect(b.unitUnderTest.toStringAsFixed(b.desimalEfektif(2)), '10.11');
      expect(b.correction.toStringAsFixed(b.desimalEfektif(2)), '-0.13');
    });
  });
}

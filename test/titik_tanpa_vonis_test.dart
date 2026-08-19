import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart'
    show Keputusan;

/// Titik yang alatnya NGGAK divonis PASS/FAIL harus kebaca sebagai `null`.
///
/// Conductivity Meter nggak punya satu pun batas keberterimaan di master-nya;
/// sertifikatnya berhenti di `Correction` + `U95%`. Backend sengaja balikin
/// `keputusan: null` buat alat kayak gitu — kolomnya udah dibikin nullable di
/// `2026_08_10_150000_keputusan_titik_boleh_null`.
///
/// Sisi mobile nggak pernah ikut: field-nya non-nullable dan parsingnya
/// `json['keputusan'] == 'FAIL' ? fail : pass`, jadi **null mendarat jadi
/// PASS**. Layar detail nampilin badge hijau "PASS" di titik yang nggak punya
/// kriteria kelulusan sama sekali — di layar yang dipakai admin buat mutusin
/// nerbitin sertifikat, di atas angka yang errornya 1411.
void main() {
  Map<String, dynamic> titik(Object? keputusan) => {
    'titik_ke': 1,
    'titik_ukur': 1.412,
    'standard_id': 23,
    'rata_rata': 1413.0,
    'error': 1411.588,
    'koreksi': -1411.588,
    'standar_deviasi': 0.0,
    'jumlah_pengulangan': 5,
    'type_a': 0.0,
    'type_b': 0.0041,
    'ketidakpastian_gabungan': 0.0041,
    'faktor_cakupan_k': 1.97,
    'ketidakpastian_diperluas': 0.0081,
    'toleransi': 0.0,
    'keputusan': keputusan,
  };

  test('keputusan null kebaca null, BUKAN pass', () {
    expect(MeasurementResult.fromJson(titik(null)).keputusan, isNull);
  });

  test('field keputusan yang nggak dikirim sama sekali juga null', () {
    final tanpaKolom = titik(null)..remove('keputusan');

    expect(MeasurementResult.fromJson(tanpaKolom).keputusan, isNull);
  });

  test('PASS & FAIL tetap kebaca seperti biasa', () {
    expect(MeasurementResult.fromJson(titik('PASS')).keputusan, Keputusan.pass);
    expect(MeasurementResult.fromJson(titik('FAIL')).keputusan, Keputusan.fail);
  });

  test('nilai asing nggak diam-diam jadi pass', () {
    expect(MeasurementResult.fromJson(titik('MUNGKIN')).keputusan, isNull);
  });
}

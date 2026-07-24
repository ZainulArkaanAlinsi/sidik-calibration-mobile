import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';

/// Isi tabel **Calibration Report** di sertifikat.
///
/// Angkanya disalin dari sertifikat asli `012-CAL-524` yang dikirim user, jadi
/// yang diuji di sini bukan "kodenya jalan" tapi "angkanya sama persis dengan
/// kertas yang dipegang pelanggan".
void main() {
  /// Baris buffer 7 dari sesi 012-CAL-524.
  ///
  /// Di sertifikat barisnya kebaca: Standard Value `6,99` · Unit Under Test
  /// `7,00` · Correction `-0,02` · U95% `0,02`.
  Map<String, dynamic> titikBuffer7() => {
    'titik_ke': 2,
    'titik_ukur': 6.9889072,
    'rata_rata': 7.004,
    'error': 0.0150928,
    'koreksi': -0.0150928,
    'standar_deviasi': 0.0054772256,
    'jumlah_pengulangan': 5,
    'type_a': 0.0054772256,
    'type_b': 0.01047,
    'ketidakpastian_gabungan': 0.010714869,
    'faktor_cakupan_k': 1.9706589608,
    'ketidakpastian_diperluas': 0.0211089499,
    'toleransi': 0.05,
    'keputusan': 'PASS',
    'standar_acuan': {
      'id': 3,
      'nama': 'pH Buffer Solution 7',
      'no_sertifikat': 'HC46341939',
    },
  };

  CalibrationDetail detail() => CalibrationDetail.fromJson({
    'id': 3,
    'status': 'disetujui',
    'tanggal_kalibrasi': '2024-05-26T00:00:00Z',
    'equipment': {'nama_alat': 'pH Meter'},
    'teknisi': {'nama': 'DR'},
    'hasil': {'keputusan': 'PASS'},
    'titik': [titikBuffer7()],
  });

  test('kolom Correction pakai `koreksi`, BUKAN `error`', () {
    final titik = detail().titik.single;

    // Dua field ini cuma beda tanda, dan gampang ketuker: worksheet olah data
    // nampilin `error` (+0,02) di kolom yang JUGA dinamain "Correction",
    // sementara sertifikat nampilin `koreksi` (-0,02). Kalau mobile ngambil
    // yang salah, tanda koreksi di sertifikat pelanggan kebalik — dan koreksi
    // itu angka yang dipakai pelanggan buat ngebenerin hasil ukurnya.
    expect(titik.koreksi.toStringAsFixed(2), '-0.02');
    expect(titik.error.toStringAsFixed(2), '0.02');
    expect(titik.koreksi, -titik.error);
  });

  test('empat kolom sertifikat cocok sama angka di kertas', () {
    final titik = detail().titik.single;

    expect(titik.titikUkur.toStringAsFixed(2), '6.99'); // Standard Value
    expect(titik.rataRata.toStringAsFixed(2), '7.00'); // Unit Under Test
    expect(titik.koreksi.toStringAsFixed(2), '-0.02'); // Correction
    expect(
      titik.ketidakpastianDiperluas.toStringAsFixed(2),
      '0.02',
    ); // U95% (±)
  });

  test('standar acuan bawa nomor sertifikat buat kolom Serial Number', () {
    final standar = detail().titik.single.standarAcuan;

    expect(standar?.nama, 'pH Buffer Solution 7');
    expect(standar?.noSertifikat, 'HC46341939');
  });

  test('sesi yang belum dihitung -> titik kosong, tabel nggak dipaksa render', () {
    final belum = CalibrationDetail.fromJson({
      'id': 9,
      'status': 'draft',
      'tanggal_kalibrasi': '2024-05-26T00:00:00Z',
      'equipment': {'nama_alat': 'pH Meter'},
      'teknisi': {'nama': 'DR'},
      'hasil': {'keputusan': 'PASS'},
      'titik': <dynamic>[],
    });

    expect(belum.titik, isEmpty);
  });
}

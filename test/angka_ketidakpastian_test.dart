import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/utils/angka.dart';

/// Harus keluar angka yang SAMA PERSIS kayak `App\Support\Angka::ketidakpastian()`
/// di backend — layar pratinjau dipakai buat nyocokin sama PDF-nya, jadi dua
/// angka beda buat satu pengukuran itu temuan audit.
void main() {
  group('U95 selalu kebaca 2 angka penting', () {
    const kasus = <(double, int, String)>[
      // Yang udah besar nggak berubah — desimal alat udah cukup.
      (0.2199435, 2, '0.22'),
      (1.7117242, 1, '1.7'),

      // Ini yang dulu rusak: kecetak "0.03" dan "0.02".
      (0.02658849, 2, '0.027'),
      (0.02343221, 2, '0.023'),
      (0.02110895, 2, '0.021'),
      (0.031, 2, '0.031'),

      // Alat 3 desimal, U lebih kecil lagi.
      (0.00234, 3, '0.0023'),
    ];

    for (final (nilai, desimal, harap) in kasus) {
      test('$nilai @ $desimal desimal -> $harap', () {
        expect(formatKetidakpastian(nilai, desimal), harap);
      });
    }
  });

  test('desimal alat itu LANTAI, bukan target', () {
    expect(formatKetidakpastian(0.2199435, 4), '0.2199');
  });

  test('nol nggak bikin desimalnya ngawur', () {
    // `log10(0)` = -Infinity; tanpa penjaga, desimalnya jadi ngawur.
    expect(formatKetidakpastian(0, 2), '0.00');
  });
}

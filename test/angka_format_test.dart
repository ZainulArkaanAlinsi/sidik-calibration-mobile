import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/angka.dart';

void main() {
  group('formatNilai — pad ke resolusi, nol belakang nggak dibuang', () {
    test('pembacaan dipad ke desimal resolusi titiknya', () {
      // Ini inti permintaan lab: 4.6 di titik ber-resolusi 0,01 harus tampil
      // 4.60 — nol terakhir itu INFORMASI (seberapa teliti kebaca), bukan hiasan.
      expect(formatNilai(4.6, desimalMin: 2), '4.60');
      expect(formatNilai(4.0, desimalMin: 2), '4.00');
      expect(formatNilai(99.8, desimalMin: 1), '99.8');
    });

    test('titik bulat resolusi 1 tampil tanpa desimal', () {
      expect(formatNilai(999.0, desimalMin: 0), '999');
      expect(formatNilai(1000.0, desimalMin: 0), '1000');
    });

    test('separator titik, ngikutin konvensi lembar perhitungan & PDF', () {
      expect(formatNilai(4.6, desimalMin: 2), '4.60');
      expect(formatNilai(4.6, desimalMin: 2), isNot(contains(',')));
    });

    test('nilai hitung presisi penuh tanpa pembulatan (desimalMin 0)', () {
      // "jangan ada pembulatan, tampilkan saja desimalnya".
      expect(formatNilai(0.14363147, desimalMin: 0), '0.14363147');
      // Derau float diserap batas 8 desimal — bukan dibulatkan ke desimal alat.
      expect(formatNilai(-0.20000000000000284, desimalMin: 0), '-0.2');
    });

    test('desimalMin lebih kecil dari desimal nyata → desimal nyata menang', () {
      // 4.6 dengan min 0: nol belakang nggak ada yang dibuang, tetap 4.6.
      expect(formatNilai(4.6, desimalMin: 0), '4.6');
      // Tapi min 2 maksa minimal 2 desimal.
      expect(formatNilai(4.6, desimalMin: 2), '4.60');
    });
  });
}

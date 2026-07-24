import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/worksheet_vision.dart';

void main() {
  group('GabungTabel — foto ulang nggak boleh nimpa', () {
    test('sel kosong keisi', () {
      expect(GabungTabel.nilaiBaru('', 4.04), '4.04');
      expect(GabungTabel.nilaiBaru('   ', 22.2), '22.2');
    });

    test('sel yang udah keisi TIDAK diubah', () {
      // Ini intinya. Teknisi motret, lihat AI salah baca `9,61` jadi `9,81`,
      // dia betulin manual. Foto berikutnya buat nambal sel lain nggak boleh
      // ngembaliin `9,81` — koreksinya bakal ilang tanpa jejak, dan yang masuk
      // sertifikat justru angka yang tadi salah.
      expect(GabungTabel.nilaiBaru('9.61', 9.81), isNull);
      expect(GabungTabel.nilaiBaru('4.00', 4.04), isNull);
    });

    test('AI nggak baca apa-apa → sel dibiarin apa adanya', () {
      expect(GabungTabel.nilaiBaru('', null), isNull);
      expect(GabungTabel.nilaiBaru('4.04', null), isNull);
    });

    test('nol di belakang dibuang, desimal asli dipertahankan', () {
      // pH ditulis 2 desimal, suhu cuma 1 — nggak boleh dipaksa seragam.
      expect(GabungTabel.nilaiBaru('', 4.0), '4');
      expect(GabungTabel.nilaiBaru('', 22.2), '22.2');
      expect(GabungTabel.nilaiBaru('', 4.04), '4.04');
      expect(GabungTabel.nilaiBaru('', 10.11), '10.11');
      expect(GabungTabel.nilaiBaru('', 100), '100');
    });
  });

  group('TingkatKeyakinan.fromApi', () {
    test('high/medium/low dikenali', () {
      expect(TingkatKeyakinan.fromApi('high'), TingkatKeyakinan.tinggi);
      expect(TingkatKeyakinan.fromApi('medium'), TingkatKeyakinan.sedang);
      expect(TingkatKeyakinan.fromApi('low'), TingkatKeyakinan.rendah);
    });

    test('string asing / null → rendah (lebih aman nyuruh cek)', () {
      expect(TingkatKeyakinan.fromApi('halo'), TingkatKeyakinan.rendah);
      expect(TingkatKeyakinan.fromApi(null), TingkatKeyakinan.rendah);
      expect(TingkatKeyakinan.rendah.perluDicek, isTrue);
      expect(TingkatKeyakinan.tinggi.perluDicek, isFalse);
    });
  });

  group('HasilEkstraksiTabel.fromJson', () {
    test('respons AI dipetakan ke sel + keyakinan, hitung sel kebaca', () {
      final hasil = HasilEkstraksiTabel.fromJson({
        'baris': [
          {
            'ph': [4.01, 7.02, 10.11],
            'suhu': [22.2, 22.3, 22.1],
            'ph_keyakinan': ['high', 'high', 'low'],
            'suhu_keyakinan': ['high', 'high', 'high'],
          },
        ],
      }, jumlahTitik: 3, jumlahBaris: 5);

      expect(hasil.baris.length, 1);
      expect(hasil.baris.first.ph, [4.01, 7.02, 10.11]);
      expect(hasil.baris.first.keyakinanPh(2), TingkatKeyakinan.rendah);
      expect(hasil.baris.first.keyakinanPh(0), TingkatKeyakinan.tinggi);
      expect(hasil.jumlahSelKebaca, 6);
      expect(hasil.jumlahSelDiharapkan, 30);
    });

    test('sel null (tak terbaca) nggak dihitung kebaca', () {
      final hasil = HasilEkstraksiTabel.fromJson({
        'baris': [
          {
            'ph': [4.01, null, 10.11],
            'suhu': [22.2, null, null],
          },
        ],
      }, jumlahTitik: 3, jumlahBaris: 5);

      // 2 pH + 1 suhu = 3 kebaca; null dilewat.
      expect(hasil.jumlahSelKebaca, 3);
      expect(hasil.baris.first.ph[1], isNull);
      // Tanpa field keyakinan → default tinggi (nggak nge-flag semua sel).
      expect(hasil.baris.first.keyakinanPh(0), TingkatKeyakinan.tinggi);
    });

    test('baris cacat dilewat, bukan bikin parse ambruk', () {
      final hasil = HasilEkstraksiTabel.fromJson({
        'baris': [
          {
            'ph': [4.01],
            'suhu': [22.2],
          },
          'bukan objek', // item cacat → dilewat oleh parseListAman
          {
            'ph': [7.02],
            'suhu': [22.3],
          },
        ],
      }, jumlahTitik: 1, jumlahBaris: 5);

      expect(hasil.baris.length, 2);
    });
  });
}

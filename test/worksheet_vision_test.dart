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

    test('desimal titik diisi → dipad ke resolusi (Turbidimeter)', () {
      // Titik 1 NTU resolusi 0,01 → 2 desimal: 4.6 masuk sebagai 4.60.
      expect(GabungTabel.nilaiBaru('', 4.6, desimal: 2), '4.60');
      // Titik 1000 NTU resolusi 1 → 0 desimal: 999 tetap 999.
      expect(GabungTabel.nilaiBaru('', 999.0, desimal: 0), '999');
      expect(GabungTabel.nilaiBaru('', 1000.0, desimal: 0), '1000');
      // Sel yang udah keisi tetap nggak ketimpa, walau ada desimal.
      expect(GabungTabel.nilaiBaru('4.60', 5.0, desimal: 2), isNull);
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

    test('respons tanpa "header" tetap jalan — header-nya kosong', () {
      // Backend versi lama cuma ngirim `baris`. Mobile nggak boleh ambruk atau
      // ngarang isi; tabelnya keisi, blok non-tabel dibiarin kosong.
      final hasil = HasilEkstraksiTabel.fromJson({
        'baris': [
          {
            'ph': [4.01],
            'suhu': [22.2],
          },
        ],
      }, jumlahTitik: 1, jumlahBaris: 5);

      expect(hasil.header.kosong, isTrue);
    });

    test('blok header ke-parse beserta usage check', () {
      final hasil = HasilEkstraksiTabel.fromJson({
        'baris': <dynamic>[],
        'header': {
          'field': {
            'suhu_awal': {'nilai': 22.2, 'keyakinan': 'high'},
            'catatan_teknisi': {'nilai': '  buffer baru  ', 'keyakinan': 'low'},
            'kelembaban_awal': {'nilai': null, 'keyakinan': 'low'},
          },
          'tanggal': {
            'tanggal_terima': {'nilai': '23/07/2026', 'keyakinan': 'medium'},
          },
          'usage_check': [
            {'standard_id': 3, 'dipakai': true, 'keyakinan': 'high'},
            {'dipakai': true}, // tanpa standard_id → dilewat
          ],
        },
      }, jumlahTitik: 3, jumlahBaris: 5);

      // Angka dikirim sebagai num, disimpen sebagai string.
      expect(hasil.header.field['suhu_awal']!.nilai, '22.2');
      // Spasi pinggir dibuang.
      expect(hasil.header.field['catatan_teknisi']!.nilai, 'buffer baru');
      // `null` = nggak kebaca → kolomnya nggak dibikin sama sekali, bukan
      // diisi string kosong yang bikin kolom "kelihatan udah diisi".
      expect(hasil.header.field.containsKey('kelembaban_awal'), isFalse);
      expect(hasil.header.tanggal['tanggal_terima']!.nilai, '23/07/2026');
      expect(hasil.header.usageCheck.length, 1);
      expect(hasil.header.usageCheck.first.standardId, 3);
    });
  });

  group('GabungTabel.nilaiBaruTeks — aturan sama kayak tabel', () {
    test('kolom kosong keisi, kolom terisi nggak ditimpa', () {
      expect(GabungTabel.nilaiBaruTeks('', 'buffer baru'), 'buffer baru');
      expect(GabungTabel.nilaiBaruTeks('   ', ' 22.2 '), '22.2');
      expect(GabungTabel.nilaiBaruTeks('catatan teknisi', 'versi AI'), isNull);
    });

    test('AI nggak baca apa-apa → kolom dibiarin', () {
      expect(GabungTabel.nilaiBaruTeks('', null), isNull);
      expect(GabungTabel.nilaiBaruTeks('', '   '), isNull);
    });
  });

  group('parseTanggalAi', () {
    test('format yang dikenali', () {
      expect(parseTanggalAi('2026-07-23'), DateTime(2026, 7, 23));
      // Konvensi formulir Indonesia: hari duluan.
      expect(parseTanggalAi('23/07/2026'), DateTime(2026, 7, 23));
      expect(parseTanggalAi('3-4-2026'), DateTime(2026, 4, 3));
    });

    test('tanggal ngawur ditolak, BUKAN digulung diam-diam', () {
      // `DateTime(2026, 2, 31)` diam-diam jadi 3 Maret. Tanggal kalibrasi yang
      // meleset itu lebih bahaya daripada kolom kosong yang diisi teknisi.
      expect(parseTanggalAi('31/02/2026'), isNull);
      expect(parseTanggalAi('23/13/2026'), isNull);
      expect(parseTanggalAi('kemarin'), isNull);
      expect(parseTanggalAi('23 Juli 2026'), isNull);
      expect(parseTanggalAi(''), isNull);
    });
  });
}

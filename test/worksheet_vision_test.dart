import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/worksheet_vision.dart';

void main() {
  group('MockWorksheetVisionService — sadar alat, bukan hardcode pH', () {
    final fotoPalsu = File('tidak-dipakai.jpg');

    test('Turbidimeter (nominal NTU) balikin angka NTU, bukan buffer pH', () async {
      final hasil = await MockWorksheetVisionService().ekstrak(
        fotoPalsu,
        jumlahTitik: 3,
        satuan: 'NTU',
        nominal: const [1, 100, 1000],
        desimal: const [2, 1, 0],
      );

      final baca = hasil!.baris.first.ph;
      // Tiap kolom mesti DEKAT nominalnya (bukan 4.01/7.02/10.11).
      expect(baca[0], closeTo(1, 0.1)); // ~1 NTU
      expect(baca[1], closeTo(100, 0.5)); // ~100 NTU
      expect(baca[2], closeTo(1000, 2)); // ~1000 NTU
      expect(baca, isNot(contains(7.02)));
      // Kolom terakhir dipad ke desimal 0 → bilangan bulat.
      expect(baca[2], baca[2]!.roundToDouble());
      // Usage check buffer pH nggak boleh nempel di alat non-pH.
      expect(hasil.header.usageCheck, isEmpty);
      // Catatan "buffer" juga nggak muncul buat non-pH.
      expect(hasil.header.field.containsKey('catatan_teknisi'), isFalse);
    });

    test('pH (satuan pH) tetap dapat usage check buffer + catatan', () async {
      final hasil = await MockWorksheetVisionService().ekstrak(
        fotoPalsu,
        jumlahTitik: 3,
        satuan: 'pH',
        nominal: const [4, 7, 10.01],
      );

      expect(hasil!.header.usageCheck, isNotEmpty);
      expect(hasil.header.field.containsKey('catatan_teknisi'), isTrue);
      expect(hasil.baris.first.ph[0], closeTo(4, 0.1));
    });
  });

  group('GabungTabel — foto ulang nggak boleh nimpa', () {
    test('sel kosong keisi', () {
      expect(GabungTabel.nilaiBaru('', 4.04), '4,04');
      expect(GabungTabel.nilaiBaru('   ', 22.2), '22,2');
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
      expect(GabungTabel.nilaiBaru('', 22.2), '22,2');
      expect(GabungTabel.nilaiBaru('', 4.04), '4,04');
      expect(GabungTabel.nilaiBaru('', 10.11), '10,11');
      expect(GabungTabel.nilaiBaru('', 100), '100');
    });

    test('desimal titik diisi → dipad ke resolusi (Turbidimeter)', () {
      // Titik 1 NTU resolusi 0,01 → 2 desimal: 4,6 masuk sebagai 4,60 —
      // KOMA, sama kayak sisa lembarnya.
      expect(GabungTabel.nilaiBaru('', 4.6, desimal: 2), '4,60');
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

    /// **Angka hasil foto nggak boleh kehilangan digit.**
    ///
    /// Bug lapangan 7 Agt 2026: AI baca `1,3362` dari foto tabel Refractometer,
    /// yang mendarat di kotak jadi `1,336`. Penyebabnya `toStringAsFixed(3)`
    /// dipatok di perapian angka — pembacaan resolusi 0,0001 dipotong jadi
    /// 0,001, sepuluh kali lebih kasar dari alatnya, tanpa satu pun error.
    ///
    /// Tiga alat pertama selamat cuma karena kebetulan resolusinya 0,01 semua,
    /// jadi muat di 3 desimal. Alat berikutnya yang lebih teliti bakal kena
    /// lagi kalau batas ini dipatok — makanya yang diuji BUKAN satu angka, tapi
    /// beberapa tingkat resolusi sekaligus.
    test('digit pembacaan nggak kepotong, seberapa pun telitinya alatnya', () {
      // 4 desimal — Refractometer (0,0001). Ini yang beneran kejadian.
      expect(GabungTabel.nilaiBaru('', 1.3362), '1,3362');
      expect(GabungTabel.nilaiBaru('', 1.39986), '1,39986');

      // 5-6 desimal — belum ada alatnya, tapi batas ini nggak boleh jadi
      // penghalang berikutnya.
      expect(GabungTabel.nilaiBaru('', 1.339351), '1,339351');

      // Nol di belakang TETAP dibuang: 25,0 tetap `25`, bukan `25,00000000`.
      //
      // Pemisah desimalnya KOMA, ngikut lembar kerja & formulir kertasnya —
      // lihat `WorksheetVisionService._rapi`. Ekspektasi di tes ini sempat
      // bertitik karena dua perbaikan (8 desimal & koma) lahir di dua branch
      // terpisah; disatuin waktu merge 10 Agt 2026.
      expect(GabungTabel.nilaiBaru('', 25.0), '25');
      expect(GabungTabel.nilaiBaru('', 4.60), '4,6');

      // Derau float nggak ikut kecetak.
      expect(GabungTabel.nilaiBaru('', 0.1 + 0.2), '0,3');
    });
  });

  group('mock kamera ngisi SEMUA Repeat, bukan cuma satu', () {
    /// Dulu mock ini balikin satu baris doang. Di lembar Chlorine (2 titik)
    /// hasilnya "4 dari 20 sel keisi" — di layar kebaca kayak kameranya gagal
    /// 80%, padahal cuma data contohnya yang sedikit. Dilaporin dari HP.
    test('chlorine 2 titik x 5 repeat -> 20 sel, bukan 4', () async {
      final hasil = await MockWorksheetVisionService().ekstrak(
        File('x.png'),
        jumlahTitik: 2,
        jumlahBaris: 5,
        satuan: 'mg/L',
        nominal: [1.74, 1.83],
        desimal: [null, null],
      );

      expect(hasil!.baris, hasLength(5));
      expect(hasil.jumlahSelKebaca, 20);
      // Kalau kebaca == diharapkan, layar nggak lagi nempelin kalimat
      // "sel yang kosong: ketik manual atau foto ulang".
      expect(hasil.jumlahSelDiharapkan, hasil.jumlahSelKebaca);
    });

    test('pH 3 titik x 5 repeat -> 30 sel', () async {
      final hasil = await MockWorksheetVisionService().ekstrak(
        File('x.png'),
        jumlahTitik: 3,
        jumlahBaris: 5,
        satuan: 'pH',
        nominal: [4.0, 7.0, 10.01],
      );

      expect(hasil!.baris, hasLength(5));
      expect(hasil.jumlahSelKebaca, 30);
    });

    /// Penandaan low-confidence itu pagar penting di alur foto — kalau nggak
    /// pernah kelihatan waktu demo, nggak ada yang tau dia ada. Disisain SATU
    /// sel supaya tetap kedemo tanpa bikin hasilnya kelihatan gagal.
    test('tetap ada TEPAT satu sel keyakinan rendah buat demo penandaannya', () async {
      final hasil = await MockWorksheetVisionService().ekstrak(
        File('x.png'),
        jumlahTitik: 2,
        jumlahBaris: 5,
        nominal: [1.74, 1.83],
      );

      var rendah = 0;
      for (var r = 0; r < hasil!.baris.length; r++) {
        for (var t = 0; t < 2; t++) {
          if (hasil.baris[r].keyakinanPh(t) == TingkatKeyakinan.rendah) rendah++;
        }
      }
      expect(rendah, 1);
    });
  });
}

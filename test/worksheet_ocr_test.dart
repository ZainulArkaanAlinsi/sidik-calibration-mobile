import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/worksheet_ocr.dart';

/// Ngunci logika penyusun tabel worksheet.
///
/// Ini bagian yang paling gampang salah diam-diam: angkanya kebaca semua, tapi
/// nempel ke kolom yang salah. Hasilnya kelihatan wajar — dan itu yang bikin
/// bahaya. Semua kasus di bawah pakai koordinat, bukan foto, jadi bisa diuji
/// tanpa kamera.
void main() {
  _pesanTidakBuntu();
  _regresiFotoSelembarPenuh();
  /// Susun koordinat kayak tabel asli: 5 baris × 3 buffer × (pH, °C),
  /// plus kolom nomor Repeat di paling kiri.
  ///
  /// Angkanya diambil dari worksheet 012-CAL-524 (After Adjustment).
  List<KotakAngka> tabelAsli({bool pakaiNomorRepeat = true}) {
    const ph = [
      [4.00, 7.01, 10.11],
      [4.00, 7.01, 10.11],
      [4.00, 7.00, 10.11],
      [4.00, 7.00, 10.11],
      [4.00, 7.00, 10.11],
    ];
    const suhu = [
      [22.2, 22.2, 22.1],
      [22.2, 22.2, 22.1],
      [22.1, 22.2, 22.1],
      [22.2, 22.2, 22.1],
      [22.2, 22.2, 22.1],
    ];

    final kotak = <KotakAngka>[];
    for (var b = 0; b < 5; b++) {
      final y = 100.0 + b * 40;
      if (pakaiNomorRepeat) {
        kotak.add(KotakAngka(nilai: (b + 1).toDouble(), x: 40, y: y));
      }
      for (var t = 0; t < 3; t++) {
        kotak.add(KotakAngka(nilai: ph[b][t], x: 120.0 + t * 160, y: y));
        kotak.add(KotakAngka(nilai: suhu[b][t], x: 200.0 + t * 160, y: y));
      }
    }
    return kotak;
  }

  HasilTabelOcr? susun(List<KotakAngka> kotak) =>
      TabelWorksheetParser.susun(kotak, teksMentah: 'uji');

  test('tabel utuh kesusun persis, kolom pH & suhu nggak ketuker', () {
    final hasil = susun(tabelAsli())!;

    expect(hasil.baris, hasLength(5));
    expect(hasil.kelengkapan, 1.0);

    expect(hasil.baris[0].ph, [4.00, 7.01, 10.11]);
    expect(hasil.baris[0].suhu, [22.2, 22.2, 22.1]);
    expect(hasil.baris[2].ph, [4.00, 7.00, 10.11]);
    expect(hasil.baris[2].suhu, [22.1, 22.2, 22.1]);
  });

  test('nomor Repeat di kolom kiri nggak kebaca jadi nilai pH', () {
    final hasil = susun(tabelAsli())!;

    // Kalau nomor barisnya ikut kepilih, baris ke-3 pH pertamanya jadi 3.0.
    for (var b = 0; b < 5; b++) {
      expect(hasil.baris[b].ph.first, 4.00, reason: 'baris ${b + 1}');
    }
  });

  test('tabel tanpa kolom nomor Repeat tetap kesusun', () {
    final hasil = susun(tabelAsli(pakaiNomorRepeat: false))!;

    expect(hasil.kelengkapan, 1.0);
    expect(hasil.baris[0].ph, [4.00, 7.01, 10.11]);
  });

  test('urutan acak dari ML Kit nggak ngubah hasil', () {
    // ML Kit nggak menjamin urutan blok ngikutin bacaan manusia — yang
    // nentuin posisi kolom itu koordinat, bukan urutan kemunculan.
    final acak = tabelAsli().reversed.toList();
    final hasil = susun(acak)!;

    expect(hasil.baris[0].ph, [4.00, 7.01, 10.11]);
    expect(hasil.baris[4].suhu, [22.2, 22.2, 22.1]);
  });

  test('sel yang hilang ninggalin lubang di kolomnya, nggak menggeser tetangga', () {
    final kotak = tabelAsli();
    // Buang satu sel suhu di baris pertama — worksheet-nya bolong / OCR kelewat.
    kotak.removeWhere((k) => k.y == 100 && k.x == 200);

    final hasil = susun(kotak)!;

    // Ini inti pengujiannya. Kalau angka dipasangin berurutan, `7,01` bakal
    // maju nempatin kolom suhu buffer pertama dan `10,11` jadi pH buffer
    // kedua — semuanya masih "masuk akal" jadi lolos diam-diam. Dengan kolom
    // global, yang kosong cuma sel yang emang hilang.
    expect(hasil.baris[0].ph, [4.00, 7.01, 10.11]);
    expect(hasil.baris[0].suhu, [null, 22.2, 22.1]);

    // Baris lain nggak ikut kena.
    expect(hasil.baris[1].ph, [4.00, 7.01, 10.11]);
    expect(hasil.baris[1].suhu, [22.2, 22.2, 22.1]);
    expect(hasil.kelengkapan, lessThan(1.0));
  });

  test('pH dan suhu ketuker → sel-nya ditolak, bukan diterima terbalik', () {
    final kotak = <KotakAngka>[];
    for (var t = 0; t < 3; t++) {
      // Sengaja dibalik: suhu di kolom kiri, pH di kanan.
      kotak.add(KotakAngka(nilai: 22.2, x: 120.0 + t * 160, y: 100));
      kotak.add(KotakAngka(nilai: 4.00, x: 200.0 + t * 160, y: 100));
    }

    final hasil = TabelWorksheetParser.susun(
      kotak,
      teksMentah: 'uji',
      jumlahBaris: 1,
    )!;

    // pH 22,2 itu mustahil (skala 0–14) — jadi pasangannya nggak dipakai.
    expect(hasil.baris[0].ph, [null, null, null]);
    expect(hasil.kelengkapan, 0.0);
  });

  test('foto kosong / nggak ada angka → null, bukan tabel kosong palsu', () {
    expect(susun([]), isNull);
  });

  group('GabungTabel — foto ulang nggak boleh nimpa', () {
    test('sel kosong keisi', () {
      expect(GabungTabel.nilaiBaru('', 4.04), '4.04');
      expect(GabungTabel.nilaiBaru('   ', 22.2), '22.2');
    });

    test('sel yang udah keisi TIDAK diubah', () {
      // Ini intinya. Teknisi motret, lihat OCR salah baca `9,61` jadi `9,81`,
      // dia betulin manual. Foto berikutnya buat nambal sel lain nggak boleh
      // ngembaliin `9,81` — koreksinya bakal ilang tanpa jejak, dan yang masuk
      // sertifikat justru angka yang tadi salah.
      expect(GabungTabel.nilaiBaru('9.61', 9.81), isNull);
      expect(GabungTabel.nilaiBaru('4.00', 4.04), isNull);
    });

    test('OCR nggak baca apa-apa → sel dibiarin apa adanya', () {
      expect(GabungTabel.nilaiBaru('', null), isNull);
      expect(GabungTabel.nilaiBaru('4.04', null), isNull);
    });

    test('nol di belakang dibuang, desimal asli dipertahankan', () {
      // pH ditulis 2 desimal, suhu cuma 1 — nggak boleh dipaksa seragam,
      // teknisi ngebandingin langsung sama worksheet.
      expect(GabungTabel.nilaiBaru('', 4.0), '4');
      expect(GabungTabel.nilaiBaru('', 22.2), '22.2');
      expect(GabungTabel.nilaiBaru('', 4.04), '4.04');
      expect(GabungTabel.nilaiBaru('', 10.11), '10.11');
      // Bilangan bulat besar nggak boleh kepotong nol-nya.
      expect(GabungTabel.nilaiBaru('', 100), '100');
    });
  });

  group('keAngka', () {
    test('koma dibaca sebagai titik desimal', () {
      expect(TabelWorksheetParser.keAngka('4,04'), 4.04);
      expect(TabelWorksheetParser.keAngka('22,2'), 22.2);
    });

    test('teks tanpa angka sama sekali dibuang', () {
      // Kalau `pH` atau `Repeat` ikut kebaca jadi angka, seluruh pemetaan
      // kolomnya geser.
      for (final teks in ['pH', 'Repeat', '°C', '', '-']) {
        expect(TabelWorksheetParser.keAngka(teks), isNull, reason: teks);
      }
    });

    test('satuan yang nempel di angka TIDAK bikin selnya kebuang', () {
      // Dulu `4,04pH` ditolak dengan alasan "harus bilangan murni". Di lembar
      // tulisan tangan itu keputusan yang salah: ML Kit rutin nyatuin angka
      // sama satuannya, dan menolaknya bikin hampir semua sel hilang —
      // gejalanya "nggak ada angka yang kebaca" padahal angkanya jelas.
      expect(TabelWorksheetParser.keAngka('4,04pH'), 4.04);
      expect(TabelWorksheetParser.keAngka('22,2°C'), 22.2);
    });
  });
}

/// Kasus nyata dari lapangan: foto SELEMBAR PENUH, bukan tabelnya doang.
///
/// Ini yang bikin scan gagal total di HP — angka kop (`0509`, `285`, `2024`)
/// ikut kebaca, lalu pusat baris & kolom dihitung dari sebaran yang salah.
/// Gejalanya "nggak ada angka yang kebaca" padahal angkanya jelas di foto.
void _regresiFotoSelembarPenuh() {
  group('foto selembar penuh (regresi lapangan)', () {
    test('angka kop dibuang, isi sel tetap kebaca', () {
      final kotak = <KotakAngka>[
        // --- sampah kop & footer, di luar rentang isi sel -----------------
        const KotakAngka(nilai: 509, x: 900, y: 40), // SIDIK-FM-CAL-0509
        const KotakAngka(nilai: 285, x: 700, y: 40), // LK-285-IDN
        const KotakAngka(nilai: 2024, x: 300, y: 80), // tahun
        // --- isi tabel: 1 baris, 3 buffer x (pH, suhu) --------------------
        const KotakAngka(nilai: 4.04, x: 100, y: 500),
        const KotakAngka(nilai: 22.2, x: 200, y: 500),
        const KotakAngka(nilai: 7.02, x: 300, y: 500),
        const KotakAngka(nilai: 22.3, x: 400, y: 500),
        const KotakAngka(nilai: 9.61, x: 500, y: 500),
        const KotakAngka(nilai: 22.2, x: 600, y: 500),
      ];

      final hasil = TabelWorksheetParser.susun(
        kotak,
        teksMentah: 'contoh',
        jumlahBaris: 1,
      );

      expect(hasil, isNotNull);
      expect(hasil!.baris.first.ph, [4.04, 7.02, 9.61]);
      expect(hasil.baris.first.suhu, [22.2, 22.3, 22.2]);
    });

    test('saringan cuma buang yang MUSTAHIL, bukan yang keliatan aneh', () {
      // 9.61 di kolom buffer 10 itu pembacaan menyimpang — justru temuan
      // alat rusak. Jangan sampai kesaring.
      final kotak = [
        const KotakAngka(nilai: 9.61, x: 500, y: 500),
        const KotakAngka(nilai: 509, x: 900, y: 40),
      ];

      final lolos = TabelWorksheetParser.saringKandidat(kotak);

      expect(lolos.map((k) => k.nilai), [9.61]);
    });
  });

  group('angka bertepi sampah (tulisan tangan)', () {
    test('tanda baca nempel di ujung nggak bikin sel kebuang', () {
      // ML Kit sering nempelin ini di lembar tulisan tangan.
      expect(TabelWorksheetParser.keAngka('4,04.'), 4.04);
      expect(TabelWorksheetParser.keAngka('|7,02'), 7.02);
      expect(TabelWorksheetParser.keAngka('(22,2)'), 22.2);
      expect(TabelWorksheetParser.keAngka('9,61°'), 9.61);
    });

    test('kebacaan ngaco tetap ditolak, bukan ditebak', () {
      expect(TabelWorksheetParser.keAngka('4.0.4'), isNull);
      expect(TabelWorksheetParser.keAngka('pH'), isNull);
      expect(TabelWorksheetParser.keAngka(''), isNull);
    });
  });
}

/// Foto yang gagal **tidak boleh jadi jalan buntu**.
///
/// Teknisi udah berdiri di depan alat pelanggan waktu ini kejadian. Yang dia
/// butuh: tahu apa yang salah, dan tetap bisa maju.
void _pesanTidakBuntu() {
  String pesan({required int terisi, required int terdeteksi}) =>
      pesanHasilFotoTabel(
        terisi: terisi,
        diharapkan: 30,
        terdeteksi: terdeteksi,
        takTerbaca: 'GELAP. tetap bisa diketik manual.',
        posisiKacau: (n) => '$n angka kebaca tapi miring. tetap bisa diketik manual.',
        berhasil: (a, b) => '$a dari $b sel keisi.',
        sisa: 'sisanya ketik manual.',
      );

  group('pesan hasil foto', () {
    test('nol angka terdeteksi → masalahnya FOTO (gelap/buram)', () {
      expect(pesan(terisi: 0, terdeteksi: 0), contains('GELAP'));
    });

    test('angka kebaca tapi sel nol → masalahnya POSISI, bukan foto gelap', () {
      // Dua sebab ini beda obatnya. Kalau disamain, teknisi disuruh nyalain
      // lampu padahal masalahnya fotonya miring.
      final p = pesan(terisi: 0, terdeteksi: 18);

      expect(p, contains('18'));
      expect(p, contains('miring'));
      expect(p, isNot(contains('GELAP')));
    });

    test('sebagian keisi → dikasih tahu sisanya, bukan dianggap gagal', () {
      final p = pesan(terisi: 12, terdeteksi: 20);

      expect(p, contains('12 dari 30'));
      expect(p, contains('sisanya ketik manual'));
    });

    test('penuh → nggak usah disuruh ngetik lagi', () {
      final p = pesan(terisi: 30, terdeteksi: 30);

      expect(p, contains('30 dari 30'));
      expect(p, isNot(contains('sisanya')));
    });

    test('SEMUA cabang gagal nawarin jalan maju', () {
      // Ini jaminannya: apa pun kondisinya, teknisi nggak pernah mentok.
      for (final p in [
        pesan(terisi: 0, terdeteksi: 0),
        pesan(terisi: 0, terdeteksi: 18),
        pesan(terisi: 12, terdeteksi: 20),
      ]) {
        expect(p, contains('ketik manual'), reason: p);
      }
    });
  });
}

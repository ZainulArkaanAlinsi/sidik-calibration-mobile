import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart'
    show TeksTerbaca;

/// Pembaca identitas dari teks seluruh halaman, dengan TEKS SINTETIS: tidak ada
/// foto asli lab di repo. Letak label meniru formulir kosong SIDIK-FM-CAL
/// (koordinat dalam point halaman A4 lanskap 792 x 612, dikali [_skala] seperti
/// foto), nilainya karangan.
const _skala = 4.0;

/// Satu elemen teks (satu kata) di (x0, y0)-(x1, y1) point.
TeksTerbaca _e(
  double x0,
  double y0,
  double x1,
  double y1,
  String teks, {
  double? yakin,
}) => (
  teks: teks,
  kotak: Rect.fromLTRB(x0 * _skala, y0 * _skala, x1 * _skala, y1 * _skala),
  keyakinan: yakin,
);

/// Baris berlabel pH 0509: label di x=27..118, nilai mulai x=125.
List<TeksTerbaca> _labelPh({
  String? nama,
  String? model,
  String? seri,
  String? merk,
  String? pemilik,
  List<String> alamat = const [],
  String? terima,
  String? kalibrasi,
  bool cetakanTh = true,
}) {
  final hasil = <TeksTerbaca>[
    _e(44, 96, 63, 108, 'PT.'),
    _e(66, 96, 98, 108, 'SIDIK'),
    _e(300, 96, 363, 108, 'Calibration'),
    _e(261, 125, 291, 132, 'Received'),
    _e(293, 125, 308, 132, 'Date'),
    _e(312, 123, 315, 132, ':'),
    _e(255, 137, 291, 144, 'Calibration'),
    _e(293, 137, 308, 144, 'Date'),
    _e(312, 135, 315, 144, ':'),
    _e(69, 157, 121, 165, 'EQUIPMENT'),
    _e(123, 157, 163, 165, 'IDENTITY'),
    _e(165, 157, 184, 165, 'AND'),
    _e(186, 157, 235, 165, 'CUSTOMER'),
    _e(238, 157, 262, 165, 'DATA'),
    // 1. Name
    _e(27, 184, 32, 191, '1.'),
    _e(38, 184, 57, 191, 'Name'),
    _e(115, 184, 118, 191, ':'),
    // 2. Range/Resolution + satuan cetak
    _e(27, 197, 32, 204, '2.'),
    _e(38, 197, 96, 204, 'Range/Resolution'),
    _e(115, 197, 118, 204, ':'),
    _e(185, 197, 194, 204, 'pH'),
    _e(185, 208, 194, 215, 'pH'),
    // 3. Type/Model
    _e(27, 219, 32, 226, '3.'),
    _e(38, 219, 76, 226, 'Type/Model'),
    _e(115, 218, 118, 225, ':'),
    // 4. Serial Number/LPI
    _e(27, 230, 32, 237, '4.'),
    _e(38, 230, 57, 237, 'Serial'),
    _e(58, 230, 97, 237, 'Number/LPI'),
    _e(115, 229, 118, 236, ':'),
    // 5. Merk/Manufacture
    _e(27, 241, 32, 248, '5.'),
    _e(38, 241, 97, 248, 'Merk/Manufacture'),
    _e(115, 240, 118, 247, ':'),
    // OWNER
    _e(27, 268, 60, 275, 'OWNER'),
    _e(27, 281, 32, 288, '1.'),
    _e(38, 281, 57, 288, 'Name'),
    _e(115, 281, 118, 288, ':'),
    _e(27, 292, 32, 299, '2.'),
    _e(38, 292, 75, 299, 'Address'),
    _e(115, 292, 118, 299, ':'),
  ];

  if (cetakanTh) {
    hasil.addAll([
      _e(38, 255, 100, 262, 'Thermohygro'),
      _e(150, 255, 175, 262, 'Insitu:'),
      _e(180, 255, 195, 262, 'TH-6'),
      _e(150, 268, 175, 275, 'Inlab:'),
      _e(240, 281, 255, 288, 'TH-2'),
      _e(260, 281, 275, 288, 'TH-7'),
      _e(150, 303, 165, 310, 'TH-4'),
    ]);
  }

  // Tulisan tangan.
  void tulis(double y, String? teks, {double x = 125}) {
    if (teks == null) return;
    var kiri = x;
    for (final kata in teks.split(' ')) {
      final lebar = 6.0 * kata.length + 2;
      hasil.add(_e(kiri, y, kiri + lebar, y + 8, kata));
      kiri += lebar + 4;
    }
  }

  tulis(183, nama);
  tulis(218, model);
  tulis(229, seri);
  tulis(240, merk);
  tulis(280, pemilik);
  for (var i = 0; i < alamat.length; i++) {
    tulis(291 + i * 11, alamat[i]);
  }
  tulis(123, terima, x: 330);
  tulis(135, kalibrasi, x: 330);

  return hasil;
}

void main() {
  final hariIni = DateTime(2026, 11, 19);

  group('formulir kosong: tidak ada yang dikarang', () {
    test(
      'label dan cetakan saja (TH-n, satuan, Insitu/Inlab) = semua kosong',
      () {
        final id = bacaIdentitasKertas(_labelPh(), sekarang: hariIni);

        expect(id.adaIsi, isFalse, reason: '$id');
        expect(id.namaAlat, isNull);
        expect(id.model, isNull);
        expect(id.seri, isNull);
        expect(id.merk, isNull);
        expect(id.pemilik, isNull);
        expect(id.alamat, isNull);
      },
    );

    test(
      'halaman tanpa teks atau terlalu sedikit teks = kosong, tidak melempar',
      () {
        expect(bacaIdentitasKertas(const []).adaIsi, isFalse);
        expect(bacaIdentitasKertas([_e(0, 0, 10, 10, 'Halo')]).adaIsi, isFalse);
      },
    );
  });

  group('pH 0509: tulisan teknisi di kanan label cetak', () {
    final penuh = _labelPh(
      nama: 'pH Meter',
      model: 'Five Easy',
      seri: 'B628755900',
      merk: 'Mettler Toledo',
      pemilik: 'PT Tirta Contoh',
      alamat: ['Jl. Contoh Primer A-10', 'Kec. Cicalengka Bandung'],
      terima: '12/11/2026',
      kalibrasi: '13 Nov 2026',
    );

    test('semua bidang identitas terbaca persis', () {
      final id = bacaIdentitasKertas(penuh, sekarang: hariIni);

      expect(id.namaAlat, 'pH Meter');
      expect(id.model, 'Five Easy');
      expect(id.seri, 'B628755900');
      expect(id.merk, 'Mettler Toledo');
      expect(id.pemilik, 'PT Tirta Contoh');
      expect(id.alamat, 'Jl. Contoh Primer A-10 Kec. Cicalengka Bandung');
      expect(id.tanggalTerima, DateTime(2026, 11, 12));
      expect(id.tanggalKalibrasi, DateTime(2026, 11, 13));
    });

    test(
      '"1. Name" kedua (di bawah judul OWNER) = pemilik, bukan nama alat',
      () {
        final id = bacaIdentitasKertas(
          _labelPh(nama: 'pH Meter', pemilik: 'CV Sentosa'),
          sekarang: hariIni,
        );

        expect(id.namaAlat, 'pH Meter');
        expect(id.pemilik, 'CV Sentosa');
      },
    );

    test('hanya satu bidang terisi: yang lain tetap kosong', () {
      final id = bacaIdentitasKertas(
        _labelPh(seri: 'SN-4471'),
        sekarang: hariIni,
      );

      expect(id.seri, 'SN-4471');
      expect(id.namaAlat, isNull);
      expect(id.merk, isNull);
      expect(id.pemilik, isNull);
      expect(id.alamat, isNull);
    });

    test('satuan cetak di dalam nama ("pH Meter") tidak dibuang', () {
      final id = bacaIdentitasKertas(
        _labelPh(nama: 'pH Meter'),
        sekarang: hariIni,
      );

      expect(id.namaAlat, 'pH Meter');
    });

    test(
      'nilai serial dengan spasi dipertahankan apa adanya; kunci merapikan',
      () {
        final id = bacaIdentitasKertas(
          _labelPh(seri: 'B 628 755 900'),
          sekarang: hariIni,
        );

        expect(id.seri, 'B 628 755 900');
        expect(kunciSeri(id.seri!), 'B628755900');
      },
    );

    test('seri tanpa satu angka pun tidak diterima (bukan nomor seri)', () {
      final id = bacaIdentitasKertas(
        _labelPh(seri: 'Mettler'),
        sekarang: hariIni,
      );

      expect(id.seri, isNull);
    });

    test('keyakinan pengenal rendah (< 0,35) = bidang dikosongkan', () {
      final lembar = _labelPh(seri: 'B628755900', merk: 'Mettler');
      final lemah = [
        for (final t in lembar)
          if (t.teks == 'Mettler')
            (teks: t.teks, kotak: t.kotak, keyakinan: 0.2)
          else if (t.teks == 'B628755900')
            (teks: t.teks, kotak: t.kotak, keyakinan: 0.9)
          else
            t,
      ];

      final id = bacaIdentitasKertas(lemah, sekarang: hariIni);

      expect(id.merk, isNull, reason: 'tidak yakin = kosong');
      expect(id.seri, 'B628755900');
    });

    test('tanggal masa depan jauh (salah baca tahun) dikosongkan', () {
      final id = bacaIdentitasKertas(
        _labelPh(kalibrasi: '13/11/2029'),
        sekarang: hariIni,
      );

      expect(id.tanggalKalibrasi, isNull);
    });
  });

  group('formulir berlabel Indonesia (dua kolom, tanpa nomor)', () {
    // Thermocouple 0535: kolom kiri Nama Alat / Merk / Type / No. Seri / Nama
    // Cust. / Alamat Cust.; kolom kanan Rentang Ukur / Tgl. Diterima / Tgl.
    // Kalibrasi.
    List<TeksTerbaca> thermocouple() => [
      _e(80, 60, 200, 70, 'Identitas'),
      _e(204, 60, 230, 70, 'Alat'),
      _e(234, 60, 250, 70, 'dan'),
      _e(254, 60, 275, 70, 'Data'),
      _e(279, 60, 320, 70, 'Customer'),
      _e(20, 80, 38, 88, 'Nama'),
      _e(40, 80, 56, 88, 'Alat'),
      _e(90, 80, 93, 88, ':'),
      _e(110, 79, 150, 89, 'Termokopel', yakin: 0.8),
      _e(300, 80, 330, 88, 'Rentang'),
      _e(332, 80, 350, 88, 'Ukur'),
      _e(380, 80, 383, 88, ':'),
      _e(420, 80, 435, 88, 'Tgl.'),
      _e(437, 80, 470, 88, 'Diterima'),
      _e(474, 80, 477, 88, ':'),
      _e(485, 79, 540, 89, '12-11-26'),
      _e(20, 92, 36, 100, 'Merk'),
      _e(90, 92, 93, 100, ':'),
      _e(110, 91, 140, 101, 'Fluke'),
      _e(20, 104, 36, 112, 'Type'),
      _e(90, 104, 93, 112, ':'),
      _e(110, 103, 130, 113, '52II'),
      _e(300, 104, 340, 112, 'Kapasitas'),
      _e(342, 104, 360, 112, 'Alat'),
      _e(380, 104, 383, 112, ':'),
      _e(420, 104, 435, 112, 'Tgl.'),
      _e(437, 104, 480, 112, 'Kalibrasi'),
      _e(484, 104, 487, 112, ':'),
      _e(495, 103, 560, 113, '13.11.2026'),
      _e(20, 116, 30, 124, 'No.'),
      _e(32, 116, 45, 124, 'Seri'),
      _e(90, 116, 93, 124, ':'),
      _e(110, 115, 170, 125, 'FK-20193847'),
      _e(20, 140, 38, 148, 'Nama'),
      _e(40, 140, 62, 148, 'Cust.'),
      _e(90, 140, 93, 148, ':'),
      _e(110, 139, 130, 149, 'CV'),
      _e(134, 139, 160, 149, 'Maju'),
      _e(300, 140, 335, 148, 'Lokasi'),
      _e(337, 140, 372, 148, 'Kalibrasi'),
      _e(376, 140, 379, 148, ':'),
      _e(385, 139, 410, 149, 'Inlab'),
      _e(20, 152, 38, 160, 'Alamat'),
      _e(40, 152, 62, 160, 'Cust.'),
      _e(90, 152, 93, 160, ':'),
      _e(110, 151, 140, 161, 'Jl.'),
      _e(144, 151, 190, 161, 'Merdeka'),
      _e(194, 151, 210, 161, '12'),
    ];

    test('label Indonesia, titik dua terpisah, dua kolom: semua terbaca', () {
      final id = bacaIdentitasKertas(thermocouple(), sekarang: hariIni);

      expect(id.namaAlat, 'Termokopel');
      expect(id.merk, 'Fluke');
      expect(id.model, '52II');
      expect(id.seri, 'FK-20193847');
      expect(id.pemilik, 'CV Maju');
      expect(id.alamat, 'Jl. Merdeka 12');
      expect(id.lokasi, 'Inlab');
      expect(id.tanggalTerima, DateTime(2026, 11, 12));
      expect(id.tanggalKalibrasi, DateTime(2026, 11, 13));
    });

    test(
      'nilai tidak menelan label kolom sebelah (berhenti di "Rentang Ukur")',
      () {
        final kosongNama = [
          for (final t in thermocouple())
            if (t.teks != 'Termokopel') t,
        ];
        final id = bacaIdentitasKertas(kosongNama, sekarang: hariIni);

        expect(id.namaAlat, isNull, reason: '$id');
      },
    );
  });

  group('bentuk label lain', () {
    test('"Owner :" dengan nilai di baris yang sama (Micrometer)', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 40, 48, 'Owner'),
        _e(80, 40, 83, 48, ':'),
        _e(90, 39, 120, 49, 'PT'),
        _e(124, 39, 170, 49, 'Sinar'),
        _e(10, 52, 40, 60, 'Address'),
        _e(80, 52, 83, 60, ':'),
        _e(90, 51, 130, 61, 'Cikarang'),
        _e(10, 64, 60, 72, 'Serial'),
        _e(62, 64, 90, 72, 'Number'),
        _e(80, 64, 83, 72, ':'),
        _e(90, 63, 130, 73, 'MC-7731'),
      ], sekarang: hariIni);

      expect(id.pemilik, 'PT Sinar');
      expect(id.alamat, 'Cikarang');
      expect(id.seri, 'MC-7731');
    });

    test('titik dua menempel pada label atau nilai ("Name:", ":Mettler")', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 40, 48, 'Merk:'),
        _e(50, 39, 100, 49, 'Mettler'),
        _e(10, 52, 60, 60, 'Serial'),
        _e(62, 52, 90, 60, 'Number'),
        _e(92, 52, 150, 60, ':B628755900'),
        _e(10, 64, 20, 72, 'x'),
      ], sekarang: hariIni);

      expect(id.merk, 'Mettler');
      expect(id.seri, 'B628755900');
    });

    test('label dan nilai satu elemen ("Merk:Mettler") dipecah', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 90, 48, 'Merk:Mettler'),
        _e(10, 52, 90, 60, 'Serial:SN-8812'),
        _e(10, 64, 20, 72, 'x'),
      ], sekarang: hariIni);

      expect(id.merk, 'Mettler');
      expect(id.seri, 'SN-8812');
    });

    test('"Name" dua kali tanpa judul OWNER: pertama alat, kedua pemilik', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 40, 48, 'Name'),
        _e(60, 40, 63, 48, ':'),
        _e(70, 39, 110, 49, 'Neraca'),
        _e(10, 80, 40, 88, 'Name'),
        _e(60, 80, 63, 88, ':'),
        _e(70, 79, 110, 89, 'PT'),
        _e(114, 79, 150, 89, 'Aman'),
      ], sekarang: hariIni);

      expect(id.namaAlat, 'Neraca');
      expect(id.pemilik, 'PT Aman');
    });

    test('nilai yang terlalu jauh dari label (kolom lain) tidak diambil', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 40, 48, 'Merk'),
        _e(50, 40, 53, 48, ':'),
        _e(900, 39, 940, 49, 'Teks'),
        _e(10, 60, 40, 68, 'x'),
        _e(10, 80, 40, 88, 'y'),
      ], sekarang: hariIni);

      expect(id.merk, isNull);
    });

    test('ID alat dan "No. ID"', () {
      final id = bacaIdentitasKertas([
        _e(10, 40, 20, 48, 'No.'),
        _e(22, 40, 36, 48, 'ID'),
        _e(60, 40, 63, 48, ':'),
        _e(70, 39, 130, 49, 'PH-007'),
        _e(10, 60, 40, 68, 'x'),
        _e(10, 80, 40, 88, 'y'),
      ], sekarang: hariIni);

      expect(id.idAlat, 'PH-007');
    });
  });

  group('parseTanggalKertas', () {
    final kini = DateTime(2026, 11, 19);

    test('pemisah garis miring, strip, titik; tahun dua atau empat digit', () {
      expect(
        parseTanggalKertas('12/11/2026', sekarang: kini),
        DateTime(2026, 11, 12),
      );
      expect(
        parseTanggalKertas('12-11-26', sekarang: kini),
        DateTime(2026, 11, 12),
      );
      expect(
        parseTanggalKertas('05.01.2026', sekarang: kini),
        DateTime(2026, 1, 5),
      );
      expect(
        parseTanggalKertas('5 / 1 / 26', sekarang: kini),
        DateTime(2026, 1, 5),
      );
    });

    test('bulan bernama Indonesia dan Inggris, singkat atau penuh', () {
      expect(
        parseTanggalKertas('12 Nov 2026', sekarang: kini),
        DateTime(2026, 11, 12),
      );
      expect(
        parseTanggalKertas('12 November 2026', sekarang: kini),
        DateTime(2026, 11, 12),
      );
      expect(
        parseTanggalKertas('3-Agt-26', sekarang: kini),
        DateTime(2026, 8, 3),
      );
      expect(
        parseTanggalKertas('3 Agustus 2026', sekarang: kini),
        DateTime(2026, 8, 3),
      );
      expect(
        parseTanggalKertas('15 Des 2025', sekarang: kini),
        DateTime(2025, 12, 15),
      );
      expect(
        parseTanggalKertas('1 Oct 2026', sekarang: kini),
        DateTime(2026, 10, 1),
      );
      expect(
        parseTanggalKertas('9 Mei 2026', sekarang: kini),
        DateTime(2026, 5, 9),
      );
    });

    test('salah baca O jadi 0 dan l jadi 1 di angka dipulihkan', () {
      expect(
        parseTanggalKertas('l2/1l/2O26', sekarang: kini),
        DateTime(2026, 11, 12),
      );
    });

    test('tidak sah = null: 31 Februari, bulan 13, hari 0, tahun 1999', () {
      expect(parseTanggalKertas('31/02/2026', sekarang: kini), isNull);
      expect(parseTanggalKertas('12/13/2026', sekarang: kini), isNull);
      expect(parseTanggalKertas('0/11/2026', sekarang: kini), isNull);
      expect(parseTanggalKertas('12/11/1999', sekarang: kini), isNull);
    });

    test('bukan tanggal = null: teks lain, kosong, bulan tak dikenal', () {
      expect(parseTanggalKertas('', sekarang: kini), isNull);
      expect(parseTanggalKertas('abc', sekarang: kini), isNull);
      expect(parseTanggalKertas('12 Xyz 2026', sekarang: kini), isNull);
      expect(parseTanggalKertas('2026', sekarang: kini), isNull);
    });

    test(
      'masa depan: lebih dari 2 hari sesudah hari ini = null; 2 hari boleh',
      () {
        expect(
          parseTanggalKertas('21/11/2026', sekarang: kini),
          DateTime(2026, 11, 21),
        );
        expect(parseTanggalKertas('22/11/2026', sekarang: kini), isNull);
        // Tanpa patokan hari ini: tidak ada batas masa depan.
        expect(parseTanggalKertas('22/11/2026'), DateTime(2026, 11, 22));
      },
    );
  });

  group('kunci dan kemiripan nomor seri', () {
    test('kunciSeri: huruf besar, hanya huruf dan angka', () {
      expect(kunciSeri('mt-500 196/30'), 'MT50019630');
      expect(kunciSeri(' b628755900 '), 'B628755900');
    });

    test('kunciSeriLonggar: O jadi 0 dan I jadi 1, hanya untuk pencocokan', () {
      expect(
        kunciSeriLonggar('BO28-755I00'),
        'B0287551'
        '00',
      );
      expect(
        kunciSeri('BO28-755I00'),
        'BO28755I00',
        reason: 'kunci persis tidak melipat huruf',
      );
    });

    test('jarakEdit', () {
      expect(jarakEdit('ABC', 'ABC'), 0);
      expect(jarakEdit('ABC', 'ABD'), 1);
      expect(jarakEdit('ABC', 'AC'), 1);
      expect(jarakEdit('', 'AB'), 2);
      expect(jarakEdit('KITTEN', 'SITTING'), 3);
    });

    test('seriMirip: O/0 dan satu-dua karakter beda pada seri panjang', () {
      expect(seriMirip('B628755900', 'B628755900'), isTrue);
      expect(seriMirip('B628755900', 'B6287559O0'), isTrue, reason: 'O jadi 0');
      expect(seriMirip('B628755900', 'B628755800'), isTrue, reason: '1 beda');
      expect(seriMirip('B628755900', 'B628755800X'), isTrue, reason: '2 beda');
      expect(seriMirip('B628755900', 'B628700000'), isFalse, reason: '3 beda');
    });

    test('seri pendek lebih ketat; seri 3 karakter tidak pernah mirip', () {
      expect(seriMirip('A1234', 'A1235'), isTrue);
      expect(seriMirip('A1234', 'A1255'), isFalse, reason: '2 beda di 5 huruf');
      expect(seriMirip('AB1', 'AB2'), isFalse);
    });
  });
}

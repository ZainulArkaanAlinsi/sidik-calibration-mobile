import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/identitas_kertas.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart'
    show TeksTerbaca;

import 'support/halaman_identitas_uji.dart';

/// Pembaca identitas dari teks seluruh halaman, dengan TEKS SINTETIS: tidak ada
/// foto asli lab di repo. Letak label meniru formulir kosong SIDIK-FM-CAL
/// (koordinat dalam point halaman A4 lanskap 792 x 612, dikali [_skala] seperti
/// foto), nilainya karangan.
void main() {
  final hariIni = DateTime(2026, 11, 19);

  group('formulir kosong: tidak ada yang dikarang', () {
    test(
      'label dan cetakan saja (TH-n, satuan, Insitu/Inlab) = semua kosong',
      () {
        final id = bacaIdentitasKertas(halamanLabelPh(), sekarang: hariIni);

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
        expect(bacaIdentitasKertas([el(0, 0, 10, 10, 'Halo')]).adaIsi, isFalse);
      },
    );
  });

  group('pH 0509: tulisan teknisi di kanan label cetak', () {
    final penuh = halamanLabelPh(
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
          halamanLabelPh(nama: 'pH Meter', pemilik: 'CV Sentosa'),
          sekarang: hariIni,
        );

        expect(id.namaAlat, 'pH Meter');
        expect(id.pemilik, 'CV Sentosa');
      },
    );

    test('hanya satu bidang terisi: yang lain tetap kosong', () {
      final id = bacaIdentitasKertas(
        halamanLabelPh(seri: 'SN-4471'),
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
        halamanLabelPh(nama: 'pH Meter'),
        sekarang: hariIni,
      );

      expect(id.namaAlat, 'pH Meter');
    });

    test(
      'nilai serial dengan spasi dipertahankan apa adanya; kunci merapikan',
      () {
        final id = bacaIdentitasKertas(
          halamanLabelPh(seri: 'B 628 755 900'),
          sekarang: hariIni,
        );

        expect(id.seri, 'B 628 755 900');
        expect(kunciSeri(id.seri!), 'B628755900');
      },
    );

    test('seri tanpa satu angka pun tidak diterima (bukan nomor seri)', () {
      final id = bacaIdentitasKertas(
        halamanLabelPh(seri: 'Mettler'),
        sekarang: hariIni,
      );

      expect(id.seri, isNull);
    });

    test('keyakinan pengenal rendah (< 0,35) = bidang dikosongkan', () {
      final lembar = halamanLabelPh(seri: 'B628755900', merk: 'Mettler');
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
        halamanLabelPh(kalibrasi: '13/11/2029'),
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
      el(80, 60, 200, 70, 'Identitas'),
      el(204, 60, 230, 70, 'Alat'),
      el(234, 60, 250, 70, 'dan'),
      el(254, 60, 275, 70, 'Data'),
      el(279, 60, 320, 70, 'Customer'),
      el(20, 80, 38, 88, 'Nama'),
      el(40, 80, 56, 88, 'Alat'),
      el(90, 80, 93, 88, ':'),
      el(110, 79, 150, 89, 'Termokopel', yakin: 0.8),
      el(300, 80, 330, 88, 'Rentang'),
      el(332, 80, 350, 88, 'Ukur'),
      el(380, 80, 383, 88, ':'),
      el(420, 80, 435, 88, 'Tgl.'),
      el(437, 80, 470, 88, 'Diterima'),
      el(474, 80, 477, 88, ':'),
      el(485, 79, 540, 89, '12-11-26'),
      el(20, 92, 36, 100, 'Merk'),
      el(90, 92, 93, 100, ':'),
      el(110, 91, 140, 101, 'Fluke'),
      el(20, 104, 36, 112, 'Type'),
      el(90, 104, 93, 112, ':'),
      el(110, 103, 130, 113, '52II'),
      el(300, 104, 340, 112, 'Kapasitas'),
      el(342, 104, 360, 112, 'Alat'),
      el(380, 104, 383, 112, ':'),
      el(420, 104, 435, 112, 'Tgl.'),
      el(437, 104, 480, 112, 'Kalibrasi'),
      el(484, 104, 487, 112, ':'),
      el(495, 103, 560, 113, '13.11.2026'),
      el(20, 116, 30, 124, 'No.'),
      el(32, 116, 45, 124, 'Seri'),
      el(90, 116, 93, 124, ':'),
      el(110, 115, 170, 125, 'FK-20193847'),
      el(20, 140, 38, 148, 'Nama'),
      el(40, 140, 62, 148, 'Cust.'),
      el(90, 140, 93, 148, ':'),
      el(110, 139, 130, 149, 'CV'),
      el(134, 139, 160, 149, 'Maju'),
      el(300, 140, 335, 148, 'Lokasi'),
      el(337, 140, 372, 148, 'Kalibrasi'),
      el(376, 140, 379, 148, ':'),
      el(385, 139, 410, 149, 'Inlab'),
      el(20, 152, 38, 160, 'Alamat'),
      el(40, 152, 62, 160, 'Cust.'),
      el(90, 152, 93, 160, ':'),
      el(110, 151, 140, 161, 'Jl.'),
      el(144, 151, 190, 161, 'Merdeka'),
      el(194, 151, 210, 161, '12'),
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
        el(10, 40, 40, 48, 'Owner'),
        el(80, 40, 83, 48, ':'),
        el(90, 39, 120, 49, 'PT'),
        el(124, 39, 170, 49, 'Sinar'),
        el(10, 52, 40, 60, 'Address'),
        el(80, 52, 83, 60, ':'),
        el(90, 51, 130, 61, 'Cikarang'),
        el(10, 64, 60, 72, 'Serial'),
        el(62, 64, 90, 72, 'Number'),
        el(80, 64, 83, 72, ':'),
        el(90, 63, 130, 73, 'MC-7731'),
      ], sekarang: hariIni);

      expect(id.pemilik, 'PT Sinar');
      expect(id.alamat, 'Cikarang');
      expect(id.seri, 'MC-7731');
    });

    test('titik dua menempel pada label atau nilai ("Name:", ":Mettler")', () {
      final id = bacaIdentitasKertas([
        el(10, 40, 40, 48, 'Merk:'),
        el(50, 39, 100, 49, 'Mettler'),
        el(10, 52, 60, 60, 'Serial'),
        el(62, 52, 90, 60, 'Number'),
        el(92, 52, 150, 60, ':B628755900'),
        el(10, 64, 20, 72, 'x'),
      ], sekarang: hariIni);

      expect(id.merk, 'Mettler');
      expect(id.seri, 'B628755900');
    });

    test('label dan nilai satu elemen ("Merk:Mettler") dipecah', () {
      final id = bacaIdentitasKertas([
        el(10, 40, 90, 48, 'Merk:Mettler'),
        el(10, 52, 90, 60, 'Serial:SN-8812'),
        el(10, 64, 20, 72, 'x'),
      ], sekarang: hariIni);

      expect(id.merk, 'Mettler');
      expect(id.seri, 'SN-8812');
    });

    test('"Name" dua kali tanpa judul OWNER: pertama alat, kedua pemilik', () {
      final id = bacaIdentitasKertas([
        el(10, 40, 40, 48, 'Name'),
        el(60, 40, 63, 48, ':'),
        el(70, 39, 110, 49, 'Neraca'),
        el(10, 80, 40, 88, 'Name'),
        el(60, 80, 63, 88, ':'),
        el(70, 79, 110, 89, 'PT'),
        el(114, 79, 150, 89, 'Aman'),
      ], sekarang: hariIni);

      expect(id.namaAlat, 'Neraca');
      expect(id.pemilik, 'PT Aman');
    });

    test('nilai yang terlalu jauh dari label (kolom lain) tidak diambil', () {
      final id = bacaIdentitasKertas([
        el(10, 40, 40, 48, 'Merk'),
        el(50, 40, 53, 48, ':'),
        el(900, 39, 940, 49, 'Teks'),
        el(10, 60, 40, 68, 'x'),
        el(10, 80, 40, 88, 'y'),
      ], sekarang: hariIni);

      expect(id.merk, isNull);
    });

    test('ID alat dan "No. ID"', () {
      final id = bacaIdentitasKertas([
        el(10, 40, 20, 48, 'No.'),
        el(22, 40, 36, 48, 'ID'),
        el(60, 40, 63, 48, ':'),
        el(70, 39, 130, 49, 'PH-007'),
        el(10, 60, 40, 68, 'x'),
        el(10, 80, 40, 88, 'y'),
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

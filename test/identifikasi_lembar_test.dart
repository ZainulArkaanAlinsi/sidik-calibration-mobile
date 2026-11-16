import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/identifikasi_lembar.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart'
    show TeksTerbaca;

/// Pengenal lembar BERLAPIS: kode formulir (toleran separator, huruf kembar,
/// potongan), judul (fuzzy), revisi (pemeriksa). Masukannya TEKS: tidak ada
/// ML Kit dan tidak ada foto.
///
/// PRIVASI: repo ini publik. Semua string di sini buatan tangan yang meniru
/// galat OCR pada TEKS CETAK formulir (judul, kode, revisi). Tidak ada nama,
/// alamat, nomor seri, atau angka dari foto nyata. Daftar jenis dan teks
/// formulir bersih memakai `test/assets/jenis-lembar-fixture.json` (hanya
/// label tercetak formulir kosong).
void main() {
  final data =
      jsonDecode(
            File('test/assets/jenis-lembar-fixture.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final fixture = <FormulirDikenal>[
    for (final d in data['dikenal'] as List<dynamic>)
      (
        templateId: (d as Map<String, dynamic>)['template_id'] as String,
        kodeDokumen: d['kode_dokumen'] as String,
        judul: d['judul'] as String,
      ),
  ];
  final lembar = (data['lembar'] as List<dynamic>).cast<Map<String, dynamic>>();

  // Fixture lama tidak memuat 0508 (Timbangan). Ditambah di sini supaya umpan
  // "SIDIK-IK-CAL-0508" diuji terhadap kode yang MEMANG dikenal.
  final dikenal = <FormulirDikenal>[
    ...fixture,
    (
      templateId: 'timbangan',
      kodeDokumen: 'SIDIK-FM-CAL-0508_Rev.6',
      judul: 'Calibration Worksheet - Timbangan',
    ),
  ];

  HasilJenisLembar? kenali(String teks) =>
      identifikasiLembar(teks, dikenal: dikenal);

  HasilJenisLembar ada(String teks) {
    final h = kenali(teks);
    expect(h, isNotNull, reason: teks);

    return h!;
  }

  Set<String> idKandidat(HasilJenisLembar h) => {
    for (final k in h.peringkat) k.formulir.templateId,
  };

  const kakiSpektro = 'Page 1 of 1 Revise : 5 SIDIK-FM-CAL-0511';
  const judulSpektro =
      'PT. SIDIK Calibration Worksheet - UV/VIS Spectrophotometer LK-285-IDN';

  group('lapis kode: separator', () {
    for (final teks in [
      'Page 1 of 1 Revise : 5 SIDIK.FM-CAL.0511',
      'Revise : 5 SIDIK_FM_CAL_0511',
      'Revise : 5 SIDIK FM CAL 0511',
      'Revise : 5 SIDIK - FM - CAL - 0511',
      'Revise : 5 sidik.fm.cal.0511',
      'Revise : 5 SIDIK-FM-CAL- 0511',
    ]) {
      test('"$teks" dibaca bersih dan dipilih-awal', () {
        final h = ada(teks);

        expect(h.sumber, SumberJenisLembar.kodeFormulir);
        expect(h.alasan, AlasanPetunjuk.praPilihKode);
        expect(h.kodeFormulir, 'SIDIK-FM-CAL-0511');
        expect(h.praPilihTemplateId, 'spectrophotometer');
        expect(h.peringkat.single.skor, closeTo(0.92, 1e-9));
      });
    }

    test(
      'elemen ML Kit yang terpecah (kode dan nomor beda kotak) digabung',
      () {
        TeksTerbaca t(String teks, double x) =>
            (teks: teks, kotak: Rect.fromLTWH(x, 100, 60, 20), keyakinan: null);

        final h = ada(
          teksHalaman([
            t('Revise : 5', 10),
            t('SIDIK-FM-CAL-', 200),
            t('0511', 330),
          ]),
        );

        expect(h.praPilihTemplateId, 'spectrophotometer');
      },
    );
  });

  group('lapis kode: huruf kembar dan potongan', () {
    test(
      '0 terbaca O: kode samar tetapi unik -> dipilih-awal, ditandai samar',
      () {
        final h = ada('Revise : 5 SIDIK-FM-CAL-O511');

        expect(h.sumber, SumberJenisLembar.kodeSamar);
        expect(h.alasan, AlasanPetunjuk.praPilihKodeSamar);
        expect(h.praPilihTemplateId, 'spectrophotometer');

        final bukti = h.peringkat.single.bukti.firstWhere(
          (b) => b.lapis == LapisBukti.kode,
        );
        expect(bukti.mutu, MutuBukti.samar);
        expect(bukti.cocok, 'SIDIK-FM-CAL-0511');
        expect(bukti.terbaca, contains('O511'));
        expect(bukti.biaya, closeTo(0.3, 1e-9));
      },
    );

    test('5 terbaca S, 1 terbaca l atau I', () {
      for (final teks in [
        'SIDIK-FM-CAL-0S11',
        'SIDIK-FM-CAL-05l1',
        'SIDIK-FM-CAL-05I1',
        'SIDIK-FM-CAL-051|',
      ]) {
        final h = ada('Revise : 5 $teks');

        expect(h.praPilihTemplateId, 'spectrophotometer', reason: teks);
        expect(h.sumber, SumberJenisLembar.kodeSamar, reason: teks);
      }
    });

    test('0 terbaca O di ujung (0530) dan 8 terbaca B (0538.A)', () {
      final h = ada('Revise : 2 SIDIK-FM-CAL-053O');
      expect(h.praPilihTemplateId, 'turbidimeter');
      expect(
        ada('Rev : 3 SIDIK-FM-CAL-053B.A').praPilihTemplateId,
        'flowmeter_flowrate',
      );

      // 0509: dua huruf kembar sekaligus.
      final o = ada('Revise : 4 SIDIK-FM-CAL-O5O9');
      expect(o.praPilihTemplateId, 'ph_meter');
      expect(o.sumber, SumberJenisLembar.kodeSamar);
    });

    test(
      'terlalu banyak huruf kembar = lemah: usulan teratas, TANPA pilih-awal',
      () {
        final h = ada('SIDIK-FM-CAL-OSII');

        expect(h.alasan, AlasanPetunjuk.lemah);
        expect(h.praPilihTemplateId, isNull);
        expect(idKandidat(h), {'spectrophotometer'});
        expect(h.peringkat.single.skor, lessThan(0.70));
      },
    );

    test('awalan SIDIK terpotong tepi bingkai tetap terbaca', () {
      for (final teks in [
        'Revise : 5 IDIK-FM-CAL-0511',
        'Revise : 5 DIK-FM-CAL-0511',
        'Revise : 5 FM-CAL-0511',
      ]) {
        final h = ada(teks);

        expect(h.praPilihTemplateId, 'spectrophotometer', reason: teks);
        expect(h.sumber, SumberJenisLembar.kodeSamar, reason: teks);
      }
    });

    test('"OMI" (0511 yang rusak parah) terlalu kabur untuk berdiri sendiri: '
        'tanpa bukti, TIDAK menebak 0511', () {
      expect(kenali('Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI'), isNull);
    });

    test('varian .A dan .B tetap dibedakan walau samar', () {
      final a = ada('Rev : 3 SIDIK-FM-CAL-O538.A');
      final b = ada('Rev : 3 SIDIK.FM.CAL.0538 . B');

      expect(a.praPilihTemplateId, 'flowmeter_flowrate');
      expect(b.praPilihTemplateId, 'flowmeter_totalizer');
    });
  });

  group('lapis kode: angka tidak ditukar dengan angka lain', () {
    test(
      '0599 (jelas terbaca, tidak ada di daftar) TIDAK didekatkan ke 0509',
      () {
        final h = ada('Revise : 4 SIDIK-FM-CAL-0599');

        expect(h.alasan, AlasanPetunjuk.kodeTakDikenal);
        expect(h.kodeFormulir, 'SIDIK-FM-CAL-0599');
        expect(h.peringkat, isEmpty);
        expect(h.kandidat, isEmpty);
        expect(h.praPilihTemplateId, isNull);
      },
    );

    test('satu angka beda (0512 vs 0511, 0508 vs 0509) bukan kembar OCR', () {
      expect(ada('SIDIK-FM-CAL-0512').alasan, AlasanPetunjuk.kodeTakDikenal);
      expect(ada('SIDIK-FM-CAL-0519').praPilihTemplateId, 'utm');
      expect(ada('SIDIK-FM-CAL-0508').praPilihTemplateId, 'timbangan');
    });

    test(
      'nomor lebih panjang (05091, 050912) BUKAN 0509; deret lain diabaikan',
      () {
        for (final teks in [
          'Revise : 4 SIDIK-FM-CAL-05091',
          'SIDIK-FM-CAL-050912',
          'Revise : 0 SIDIK-FM-CAL-2403',
        ]) {
          expect(kenali(teks), isNull, reason: teks);
        }
      },
    );

    test('potongan nomor yang terlalu pendek ("05") bukan bukti, walau hanya '
        'ada satu kode di daftar', () {
      const satu = <FormulirDikenal>[
        (
          templateId: 'spectrophotometer',
          kodeDokumen: 'SIDIK-FM-CAL-0511_Rev.5',
          judul: 'Calibration Worksheet - UV/VIS Spectrophotometer',
        ),
      ];

      for (final teks in ['Revise : 5 SIDIK-FM-CAL-05', 'SIDIK-FM-CAL-0S']) {
        expect(identifikasiLembar(teks, dikenal: satu), isNull, reason: teks);
      }
    });
  });

  group('umpan: kode IK/IM dan kode metode BUKAN kode formulir', () {
    test(
      'kode metode berawalan IK diabaikan walau nomornya dikenal (0508)',
      () {
        for (final teks in [
          'Calibration Methode : SIDIK-IK-CAL-0508',
          '5. Type/Model : Calibration Metode : SIDIK-IK-CAL-0508_Rev.4',
          'SIDIK-IM-CAL-0508',
          'SIDIKIKCAL0508',
          'SIDIK . IK . CAL . 0508',
        ]) {
          expect(kenali(teks), isNull, reason: teks);
        }
      },
    );

    test(
      'kata "Metode" di depan kode menolak kode itu walau awalan IK salah baca '
      'menjadi FM',
      () {
        expect(kenali('Calibration Methode : SIDIK-FM-CAL-0508'), isNull);
        expect(kenali('Calibration Metode : SIDIK-FM-CAL-0508'), isNull);
      },
    );

    test('umpan di badan lembar tidak mengganggu kode kaki yang benar', () {
      final h = ada(
        '$judulSpektro\n'
        'Std. Value\n'
        '5. Type/Model : Calibration Methode : SIDIK-IK-CAL-0508_Rev.4\n'
        '$kakiSpektro',
      );

      expect(h.praPilihTemplateId, 'spectrophotometer');
      expect(idKandidat(h), {'spectrophotometer'});
      expect(h.kodeFormulir, 'SIDIK-FM-CAL-0511');
    });

    test('umpan IK + kaki yang rusak: bukan 0508, dan kaki rusak tetap '
        'dinilai sendiri', () {
      final h = ada(
        '$judulSpektro\n'
        'Calibration Methode : SIDIK-IK-CAL-0508\n'
        'Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI',
      );

      expect(idKandidat(h), {'spectrophotometer'});
      expect(h.praPilihTemplateId, 'spectrophotometer');
    });
  });

  group('lapis judul', () {
    test(
      'judul bersih saja: usulan, BUKAN pilih-awal (judul bukan pengenal)',
      () {
        final h = ada(judulSpektro);

        expect(h.sumber, SumberJenisLembar.judul);
        expect(h.alasan, AlasanPetunjuk.judulSaja);
        expect(h.praPilihTemplateId, isNull);
        expect(idKandidat(h), {'spectrophotometer'});
        expect(h.peringkat.single.bukti.single.mutu, MutuBukti.tepat);
      },
    );

    test('judul tergores dan pecah dua baris + kode rusak: berlapis sepakat -> '
        'dipilih-awal', () {
      final h = ada(
        'PT. SIDIK Calibration Worksh\n'
        'et - UVIVIS Spectrophotometer LK-285-IDN\n'
        'Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI',
      );

      expect(h.alasan, AlasanPetunjuk.praPilihBerlapis);
      expect(h.praPilihTemplateId, 'spectrophotometer');
      expect(h.sumber, SumberJenisLembar.kodeSamar);

      final bukti = {for (final b in h.peringkat.single.bukti) b.lapis: b};
      expect(bukti[LapisBukti.kode]!.mutu, MutuBukti.samar);
      expect(bukti[LapisBukti.judul]!.mutu, MutuBukti.samar);
      expect(bukti[LapisBukti.revisi]!.mutu, MutuBukti.tepat);
      expect(bukti[LapisBukti.revisi]!.skor, 0, reason: 'revisi bukan bukti');
      expect(h.peringkat.single.skor, greaterThanOrEqualTo(0.70));
    });

    test('judul pecah di tengah kata "Worksheet" tetap dikenali', () {
      final h = ada(
        'PT. SIDIK Calibration Work\n'
        'sheet - pH Meter LK-285-IDN',
      );

      expect(idKandidat(h), {'ph_meter'});
    });

    test(
      'judul dengan huruf kembar (UV/V1S, Spectrophot0meter) tetap dikenali',
      () {
        final h = ada(
          'PT. SIDIK Calibration Worksheet - UV/V1S Spectrophot0meter LK-285-IDN',
        );

        expect(idKandidat(h), {'spectrophotometer'});
      },
    );

    test('judul rusak jauh (lebih dari batas) tidak dipaksa cocok', () {
      expect(
        kenali('PT. SIDIK Calibration Worksheet - UV/VIS Spect LK-285-IDN'),
        isNull,
      );
    });

    test(
      'judul pendek harus persis: "Buret" tidak menang atas "Buret Digital"',
      () {
        final digital = ada(
          'PT. SIDIK Calibration Worksheet - Buret Digital LK-285-IDN',
        );
        expect(idKandidat(digital), {'buret_digital'});

        final biasa = ada('PT. SIDIK Calibration Worksheet - Buret LK-285-IDN');
        expect(idKandidat(biasa), {'buret'});
      },
    );

    test('judul gabungan beberapa alat ("Oven/Furnace/...") bukan bukti', () {
      expect(
        kenali(
          'PT. SIDIK Calibration Work Sheet - Oven/Furnace/Chiller/Water Bath LK-285-IDN',
        ),
        isNull,
      );
    });

    test('semua judul server dikenali sebagai dirinya sendiri, dan hanya '
        'dirinya, juga dengan satu huruf rusak', () {
      for (final d in fixture) {
        final nama = namaPendekJudul(d.judul);
        final bersih = ada(
          'PT. SIDIK Calibration Worksheet - $nama LK-285-IDN',
        );
        expect(idKandidat(bersih), {d.templateId}, reason: d.judul);

        // Satu huruf berganti (hanya bila judulnya cukup panjang untuk
        // memberi toleransi).
        if (nama.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 6) {
          final rusak = '${nama.substring(0, 2)}~${nama.substring(3)}';
          final h = kenali(
            'PT. SIDIK Calibration Worksheet - $rusak LK-285-IDN',
          );
          expect(h, isNotNull, reason: rusak);
          expect(idKandidat(h!), {d.templateId}, reason: rusak);
        }
      }
    });
  });

  group('lapis revisi: pemeriksa, bukan bukti', () {
    test('revisi yang sama tidak menambah skor', () {
      final tanpa = ada('SIDIK-FM-CAL-0511').peringkat.single.skor;
      final dengan = ada('Revise : 5 SIDIK-FM-CAL-0511').peringkat.single.skor;

      expect(dengan, tanpa);
    });

    test(
      'revisi beda dari server mengurangi skor dan dicatat bertentangan',
      () {
        final h = ada('Revise : 3 SIDIK-FM-CAL-0511');
        final k = h.peringkat.single;

        expect(h.revisiTerbaca, '3');
        expect(k.skor, closeTo(0.72, 1e-9));
        final rev = k.bukti.firstWhere((b) => b.lapis == LapisBukti.revisi);
        expect(rev.mutu, MutuBukti.bertentangan);
        expect(rev.cocok, '5');
        // Kode bersih tetap cukup kuat.
        expect(h.praPilihTemplateId, 'spectrophotometer');
      },
    );

    test('revisi beda menahan pilih-awal dari bacaan samar', () {
      final cocok = ada(
        'PT. SIDIK Calibration Worksh\n'
        'et - UVIVIS Spectrophotometer LK-285-IDN\n'
        'Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI',
      );
      final beda = ada(
        'PT. SIDIK Calibration Worksh\n'
        'et - UVIVIS Spectrophotometer LK-285-IDN\n'
        'Page 1 of 1 Revise : 3 SIDIK.FM-CAL.OMI',
      );

      expect(cocok.praPilihTemplateId, 'spectrophotometer');
      expect(beda.praPilihTemplateId, isNull);
      expect(beda.alasan, AlasanPetunjuk.lemah);
      expect(idKandidat(beda), {'spectrophotometer'});
    });

    test(
      'revisi dibaca dari kaki, bukan dari angka lain; ejaan rusak ditoleransi',
      () {
        expect(
          ada(
            'Rev. 0 lain\nPage 1 of 1 Rev: 3 SIDIK-FM-CAL-0523',
          ).revisiTerbaca,
          '3',
        );
        expect(ada('Rev1se : 5 SIDIK-FM-CAL-0511').revisiTerbaca, '5');
      },
    );
  });

  group(
    'dua kandidat dekat: keduanya ditampilkan, tidak ada yang dipilihkan',
    () {
      test(
        'kode terpotong yang sama dekat dengan dua kode (0561 dan 0562)',
        () {
          const duaKode = <FormulirDikenal>[
            (
              templateId: 'alat_a',
              kodeDokumen: 'SIDIK-FM-CAL-0561_Rev.1',
              judul: 'Calibration Worksheet - Alat A',
            ),
            (
              templateId: 'alat_b',
              kodeDokumen: 'SIDIK-FM-CAL-0562_Rev.1',
              judul: 'Calibration Worksheet - Alat B',
            ),
          ];
          final h = identifikasiLembar(
            'Revise : 1 SIDIK-FM-CAL-056',
            dikenal: duaKode,
          )!;

          expect(h.alasan, AlasanPetunjuk.beberapaKandidat);
          expect(h.sumber, SumberJenisLembar.kodeSamar);
          expect(h.praPilihTemplateId, isNull);
          expect(idKandidat(h), {'alat_a', 'alat_b'});
          expect(h.kodeFormulir, isNull, reason: 'tidak mengaku satu kode');
        },
      );

      test(
        'kode tanpa varian huruf (0538 polos) BUKAN ".A yang terpotong"',
        () {
          final h = ada('Page 1 of 1 SIDIK-FM-CAL-0538');

          expect(h.alasan, AlasanPetunjuk.kodeTakDikenal);
          expect(h.kodeFormulir, 'SIDIK-FM-CAL-0538');
          expect(h.peringkat, isEmpty);
        },
      );

      test('dua kode berbeda terbaca bersih di satu halaman', () {
        final h = ada('SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510');

        expect(h.praPilihTemplateId, isNull);
        expect(idKandidat(h), {'ph_meter', 'conductivity_meter'});
        expect(h.kodeFormulir, isNull, reason: 'tidak mengaku satu kode');
      });

      test(
        'kode terpotong yang cocok dengan terlalu banyak jenis = tanpa bukti',
        () {
          expect(kenali('Revise : 5 SIDIK-FM-CAL-051'), isNull);
          expect(kenali('SIDIK-FM-CAL-05'), isNull);
        },
      );

      test(
        'kode dipakai beberapa jenis (0504) = semua ditampilkan, tanpa pilih-awal',
        () {
          final h = ada('Page 1 of 1 Revise : 3 SIDIK-FM-CAL-0504');

          expect(h.alasan, AlasanPetunjuk.kodeBersama);
          expect(h.praPilihTemplateId, isNull);
          expect(idKandidat(h), {
            'bath',
            'furnace',
            'inkubator',
            'oven',
            'refrigerator',
          });
        },
      );

      test(
        'judul yang menunjuk salah satu jenis kode bersama menentukan pilihan',
        () {
          final h = ada(
            'PT. SIDIK Calibration Worksheet - Oven LK-285-IDN\n'
            'Page 1 of 1 Revise : 3 SIDIK-FM-CAL-0504',
          );

          expect(h.praPilihTemplateId, 'oven');
          expect(idKandidat(h), {'oven'});
        },
      );
    },
  );

  group('bertentangan: kode benar, judul salah', () {
    test(
      'kode 0509 + judul Turbidimeter: tidak dipilihkan, keduanya tampil',
      () {
        final h = ada(
          'PT. SIDIK Calibration Worksheet - Turbidimeter LK-285-IDN\n'
          'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509',
        );

        expect(h.alasan, AlasanPetunjuk.bertentangan);
        expect(h.praPilihTemplateId, isNull);
        expect(idKandidat(h), {'ph_meter', 'turbidimeter'});
        expect(h.sumber, SumberJenisLembar.kodeFormulir);
      },
    );

    test('kode samar + judul salah: juga tidak dipilihkan', () {
      final h = ada(
        'PT. SIDIK Calibration Worksheet - Turbidimeter LK-285-IDN\n'
        'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-O5O9',
      );

      expect(h.alasan, AlasanPetunjuk.bertentangan);
      expect(h.praPilihTemplateId, isNull);
      expect(idKandidat(h), {'ph_meter', 'turbidimeter'});
    });
  });

  group('tanpa bukti', () {
    test('teks kosong, label tanpa kode, angka acak = null', () {
      for (final teks in [
        '',
        'Nama Alat : Merk : Type :',
        'Received Date : Calibration Date : Std. Value X1 X2 X3',
        'Page 1 of 1',
        'SIDIK CAL',
        'Calibration Worksheet',
      ]) {
        expect(kenali(teks), isNull, reason: teks);
      }
    });

    test(
      'daftar server kosong: kode bersih tetap dilaporkan, tanpa kandidat',
      () {
        final h = identifikasiLembar('SIDIK-FM-CAL-0509', dikenal: const []);

        expect(h!.alasan, AlasanPetunjuk.kodeTakDikenal);
        expect(h.kodeFormulir, 'SIDIK-FM-CAL-0509');
        expect(h.praPilihTemplateId, isNull);
      },
    );
  });

  group('teks cetak bersih: kode + judul + revisi sempurna', () {
    test('pH Meter: skor tertinggi dan tiga lapis bukti sepakat', () {
      final h = ada(
        'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN\n'
        'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509',
      );
      final k = h.peringkat.single;

      expect(h.alasan, AlasanPetunjuk.praPilihKode);
      expect(h.praPilihTemplateId, 'ph_meter');
      expect(k.skor, closeTo(1 - 0.08 * 0.25, 1e-9));
      expect(k.bukti.map((b) => (b.lapis, b.mutu)), [
        (LapisBukti.kode, MutuBukti.tepat),
        (LapisBukti.judul, MutuBukti.tepat),
        (LapisBukti.revisi, MutuBukti.tepat),
      ]);
      expect(h.revisiTerbaca, '4');
    });

    test('bukti per lapis tidak membawa teks panjang', () {
      final h = ada(
        '$judulSpektro\nReceived Date : Calibration Date :\n$kakiSpektro',
      );

      for (final b in h.peringkat.single.bukti) {
        expect(b.terbaca.length, lessThanOrEqualTo(32));
      }
    });
  });

  group('semua kode formulir yang dikenal dikenali dari bentuk bersihnya', () {
    String kodePokok(String kodeDokumen) => RegExp(
      r'SIDIK-FM-CAL-\d{4}(?:\.[A-Z])?',
    ).firstMatch(kodeDokumen)!.group(0)!;

    final templatPerKode = <String, Set<String>>{};
    for (final d in dikenal) {
      (templatPerKode[kodePokok(d.kodeDokumen)] ??= {}).add(d.templateId);
    }

    test('daftar uji memuat 27 kode (26 fixture + 0508 tambahan)', () {
      expect(templatPerKode.length, 27);
    });

    for (final MapEntry(key: kode, value: ids) in templatPerKode.entries) {
      test('$kode: kaki bersih saja', () {
        final h = ada('Page 1 of 1 $kode');

        expect(h.sumber, SumberJenisLembar.kodeFormulir);
        expect(h.kodeFormulir, kode);
        expect(idKandidat(h), ids);
        expect(
          h.praPilihTemplateId,
          ids.length == 1 ? ids.single : isNull,
          reason: 'dipilih-awal hanya bila kodenya milik tepat satu jenis',
        );
        expect(
          h.alasan,
          ids.length == 1
              ? AlasanPetunjuk.praPilihKode
              : AlasanPetunjuk.kodeBersama,
        );
      });
    }

    // Teks kepala + kaki formulir kosong (tanpa data pelanggan) dari fixture.
    for (final l in lembar) {
      final kode = l['kode'] as String;

      test('$kode: teks kepala+kaki formulir kosong', () {
        final h = ada(l['teks'] as String);
        final ids = templatPerKode[kode];

        expect(h.kodeFormulir, kode);
        expect(h.revisiTerbaca, l['revisi']);

        if (ids == null) {
          // Kode sah tetapi belum dipetakan server.
          expect(h.alasan, AlasanPetunjuk.kodeTakDikenal);
          expect(h.peringkat, isEmpty);
          expect(h.praPilihTemplateId, isNull);

          return;
        }

        expect(idKandidat(h), ids);
        expect(h.praPilihTemplateId, ids.length == 1 ? ids.single : isNull);
        expect(
          h.alasan,
          isNot(AlasanPetunjuk.bertentangan),
          reason: 'judul cetak formulir sendiri tidak boleh menentang kodenya',
        );
      });
    }
  });

  group('pilih-awal bacaan samar: kode saja butuh bukti lebih kuat', () {
    // Daftar seperti produksi: Temperatur Indikator (tits/tids) dikeluarkan
    // dari daftar pindai, jadi 0505/0506 tidak bisa jadi pesaing.
    final prod = [
      for (final d in dikenal)
        if (d.templateId != 'tits' && d.templateId != 'tids') d,
    ];

    HasilJenisLembar? kenaliProd(String teks) =>
        identifikasiLembar(teks, dikenal: prod);

    test('huruf asing di posisi angka dan angka non-1 yang hilang TIDAK '
        'memilih-awal (jenis tetangga tidak boleh menyerap bacaan rusak)', () {
      // Kode aslinya (0528, 0512, 0538 polos, 0540) tidak ada di daftar; yang
      // terbaca mirip kode tetangga yang ADA (0508, 0532, 0538.A, 0514/0541).
      for (final teks in [
        'SIDIK-FM-CAL-05X8',
        'SIDIK-FM-CAL-058',
        'SIDIK-FM-CAL-05X2',
        'SIDIK-FM-CAL-054X',
        'SIDIK-FM-CAL-05A8',
        'SIDIK-FM-CAL-X509',
      ]) {
        final h = kenaliProd('Page 1 of 1 $teks');

        expect(h?.praPilihTemplateId, isNull, reason: teks);
        expect(
          h?.templateId,
          isNull,
          reason: '$teks: tidak boleh jadi pilihan',
        );
      }
    });

    test(
      'huruf kembar (sampai dua) dan awalan terpotong masih memilih-awal',
      () {
        for (final (teks, jenis) in [
          ('SIDIK-FM-CAL-O5O9', 'ph_meter'),
          ('SIDIK-FM-CAL-O511', 'spectrophotometer'),
          ('SIDIK-FM-CAL-05l1', 'spectrophotometer'),
          ('FM-CAL-0511', 'spectrophotometer'),
        ]) {
          final h = kenaliProd('Page 1 of 1 $teks');

          expect(h?.praPilihTemplateId, jenis, reason: teks);
        }
      },
    );

    test('sapuan korupsi tunggal: tidak ada pilih-awal yang salah, untuk kode '
        'yang ada di daftar maupun yang tidak', () {
      String pokok(String kodeDokumen) => RegExp(
        r'SIDIK-FM-CAL-\d{4}(?:\.[A-Z])?',
      ).firstMatch(kodeDokumen)!.group(0)!;

      final grup = <String, Set<String>>{};
      for (final d in prod) {
        (grup[pokok(d.kodeDokumen)] ??= {}).add(d.templateId);
      }
      final tidakAda = [
        for (final l in lembar)
          if (!grup.containsKey(l['kode'] as String)) l['kode'] as String,
      ];
      expect(
        tidakAda,
        isNotEmpty,
        reason: 'sapuan harus memuat kode di luar daftar',
      );

      const kembar = {
        '0': ['O', 'D', 'Q'],
        '1': ['I', 'l', '|'],
        '2': ['Z'],
        '5': ['S'],
        '6': ['G'],
        '8': ['B'],
      };

      Iterable<String> korupsi(String kode) sync* {
        final m = RegExp(
          r'^(SIDIK-FM-CAL-)(\d{4})(\.[A-Z])?$',
        ).firstMatch(kode)!;
        final awal = m.group(1)!;
        final n = m.group(2)!;
        final akhiran = m.group(3) ?? '';

        for (var i = 0; i < 4; i++) {
          yield '$awal${n.substring(0, i)}X${n.substring(i + 1)}$akhiran';
          yield '$awal${n.substring(0, i)}${n.substring(i + 1)}$akhiran';
          for (final h in kembar[n[i]] ?? const <String>[]) {
            yield '$awal${n.substring(0, i)}$h${n.substring(i + 1)}$akhiran';
          }
        }
        yield '$awal${n.substring(0, 3)}$akhiran';
        yield '$awal${n.substring(0, 2)}$akhiran';
      }

      final salah = <String>[];
      var diperiksa = 0;
      for (final MapEntry(key: kode, value: ids) in grup.entries) {
        for (final teks in korupsi(kode)) {
          diperiksa++;
          final pra = kenaliProd('Page 1 of 1 $teks')?.praPilihTemplateId;
          if (pra != null && !ids.contains(pra)) {
            salah.add('$teks (asli $kode) -> $pra');
          }
        }
      }
      for (final kode in tidakAda) {
        for (final teks in korupsi(kode)) {
          diperiksa++;
          final pra = kenaliProd('Page 1 of 1 $teks')?.praPilihTemplateId;
          if (pra != null) {
            salah.add('$teks (asli $kode, tak ada di daftar) -> $pra');
          }
        }
      }

      expect(diperiksa, greaterThan(400));
      expect(salah, isEmpty);
    });
  });

  group('judul yang kuat tidak menyelamatkan serpihan kode yang kosong', () {
    const judulPh = 'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN';

    test('judul + 05XX / XX09 / 5XX9: usulan saja, TANPA pilih-awal', () {
      for (final frag in ['05XX', 'XX09', '5XX9', 'XXXX']) {
        final h = kenali('$judulPh\nPage 1 of 1 Revise : 4 SIDIK-FM-CAL-$frag');

        expect(h?.praPilihTemplateId, isNull, reason: frag);
        expect(h?.templateId, isNull, reason: frag);
        // Judulnya sendiri tetap tampil sebagai usulan.
        expect(h, isNotNull, reason: frag);
        expect(idKandidat(h!), contains('ph_meter'), reason: frag);
      }
    });

    test(
      'judul + kode yang cukup terbaca (satu huruf kembar) tetap sepakat',
      () {
        final h = ada('$judulPh\nPage 1 of 1 Revise : 4 SIDIK-FM-CAL-O509');

        expect(h.praPilihTemplateId, 'ph_meter');
      },
    );
  });

  group('bacaan bersih mengalahkan bacaan samar kode lain', () {
    test('satu kode bersih + satu kode lain yang samar di halaman yang sama: '
        'yang bersih menang', () {
      final h = ada(
        'Page 1 of 1 SIDIK-FM-CAL-0509\n'
        'Std : SIDIK-FM-CAL-O511',
      );

      expect(h.praPilihTemplateId, 'ph_meter');
      expect(idKandidat(h), {'ph_meter'});
    });
  });

  group('revisi hanya dibaca di kaki halaman', () {
    test(
      '"Rev" di badan lembar (di luar tiga baris terakhir) tidak dibaca',
      () {
        final h = ada(
          'Rev. 2 lain\n'
          'baris badan 2\n'
          'baris badan 3\n'
          'baris badan 4\n'
          'Page 1 of 1 SIDIK-FM-CAL-0509',
        );

        expect(h.revisiTerbaca, isNull);
        expect(
          h.peringkat.single.bukti.where((b) => b.lapis == LapisBukti.revisi),
          isEmpty,
        );
        expect(h.praPilihTemplateId, 'ph_meter');
      },
    );
  });

  group('kode yang terbelah antar baris', () {
    test('tetap terbaca seperti pada jalur ketat (spasi lintas baris)', () {
      for (final teks in [
        'Revise : 5 SIDIK-FM-CAL-\n0511',
        'Revise : 5 SIDIK-FM-\nCAL-0511',
        'Revise : 5 SIDIK\nFM\nCAL\n0511',
        'Revise : 5 SIDIK-FM-CAL-\r\n0511',
      ]) {
        final h = ada(teks);

        expect(h.praPilihTemplateId, 'spectrophotometer', reason: teks);
        expect(h.sumber, SumberJenisLembar.kodeFormulir, reason: teks);
        expect(idKandidat(h), {'spectrophotometer'}, reason: teks);
      }
    });

    test('kode IK yang terbelah antar baris tetap ditolak', () {
      expect(kenali('Metode : SIDIK-IK-CAL-\n0508'), isNull);
      expect(kenali('Calibration Methode :\nSIDIK-FM-CAL-\n0508'), isNull);
    });
  });

  group('templateId hanya untuk jenis yang boleh dipilih-awal', () {
    test('hasil lemah / judul saja / kandidat banyak: templateId null', () {
      for (final teks in [
        'Revise : 5 SIDIK-FM-CAL-OSII', // lemah, satu kandidat
        'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN', // judul saja
        'Page 1 of 1 SIDIK-FM-CAL-0504', // kode bersama
      ]) {
        final h = ada(teks);

        expect(h.peringkat, isNotEmpty, reason: teks);
        expect(h.praPilihTemplateId, isNull, reason: teks);
        expect(h.templateId, isNull, reason: teks);
        expect(h.judul, isNull, reason: teks);
      }
    });

    test('hasil yang dipilih-awal: templateId dan judul mengikutinya', () {
      final h = ada('Revise : 4 SIDIK-FM-CAL-0509');

      expect(h.templateId, 'ph_meter');
      expect(h.judul, 'Calibration Worksheet - pH Meter');
    });
  });

  group('urutan dan bentuk keluaran', () {
    test('peringkat urut skor turun; kandidat sejajar dengan peringkat', () {
      final h = ada(
        'PT. SIDIK Calibration Worksheet - Turbidimeter LK-285-IDN\n'
        'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509',
      );

      final skor = [for (final k in h.peringkat) k.skor];
      expect(skor, [...skor]..sort((a, b) => b.compareTo(a)));
      expect(
        h.kandidat.map((k) => k.templateId),
        h.peringkat.map((k) => k.formulir.templateId),
      );
      for (final k in h.peringkat) {
        expect(k.skor, inInclusiveRange(0, 0.99));
      }
    });
  });
}

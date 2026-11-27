import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/identifikasi_lembar.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/keputusan_pindai_lembar.dart';

/// Lapisan KEPUTUSAN alur foto beranda (`putuskanPindaiLembar`): kapan lembar
/// terbuka sendiri, kapan teknisi mengetuk satu kandidat, kapan jujur bilang
/// tidak yakin. Teksnya lewat `identifikasiLembar` SUNGGUHAN (bukan tiruan),
/// jadi yang diuji sambungan mesin -> keputusan.
///
/// Daftar jenis meniru bentuk `GET /worksheet-templates` (kode dokumen +
/// judul); kode bersama 0504 dipakai lima jenis seperti di server.
FormulirDikenal _f(String id, String nama, String kode, {String rev = '4'}) => (
  templateId: id,
  kodeDokumen: '${kode}_Rev.$rev',
  judul: 'Calibration Worksheet - $nama',
);

final _dikenal = <FormulirDikenal>[
  _f('ph_meter', 'pH Meter', 'SIDIK-FM-CAL-0509'),
  _f('turbidimeter', 'Turbidimeter', 'SIDIK-FM-CAL-0531'),
  _f('oven', 'Oven', 'SIDIK-FM-CAL-0504'),
  _f('furnace', 'Furnace', 'SIDIK-FM-CAL-0504'),
  _f('inkubator', 'Inkubator', 'SIDIK-FM-CAL-0504'),
  _f('bath', 'Bath', 'SIDIK-FM-CAL-0504'),
  _f('refrigerator', 'Refrigerator', 'SIDIK-FM-CAL-0504'),
  _f('timbangan', 'Timbangan', 'SIDIK-FM-CAL-0511'),
];

bool _semuaBoleh(String id) => true;

KeputusanPindai _putuskan(
  String teks, {
  bool Function(String id)? boleh,
  double? ambang,
}) {
  final hasil = identifikasiLembar(teks, dikenal: _dikenal);

  return putuskanPindaiLembar(
    hasil,
    boleh: boleh ?? _semuaBoleh,
    ambang: ambang ?? ambangAutoBuka,
  );
}

const _kakiPh = 'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509';

void main() {
  group('buka otomatis: HANYA kode bersih, unik, skor tinggi, boleh dipindai', () {
    test('kode bersih yang cocok tepat satu jenis membuka lembar sendiri', () {
      final k = _putuskan(_kakiPh);

      expect(k, isA<BukaOtomatis>());
      final buka = k as BukaOtomatis;
      expect(buka.formulir.templateId, 'ph_meter');
      // 0,92 = skor kode tepat di mesin identifikasi (identifikasi_lembar.dart).
      expect(buka.skor, closeTo(0.92, 1e-9));
      expect(buka.skor, greaterThanOrEqualTo(ambangAutoBuka));
    });

    test('kode bersih + judul yang sepakat: tetap terbuka sendiri', () {
      final k = _putuskan(
        'PT. SIDIK Calibration Work Sheet - pH Meter LK-285-IDN\n$_kakiPh',
      );

      expect(k, isA<BukaOtomatis>());
      expect((k as BukaOtomatis).skor, greaterThan(0.92));
    });

    test('ambang benar-benar menahan: skor 0,92 < ambang 0,95 = bertanya', () {
      // Mutan yang dijaga: gerbang skor dilepas -> tes ini merah.
      final k = _putuskan(_kakiPh, ambang: 0.95);

      expect(k, isA<PilihSatu>());
      expect((k as PilihSatu).alasan, AlasanPilih.perluKonfirmasi);
      expect(k.kandidat.single.templateId, 'ph_meter');
    });

    test('revisi tercetak beda dari server: denda skor -> bertanya, tidak '
        'membuka sendiri', () {
      // Server memegang Rev.4; foto mencetak Revise : 5 (skor 0,92 - 0,20).
      final k = _putuskan('Page 1 of 1 Revise : 5 SIDIK-FM-CAL-0509');

      expect(k, isA<PilihSatu>());
      expect((k as PilihSatu).alasan, AlasanPilih.perluKonfirmasi);
    });

    test('jenis unik tetapi BELUM boleh dipindai (siap_pindai / mode uji / '
        'perlu_konfirmasi_lab): pesan jujur, tidak dibuka', () {
      final k = _putuskan(
        'Revise : 4 SIDIK-FM-CAL-0531',
        boleh: (id) => id != 'turbidimeter',
      );

      expect(k, isA<TakDikenali>());
      final t = k as TakDikenali;
      expect(t.alasan, AlasanTakDikenali.belumBisaDipindai);
      expect(t.jenis, 'Turbidimeter');
      expect(t.kode, 'SIDIK-FM-CAL-0531');
    });

    test('kode samar (O5O9 / huruf kembar) TIDAK pernah membuka sendiri, '
        'walau skornya lolos pilih-awal mesin', () {
      final k = _putuskan('Page 1 of 1 Revise : 4 SIDIK-FM-CAL-O509');

      // Mesin berani memilih-awal bacaan samar (skor >= 0,78) ...
      final hasil = identifikasiLembar(
        'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-O509',
        dikenal: _dikenal,
      );
      expect(hasil!.praPilihTemplateId, 'ph_meter');
      // ... tetapi lapisan keputusan tetap meminta SATU ketukan.
      expect(k, isA<PilihSatu>());
      expect((k as PilihSatu).alasan, AlasanPilih.samar);
      expect(k.kandidat.map((e) => e.templateId), ['ph_meter']);
    });
  });

  group('kandidat ganda: satu ketukan, tidak pernah dipilihkan', () {
    test(
      'kode bersama 0504 (lima jenis): paling banyak TIGA kandidat satu '
      'ketukan, tidak ada yang dibuka sendiri; sisanya lewat "Jenis lain"',
      () {
        final k = _putuskan('Revise : 4 SIDIK-FM-CAL-0504');

        expect(k, isA<PilihSatu>());
        final p = k as PilihSatu;
        expect(p.alasan, AlasanPilih.kodeBersama);
        expect(p.kandidat.length, maksKandidatRingkas);
        // Semuanya memang jenis sekode.
        expect(
          p.kandidat.map((e) => e.templateId).toSet().difference({
            'oven',
            'furnace',
            'inkubator',
            'bath',
            'refrigerator',
          }),
          isEmpty,
        );
      },
    );

    test('kode bersama: hanya jenis yang BOLEH dipindai yang ditawarkan', () {
      final k = _putuskan(
        'Revise : 4 SIDIK-FM-CAL-0504',
        boleh: (id) => id == 'oven' || id == 'bath',
      );

      expect(k, isA<PilihSatu>());
      expect((k as PilihSatu).kandidat.map((e) => e.templateId).toSet(), {
        'oven',
        'bath',
      });
    });

    test('kode bersama dengan SATU jenis boleh: tetap bertanya, tidak '
        'membuka sendiri (kandidat > 1 di server)', () {
      // Mutan yang dijaga: "satu yang boleh = langsung buka" -> merah.
      final k = _putuskan(
        'Revise : 4 SIDIK-FM-CAL-0504',
        boleh: (id) => id == 'oven',
      );

      expect(k, isA<PilihSatu>());
      expect((k as PilihSatu).kandidat.single.templateId, 'oven');
    });

    test('kode bersama, tidak satu pun boleh: pesan jujur', () {
      final k = _putuskan('Revise : 4 SIDIK-FM-CAL-0504', boleh: (_) => false);

      expect(k, isA<TakDikenali>());
      expect((k as TakDikenali).alasan, AlasanTakDikenali.belumBisaDipindai);
    });

    test(
      'kode dan judul bertentangan: kandidat dua sisi, tanpa pilihan awal',
      () {
        // Kode kaki 0509 (pH), judul "Timbangan": dua jenis yang berbeda.
        final k = _putuskan(
          'PT. SIDIK Calibration Work Sheet - Timbangan LK-285-IDN\n$_kakiPh',
        );

        expect(k, isA<PilihSatu>());
        final p = k as PilihSatu;
        expect(p.alasan, AlasanPilih.bertentangan);
        expect(p.kandidat.map((e) => e.templateId), containsAll(['ph_meter']));
        expect(p.kandidat.length, lessThanOrEqualTo(maksKandidatRingkas));
      },
    );

    test('hanya judul tercetak, satu jenis cocok: dibuka sendiri', () {
      final k = _putuskan(
        'PT. SIDIK Calibration Work Sheet - pH Meter LK-285-IDN',
      );

      expect(k, isA<BukaOtomatis>());
      expect((k as BukaOtomatis).formulir.templateId, 'ph_meter');
    });

    test('hanya judul tercetak, jenisnya belum boleh dipindai: jujur', () {
      final k = _putuskan(
        'PT. SIDIK Calibration Work Sheet - pH Meter LK-285-IDN',
        boleh: (_) => false,
      );

      expect(k, isA<TakDikenali>());
      expect((k as TakDikenali).alasan, AlasanTakDikenali.belumBisaDipindai);
    });

    // Keputusan pemilik 27 Nov 2026: yang dikenali dari kertas adalah NAMA ALAT
    // di judul. Kode dan revisi berubah-ubah, jadi varian berjudul sama
    // (micrometer 0522.A-D) tidak boleh memunculkan pertanyaan.
    final varianMicrometer = [
      _f('mik_a', 'Micrometer', 'SIDIK-FM-CAL-0522.A'),
      _f('mik_b', 'Micrometer', 'SIDIK-FM-CAL-0522.B'),
    ];
    const judulMicrometer =
        'PT. SIDIK Calibration Work Sheet - Micrometer LK-285-IDN';

    test(
      'hanya judul tercetak, beberapa varian berjudul sama: dibuka sendiri',
      () {
        final hasil = identifikasiLembar(
          judulMicrometer,
          dikenal: varianMicrometer,
        );
        expect(hasil?.alasan, AlasanPetunjuk.judulSaja);
        expect(hasil?.peringkat.length, 2);

        final k = putuskanPindaiLembar(hasil, boleh: _semuaBoleh);

        expect(k, isA<BukaOtomatis>());
        expect(
          (k as BukaOtomatis).formulir.templateId,
          hasil!.peringkat.first.formulir.templateId,
        );
        expect(k.formulir.judul, contains('Micrometer'));
      },
    );

    test('beberapa varian berjudul sama, hanya satu yang boleh: yang itu', () {
      final hasil = identifikasiLembar(
        judulMicrometer,
        dikenal: varianMicrometer,
      );
      final k = putuskanPindaiLembar(hasil, boleh: (id) => id == 'mik_b');

      expect(k, isA<BukaOtomatis>());
      expect((k as BukaOtomatis).formulir.templateId, 'mik_b');
    });

    test('beberapa varian berjudul sama, tak satu pun boleh: jujur', () {
      final hasil = identifikasiLembar(
        judulMicrometer,
        dikenal: varianMicrometer,
      );
      final k = putuskanPindaiLembar(hasil, boleh: (_) => false);

      expect(k, isA<TakDikenali>());
      expect((k as TakDikenali).alasan, AlasanTakDikenali.belumBisaDipindai);
    });
  });

  group('tidak yakin: pesan jujur, tanpa tebakan', () {
    test(
      'tidak ada bukti sama sekali (teks kosong / tanpa kode atau judul)',
      () {
        for (final teks in [
          '',
          'Calibration Date 12/11/2026\nTemperature 22.0',
        ]) {
          final k = _putuskan(teks);

          expect(k, isA<TakDikenali>(), reason: teks);
          expect(
            (k as TakDikenali).alasan,
            AlasanTakDikenali.tidakTerbaca,
            reason: teks,
          );
        }

        expect(
          putuskanPindaiLembar(null, boleh: _semuaBoleh),
          isA<TakDikenali>(),
        );
      },
    );

    test('kode 05xx bersih yang tidak ada di daftar server', () {
      final k = _putuskan('Revise : 4 SIDIK-FM-CAL-0599');

      expect(k, isA<TakDikenali>());
      final t = k as TakDikenali;
      expect(t.alasan, AlasanTakDikenali.kodeTakDikenal);
      expect(t.kode, 'SIDIK-FM-CAL-0599');
    });
  });

  group('invarian keselamatan (sapuan korupsi OCR, deterministik)', () {
    // Kebenaran dasar: lembar TIDAK BOLEH terbuka sendiri kecuali kode cetak
    // jenis itu terbaca PERSIS di teks. Sapuan memutasi teks kaki tiap jenis
    // dengan galat OCR yang lazim; satu pun mutasi yang membuka jenis tanpa
    // kodenya tertulis utuh = mesin atau ambang keliru.
    final acak = Random(1118);
    const huruf = 'OIlSB|!Z5';

    String mutasi(String kode) {
      final c = kode.split('');
      final i = acak.nextInt(c.length);
      switch (acak.nextInt(5)) {
        case 0:
          c[i] = huruf[acak.nextInt(huruf.length)];
        case 1:
          c.removeAt(i);
        case 2:
          c.insert(i, c[i]);
        case 3:
          return c.sublist(0, max(8, c.length - 1 - acak.nextInt(4))).join();
        default:
          c[i] = '${acak.nextInt(10)}';
      }

      return c.join();
    }

    test(
      'buka otomatis => kode jenis itu tertulis utuh dan jenisnya boleh',
      () {
        var terbuka = 0;
        var bertanya = 0;
        for (final d in _dikenal) {
          final kode = RegExp(
            r'SIDIK-FM-CAL-\d{4}',
          ).firstMatch(d.kodeDokumen)!.group(0)!;

          for (var n = 0; n < 60; n++) {
            final teks = 'Page 1 of 1 Revise : 4 ${mutasi(kode)}';
            final k = _putuskan(teks, boleh: (id) => id != 'turbidimeter');

            if (k is BukaOtomatis) {
              terbuka++;
              // Pemisah yang berlebih ("FM--CAL") tidak mengubah identitas
              // kode; yang dibandingkan huruf dan angkanya saja.
              String padat(String x) =>
                  x.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
              final kodeBuka = RegExp(
                r'SIDIK-FM-CAL-\d{4}',
              ).firstMatch(k.formulir.kodeDokumen)!.group(0)!;
              expect(
                padat(teks).contains(padat(kodeBuka)),
                isTrue,
                reason: 'terbuka tanpa kodenya tertulis utuh: "$teks"',
              );
              expect(k.formulir.templateId, isNot('turbidimeter'));
              // Kode yang dipakai bersama tidak pernah terbuka sendiri.
              expect(
                ['oven', 'furnace', 'inkubator', 'bath', 'refrigerator'],
                isNot(contains(k.formulir.templateId)),
                reason: 'kode bersama terbuka sendiri: "$teks"',
              );
            } else {
              bertanya++;
            }
          }
        }

        // Sapuannya sendiri bermakna: ada yang terbuka dan ada yang bertanya.
        expect(terbuka, greaterThan(0));
        expect(bertanya, greaterThan(0));
      },
    );
  });
}

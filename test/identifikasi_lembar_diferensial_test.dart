import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/identifikasi_lembar.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';

/// Tes DIFERENSIAL: pengenal berlapis (`identifikasiLembar`, jalur produksi
/// alur "Pindai lembar") melawan pengenal ketat lama (`detectWorksheetType`,
/// kode bersih persis).
///
/// Yang dikunci: pada teks yang jalur ketat sudah membaca, mesin berlapis
/// memberi jawaban yang SAMA (pilih-awal dan himpunan kandidat), jadi tidak
/// ada lembar yang dulu terbaca benar kini salah atau hilang. Mesin berlapis
/// boleh lebih longgar hanya pada bacaan rusak yang daftar di bawah sebut, dan
/// di sana pilih-awalnya harus jenis yang benar atau kosong.
///
/// Teksnya: kepala+kaki formulir kosong dari fixture (label tercetak saja) dan
/// string buatan. Tidak ada data pelanggan.
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

  const timbangan = (
    templateId: 'timbangan',
    kodeDokumen: 'SIDIK-FM-CAL-0508_Rev.6',
    judul: 'Calibration Worksheet - Timbangan',
  );
  final penuh = <FormulirDikenal>[...fixture, timbangan];
  final produksi = <FormulirDikenal>[
    for (final d in penuh)
      if (d.templateId != 'tits' && d.templateId != 'tids') d,
  ];
  final daftarUji = {'penuh': penuh, 'produksi': produksi};

  String pokok(String kodeDokumen) => RegExp(
    r'SIDIK-FM-CAL-\d{4}(?:\.[A-Z])?',
  ).firstMatch(kodeDokumen)!.group(0)!;

  final kodeDikenal = {for (final d in penuh) pokok(d.kodeDokumen)};

  // Teks yang jalur ketat sanggup baca: formulir kosong dari fixture, kaki
  // bersih tiap kode, dan variasi spasi/huruf/baris yang regex ketat terima.
  final korpus = <String>[
    for (final l in lembar) l['teks'] as String,
    for (final k in kodeDikenal) ...[
      'Page 1 of 1 $k',
      'Page 1 of 1 Revise : 1 $k',
      k.toLowerCase(),
      k.replaceAll('-', ' - '),
      k.replaceAll('-', ' '),
      k.replaceFirst('CAL-', 'CAL- '),
      '${k.substring(0, 13)}\n${k.substring(13)}',
      k.replaceFirst('FM-', 'FM-\n'),
    ],
    'Revise : 5 SIDIK-FM-CAL-\n0511',
    'Revise : 5 SIDIK-FM-\nCAL-0511',
    'Revise : 5 SIDIK\nFM\nCAL\n0511',
    'SIDIK-FM-CAL-0599',
    'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510',
    'Revise : 0 SIDIK-FM-CAL-2403',
    'Calibration Methode : SIDIK-IK-CAL-0508\nPage 1 of 1 SIDIK-FM-CAL-0511',
  ];

  for (final MapEntry(key: nama, value: daftar) in daftarUji.entries) {
    group(
      'daftar $nama: yang dibaca ketat dibaca sama oleh mesin berlapis',
      () {
        test(
          'pilih-awal dan himpunan kandidat identik pada ${korpus.length} teks',
          () {
            var dibandingkan = 0;

            for (final t in korpus) {
              final ketat = detectWorksheetType(t, dikenal: daftar);
              final baru = identifikasiLembar(t, dikenal: daftar);

              if (ketat == null) {
                // Ketat tidak membaca apa pun: mesin berlapis juga tidak boleh
                // mengarang pilihan.
                expect(baru?.praPilihTemplateId, isNull, reason: t);
                continue;
              }
              dibandingkan++;

              expect(baru, isNotNull, reason: 'hilang dibanding ketat: $t');
              expect(
                baru!.praPilihTemplateId,
                ketat.praPilihTemplateId,
                reason: 'pilih-awal beda: $t',
              );

              // Dua kode di satu halaman: lihat tes khusus di bawah.
              if (ketat.kodeLain.isNotEmpty) continue;

              if (ketat.sumber == SumberJenisLembar.kodeFormulir &&
                  ketat.kandidat.isEmpty) {
                expect(baru.alasan, AlasanPetunjuk.kodeTakDikenal, reason: t);
                expect(baru.kodeFormulir, ketat.kodeFormulir, reason: t);
              } else if (ketat.sumber == SumberJenisLembar.kodeFormulir) {
                expect(
                  {for (final k in baru.kandidat) k.templateId},
                  {for (final k in ketat.kandidat) k.templateId},
                  reason: 'kandidat beda: $t',
                );
                expect(baru.kodeFormulir, ketat.kodeFormulir, reason: t);
              }
            }

            expect(dibandingkan, greaterThan(100));
          },
        );

        test('revisi di kaki dibaca sama pada teks satu baris kaki', () {
          for (final t in korpus) {
            if (t.contains('\n') && !lembar.any((l) => l['teks'] == t)) {
              continue;
            }

            final ketat = detectWorksheetType(t, dikenal: daftar);
            final baru = identifikasiLembar(t, dikenal: daftar);
            if (ketat == null || baru == null) continue;
            if (ketat.kodeLain.isNotEmpty) continue;

            expect(baru.revisiTerbaca, ketat.revisiTerbaca, reason: t);
          }
        });
      },
    );
  }

  group('dua kode berbeda di satu halaman', () {
    test('keduanya tampil, tidak ada yang dipilihkan (ketat pun tidak)', () {
      const t = 'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510';
      final ketat = detectWorksheetType(t, dikenal: penuh)!;
      final baru = identifikasiLembar(t, dikenal: penuh)!;

      expect(ketat.praPilihTemplateId, isNull);
      expect(baru.praPilihTemplateId, isNull);
      expect(
        {for (final k in baru.kandidat) k.templateId},
        {'ph_meter', 'conductivity_meter'},
      );
    });
  });

  group('lebih longgar hanya pada bacaan rusak yang disebut', () {
    // (teks, jenis yang benar). Ketat tidak membacanya; mesin berlapis boleh
    // memilih-awal HANYA jenis yang benar.
    const rusak = <(String, String)>[
      ('Page 1 of 1 SIDIK.FM-CAL.0509', 'ph_meter'),
      ('Revise : 4 SIDIK-FM-CAL-O5O9', 'ph_meter'),
      ('SIDIK_FM_CAL_0511', 'spectrophotometer'),
      ('Revise : 4 IDIK-FM-CAL-0509', 'ph_meter'),
      ('Revise : 5 SIDIK-FM-CAL-O511', 'spectrophotometer'),
    ];

    for (final (teks, benar) in rusak) {
      test('"$teks": ketat tidak membaca; berlapis memilih $benar', () {
        final ketat = detectWorksheetType(teks, dikenal: penuh);
        final baru = identifikasiLembar(teks, dikenal: penuh);

        expect(ketat?.praPilihTemplateId, isNull);
        expect(baru?.praPilihTemplateId, benar);
      });
    }
  });
}

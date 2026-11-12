import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart'
    show TeksTerbaca;

/// `test/assets/jenis-lembar-fixture.json`:
///  - `lembar`: kepala + kaki halaman 1 dari ke-41 PDF formulir kosong
///    SIDIK-FM-CAL (hanya label tercetak, tanpa data pelanggan);
///  - `dikenal`: pasangan template_id/kode_dokumen/judul sebagaimana server
///    mengirimnya (diturunkan dari `database/ocr-templates`). Satu kode FM
///    bisa dipakai beberapa profil (0504, 0507, 0513, ...).
void main() {
  final data =
      jsonDecode(
            File('test/assets/jenis-lembar-fixture.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final dikenal = <FormulirDikenal>[
    for (final d in data['dikenal'] as List<dynamic>)
      (
        templateId: (d as Map<String, dynamic>)['template_id'] as String,
        kodeDokumen: d['kode_dokumen'] as String,
        judul: d['judul'] as String,
      ),
  ];
  final lembar = (data['lembar'] as List<dynamic>).cast<Map<String, dynamic>>();

  String kodePokok(String kodeDokumen) => RegExp(
    r'SIDIK-FM-CAL-\d{4}(?:\.[A-Z])?',
  ).firstMatch(kodeDokumen)!.group(0)!;

  test('fixture memuat ke-41 formulir', () => expect(lembar.length, 41));

  group('kode formulir (pengenal utama)', () {
    for (final l in lembar) {
      final kode = l['kode'] as String;

      test('$kode dikenali dari teks kepala+kaki', () {
        final h = detectWorksheetType(l['teks'] as String, dikenal: dikenal);

        expect(h, isNotNull);
        expect(h!.sumber, SumberJenisLembar.kodeFormulir);
        expect(h.kodeFormulir, kode);
        // Tidak ada kode FM lain di halaman yang sama.
        expect(h.kodeLain, isEmpty);
        // Revisi: terisi persis yang tercetak; kosong bila tidak tercetak.
        expect(h.revisiTerbaca, l['revisi']);

        // Pemetaan mengikuti server: sebanyak profil yang berbagi kode ini.
        final sebanyak = dikenal.where((d) => kodePokok(d.kodeDokumen) == kode);
        expect(
          h.kandidat.map((k) => k.templateId).toSet(),
          sebanyak.map((k) => k.templateId).toSet(),
        );
        expect(h.satuKandidat, sebanyak.length == 1);
      });
    }

    test('kode dipakai beberapa profil -> TIDAK memilihkan', () {
      final l = lembar.firstWhere((x) => x['kode'] == 'SIDIK-FM-CAL-0504');
      final h = detectWorksheetType(l['teks'] as String, dikenal: dikenal)!;

      expect(h.kandidat.length, greaterThan(1));
      expect(h.templateId, isNull);
      expect(h.satuKandidat, isFalse);
      expect(namaJenisLembar(h), isNotNull);
    });

    test('kode unik -> kode profil server (bukan tebakan nama)', () {
      final l = lembar.firstWhere((x) => x['kode'] == 'SIDIK-FM-CAL-0509');
      final h = detectWorksheetType(l['teks'] as String, dikenal: dikenal)!;

      expect(h.satuKandidat, isTrue);
      expect(h.templateId, 'ph_meter');
      expect(h.revisiTerbaca, '4');
      expect(namaJenisLembar(h), 'pH Meter');
    });

    test('varian .A tidak bercampur dengan kode polos', () {
      final a = detectWorksheetType(
        'Page 1 of 1 Rev : 3 SIDIK-FM-CAL-0538.A',
        dikenal: dikenal,
      )!;
      final b = detectWorksheetType(
        'Page 1 of 1 Rev : 3 SIDIK-FM-CAL-0538.B',
        dikenal: dikenal,
      )!;

      expect(a.kodeFormulir, 'SIDIK-FM-CAL-0538.A');
      expect(a.templateId, 'flowmeter_flowrate');
      expect(b.kodeFormulir, 'SIDIK-FM-CAL-0538.B');
      expect(b.templateId, 'flowmeter_totalizer');
    });

    test('kode terpecah spasi/strip oleh OCR tetap terbaca', () {
      for (final teks in [
        'Revise : 4 SIDIK - FM - CAL - 0509',
        'Revise : 4 SIDIK-FM-CAL- 0509',
        'revise : 4 sidik-fm-cal-0509',
        'SIDIK FM CAL 0509',
      ]) {
        final h = detectWorksheetType(teks, dikenal: dikenal);
        expect(h?.kodeFormulir, 'SIDIK-FM-CAL-0509', reason: teks);
        expect(h?.templateId, 'ph_meter', reason: teks);
      }
    });

    test('salah baca huruf TIDAK ditebak (O5O9 bukan 0509)', () {
      final h = detectWorksheetType(
        'Revise : 4 SIDIK-FM-CAL-O5O9',
        dikenal: dikenal,
      );

      expect(h, isNull);
    });

    test('dua kode berbeda di satu halaman -> ambigu, bukan dipilihkan', () {
      final h = detectWorksheetType(
        'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-0510',
        dikenal: dikenal,
      )!;

      expect(h.kodeLain, ['SIDIK-FM-CAL-0510']);
      expect(h.satuKandidat, isFalse);
    });

    test('kode sah tetapi tidak dikenal server -> kandidat kosong', () {
      final h = detectWorksheetType('SIDIK-FM-CAL-0599', dikenal: dikenal)!;

      expect(h.kodeFormulir, 'SIDIK-FM-CAL-0599');
      expect(h.kandidat, isEmpty);
      expect(h.templateId, isNull);
      expect(h.satuKandidat, isFalse);
    });

    test('deret lain (formulir sertifikat 2403) bukan jenis lembar', () {
      expect(
        detectWorksheetType('Revise : 0 SIDIK-FM-CAL-2403', dikenal: dikenal),
        isNull,
      );

      // Kode 2403 di halaman yang sama tidak dihitung sebagai "kode lain".
      final h = detectWorksheetType(
        'SIDIK-FM-CAL-0509 ... SIDIK-FM-CAL-2403',
        dikenal: dikenal,
      )!;
      expect(h.kodeLain, isEmpty);
      expect(h.templateId, 'ph_meter');
    });

    test('nomor lebih panjang (05091, 050912) BUKAN 0509', () {
      for (final teks in [
        'Revise : 4 SIDIK-FM-CAL-05091',
        'SIDIK-FM-CAL-050912',
        'SIDIK-FM-CAL-0509123',
      ]) {
        expect(
          detectWorksheetType(teks, dikenal: dikenal),
          isNull,
          reason: teks,
        );
      }

      // Tetap terbaca bila diikuti spasi/akhir teks/huruf varian.
      expect(
        detectWorksheetType(
          'SIDIK-FM-CAL-0509 Page',
          dikenal: dikenal,
        )?.kodeFormulir,
        'SIDIK-FM-CAL-0509',
      );
      expect(
        detectWorksheetType(
          'SIDIK-FM-CAL-0508.A',
          dikenal: dikenal,
        )?.kodeFormulir,
        'SIDIK-FM-CAL-0508.A',
      );
    });

    test('revisi dibaca dari kaki, bukan dari angka lain', () {
      final h = detectWorksheetType(
        'Rev. 0 lain\n\n\n\n\n\n\n\n\n\n\n\n\n\nPage 1 of 1 Rev: 3 SIDIK-FM-CAL-0523',
        dikenal: dikenal,
      )!;

      expect(h.revisiTerbaca, '3');
    });
  });

  group('judul (petunjuk saja)', () {
    test('tanpa kode, judul unik -> petunjuk, BUKAN pemilih profil', () {
      final h = detectWorksheetType(
        'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN\nReceived Date :',
        dikenal: dikenal,
      )!;

      expect(h.sumber, SumberJenisLembar.judul);
      expect(h.kandidat.single.templateId, 'ph_meter');
      expect(h.kodeFormulir, isNull);
      expect(h.satuKandidat, isFalse);
    });

    test('judul yang dipakai beberapa profil -> tidak dipilih', () {
      final h = detectWorksheetType(
        'PT. SIDIK Calibration Work Sheet - Oven/Furnace/Chiller/Water Bath LK-285-IDN',
        dikenal: dikenal,
      );

      expect(h, isNull);
    });

    test('kode menang atas judul', () {
      final h = detectWorksheetType(
        'Calibration Worksheet - pH Meter\nRevise : 5 SIDIK-FM-CAL-0510',
        dikenal: dikenal,
      )!;

      expect(h.sumber, SumberJenisLembar.kodeFormulir);
      expect(h.kodeFormulir, 'SIDIK-FM-CAL-0510');
    });

    test('teks kosong / tanpa petunjuk -> null', () {
      expect(detectWorksheetType('', dikenal: dikenal), isNull);
      expect(
        detectWorksheetType('Nama Alat : Merk : Type :', dikenal: dikenal),
        isNull,
      );
      expect(
        detectWorksheetType('SIDIK-FM-CAL-0509', dikenal: const []),
        isNotNull,
      );
    });
  });

  group('teksHalaman (urutan baca dari bingkai ML Kit)', () {
    TeksTerbaca t(String teks, double x, double y) =>
        (teks: teks, kotak: Rect.fromLTWH(x, y, 60, 20), keyakinan: null);

    test('elemen sebaris digabung kiri-ke-kanan, baris atas-ke-bawah', () {
      final teks = teksHalaman([
        t('SIDIK-FM-CAL-0509', 400, 1000),
        t('Page 1 of 1', 10, 1002),
        t('Judul', 10, 10),
        t('Revise : 4', 200, 999),
      ]);

      expect(teks, 'Judul\nPage 1 of 1 Revise : 4 SIDIK-FM-CAL-0509');
      final h = detectWorksheetType(teks, dikenal: dikenal)!;
      expect(h.templateId, 'ph_meter');
      expect(h.revisiTerbaca, '4');
    });

    test('daftar kosong -> teks kosong -> tanpa petunjuk', () {
      expect(teksHalaman(const []), '');
      expect(detectWorksheetType('', dikenal: dikenal), isNull);
    });
  });
}

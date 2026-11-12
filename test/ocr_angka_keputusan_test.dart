import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/dekoder_ctc.dart';
import 'package:sidik_calibration/services/ocr_angka/keputusan_sel.dart';

/// Status sel: kosong / perlu cek (ditahan) / usulan keyakinan tinggi.
/// Bahan: hasil dekode nyata B-en pada crop SINTETIS (fixture paritas).
void main() {
  final contoh =
      (jsonDecode(
                File(
                  'test/fixtures/ocr_angka/paritas_dekode.json',
                ).readAsStringSync(),
              )['contoh']
              as List)
          .cast<Map<String, dynamic>>();

  HasilDekodeCtc dekodeDari(String file) {
    final c = contoh.firstWhere((c) => c['file'] == file);
    return DekoderCtc.dekode(
      Float64List.fromList([
        for (final v in c['mentah_ppm'] as List) (v as int) / 1e6,
      ]),
      c['frame'] as int,
    );
  }

  AturanFormatSel aturan(int d, {bool neg = false}) =>
      AturanFormatSel(desimal: d, bolehNegatif: neg);

  test('ambang awal 0,990', () => expect(ambangJalurAwal, 0.990));

  group('usulan keyakinan tinggi', () {
    test('lolos ambang + format -> usulan, tetap bukan nilai final', () {
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/002364.png'), // "97,646" jalur ±0,997
        aturan: aturan(3),
      );

      expect(h.status, StatusSelAngka.usulanKeyakinanTinggi);
      expect(h.usulan, '97,646');
      expect(h.alasan, isNull);
    });

    test('sel bertanda: minus ikut terbaca dalam usulan', () {
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/000157.png'), // "-0.20"
        aturan: aturan(2, neg: true),
      );

      expect(h.usulan, '-0.20');
    });

    test('bulat dan 4 desimal', () {
      expect(
        putuskanSelAngka(
          dekode: dekodeDari('crop/005320.png'),
          aturan: aturan(0),
        ).usulan,
        '610',
      );
      expect(
        putuskanSelAngka(
          dekode: dekodeDari('crop/004365.png'),
          aturan: aturan(4),
        ).usulan,
        '539.4344',
      );
    });
  });

  group('perlu cek (ditahan)', () {
    test(
      'skor jalur di bawah ambang -> ditahan, bacaan hanya untuk pratinjau',
      () {
        final h = putuskanSelAngka(
          dekode: dekodeDari('crop/004956.png'), // "0,29" jalur ±0,984
          aturan: aturan(2),
        );

        expect(h.status, StatusSelAngka.perluCek);
        expect(h.alasan, AlasanSelAngka.jalurRendah);
        expect(h.bacaanMentah, '0,29');
        expect(h.usulan, isNull, reason: 'tidak boleh masuk kotak isian');
      },
    );

    test('skor tinggi tapi format salah -> ditahan', () {
      // "97,646" dibaca untuk sel 2 desimal: jumlah desimal tidak cocok.
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/002364.png'),
        aturan: aturan(2),
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.alasan, AlasanSelAngka.formatTidakCocok);
      expect(h.usulan, isNull);
    });

    test('minus pada sel yang tidak boleh negatif -> ditahan', () {
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/000157.png'),
        aturan: aturan(2),
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.alasan, AlasanSelAngka.formatTidakCocok);
    });

    test('ambang lebih ketat membalik usulan jadi ditahan', () {
      final d = dekodeDari('crop/004512.png'); // "7723.7" jalur ±0,993
      expect(
        putuskanSelAngka(dekode: d, aturan: aturan(1, neg: true)).status,
        StatusSelAngka.usulanKeyakinanTinggi,
      );
      expect(
        putuskanSelAngka(
          dekode: d,
          aturan: aturan(1, neg: true),
          ambang: 0.995,
        ).status,
        StatusSelAngka.perluCek,
      );
    });

    test('bacaan tertukar di sel coretan: ditahan, bukan angka karangan', () {
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/004266.png'), // label 0.53, terbaca "0831"
        aturan: aturan(2),
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.usulan, isNull);
    });
  });

  group('kosong', () {
    test('model tidak mengeluarkan karakter -> kosong, jalur 0', () {
      final h = putuskanSelAngka(
        dekode: dekodeDari('crop/001289.png'),
        aturan: aturan(2),
      );

      expect(h.status, StatusSelAngka.kosong);
      expect(h.alasan, AlasanSelAngka.teksKosong);
      expect(h.jalur, 0.0);
      expect(h.usulan, isNull);
    });

    test(
      'sel kosong bergaris terbaca "-" dengan skor rendah -> tidak jadi usulan',
      () {
        final h = putuskanSelAngka(
          dekode: dekodeDari('crop/005528.png'),
          aturan: aturan(2, neg: true),
        );

        expect(h.status, isNot(StatusSelAngka.usulanKeyakinanTinggi));
      },
    );
  });

  group('BATAS DIKETAHUI (sintetis)', () {
    test(
      'sisa tulisan tetangga berskor tinggi dan lolos format -> TETAP usulan',
      () {
        // crop/003126.png = sel kosong dengan sisa digit sel sebelah ("6"),
        // jalur ±0,994. Rig: 1,3–8,0% sel begini terisi. Satu-satunya penahan
        // adalah teknisi yang memeriksa tiap usulan; aturan geometri tepi dicoba
        // dan tidak layak (lihat docs/ocr-angka-onnx.md). Bila kelas ini kelak
        // ditutup, uji ini dibalik jadi "ditahan".
        final h = putuskanSelAngka(
          dekode: dekodeDari('crop/003126.png'),
          aturan: aturan(0),
        );

        expect(h.bacaanMentah, '6');
        expect(h.status, StatusSelAngka.usulanKeyakinanTinggi);
      },
    );

    test(
      'tetangga yang sama ditahan bila sel punya desimal (format tidak cocok)',
      () {
        final h = putuskanSelAngka(
          dekode: dekodeDari('crop/003126.png'),
          aturan: aturan(2),
        );

        expect(h.status, StatusSelAngka.perluCek);
      },
    );
  });
}

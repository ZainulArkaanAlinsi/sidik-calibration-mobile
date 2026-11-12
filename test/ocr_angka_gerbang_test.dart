import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';

/// Gerbang format sel: jumlah desimal dan boleh-negatif dari templat server.
/// Aturannya sama dengan `lolos_format` di rig (`sidik_ocr/alfabet.py`).
void main() {
  AturanFormatSel f(int desimal, {bool negatif = false}) =>
      AturanFormatSel(desimal: desimal, bolehNegatif: negatif);

  group('lolos', () {
    test('bulat: hanya digit, tanpa pemisah', () {
      expect(f(0).lolos('610'), isTrue);
      expect(f(0).lolos('7'), isTrue);
      expect(f(0).lolos('12345678'), isTrue);

      expect(f(0).lolos('6.1'), isFalse);
      expect(f(0).lolos('6,1'), isFalse);
      expect(f(0).lolos(''), isFalse);
      expect(f(0).lolos('.'), isFalse);
    });

    test('desimal harus TEPAT sebanyak templat', () {
      expect(f(2).lolos('4.59'), isTrue);
      expect(f(2).lolos('4,59'), isTrue); // koma dan titik sama sahnya
      expect(f(2).lolos('0,56'), isTrue);

      expect(f(2).lolos('4.5'), isFalse, reason: 'kurang satu digit');
      expect(f(2).lolos('4.591'), isFalse, reason: 'lebih satu digit');
      expect(f(2).lolos('459'), isFalse, reason: 'pemisah hilang');
      expect(f(2).lolos('.59'), isFalse, reason: 'bagian bulat kosong');
      expect(f(2).lolos('4.'), isFalse);
      expect(f(2).lolos('4..59'), isFalse);
      expect(f(2).lolos('4.5.9'), isFalse);
    });

    test('minus hanya bila sel boleh negatif', () {
      expect(f(2).lolos('-0.20'), isFalse, reason: 'sel tak bertanda');
      expect(f(2, negatif: true).lolos('-0.20'), isTrue);
      expect(f(2, negatif: true).lolos('0.20'), isTrue);
      expect(f(0, negatif: true).lolos('-58'), isTrue);

      expect(f(2, negatif: true).lolos('--0.20'), isFalse);
      expect(f(2, negatif: true).lolos('0.2-0'), isFalse);
      expect(f(2, negatif: true).lolos('-'), isFalse);
      expect(f(2, negatif: true).lolos('-.20'), isFalse);
    });

    test('paling banyak 8 karakter (batas yang diukur rig)', () {
      expect(f(4).lolos('539.4344'), isTrue); // 8
      expect(f(4).lolos('1539.4344'), isFalse); // 9
      expect(f(0).lolos('12345678'), isTrue);
      expect(f(0).lolos('123456789'), isFalse);
      expect(f(2, negatif: true).lolos('-1234.56'), isTrue); // 8
      expect(f(2, negatif: true).lolos('-12345.67'), isFalse); // 9
    });

    test('karakter bukan digit ditolak', () {
      expect(f(1).lolos('7O.1'), isFalse);
      expect(f(1).lolos('7 .1'), isFalse);
      expect(f(1).lolos('٧.١'), isFalse, reason: 'digit non-ASCII');
      expect(f(1).lolos('7.1\n'), isFalse);
    });

    test('desimal di luar 0..4 ditolak sejak konstruksi (assert)', () {
      expect(
        () => AturanFormatSel(desimal: 5, bolehNegatif: false),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AturanFormatSel(desimal: -1, bolehNegatif: false),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('dari — turunan dari aturan sel templat', () {
    test('tanpa aturan -> null (jangan menebak format)', () {
      expect(AturanFormatSel.dari(null), isNull);
    });

    test('desimal kosong (server tidak tahu resolusi alat) -> null', () {
      expect(
        AturanFormatSel.dari(const AturanSelAsli(min: 0, maks: 10)),
        isNull,
      );
    });

    test('desimal di atas yang diukur rig (5) -> null', () {
      expect(AturanFormatSel.dari(const AturanSelAsli(desimal: 5)), isNull);
      expect(AturanFormatSel.dari(const AturanSelAsli(desimal: 4)), isNotNull);
    });

    test('izinkan_minus false dan min >= 0 -> minus tidak boleh', () {
      final a = AturanFormatSel.dari(
        const AturanSelAsli(desimal: 2, min: 0, maks: 14, izinkanMinus: false),
      )!;

      expect(a.desimal, 2);
      expect(a.bolehNegatif, isFalse);
      expect(a.lolos('-1.00'), isFalse);
    });

    test(
      'min tidak ada (rentang tak dikenal) dan izinkan_minus tak disebut -> tak boleh minus',
      () {
        final a = AturanFormatSel.dari(const AturanSelAsli(desimal: 1))!;
        expect(a.bolehNegatif, isFalse);
      },
    );

    test('min negatif (mis. pita alat -20 °C) -> boleh minus', () {
      final a = AturanFormatSel.dari(
        const AturanSelAsli(
          desimal: 1,
          min: -20,
          maks: 150,
          izinkanMinus: false,
        ),
      )!;

      expect(a.bolehNegatif, isTrue);
      expect(a.lolos('-20.0'), isTrue);
    });

    test('izinkan_minus true -> boleh minus', () {
      final a = AturanFormatSel.dari(
        const AturanSelAsli(desimal: 3, min: 0, izinkanMinus: true),
      )!;
      expect(a.bolehNegatif, isTrue);
    });

    test('AturanSelAsli.dari membaca izinkan_minus dari JSON server', () {
      final a = AturanSelAsli.dari({
        'tipe': 'desimal',
        'desimal': 2,
        'min': 0,
        'maks': 14,
        'izinkan_minus': false,
      })!;
      expect(a.izinkanMinus, isFalse);
      expect(a.desimal, 2);

      final b = AturanSelAsli.dari({
        'tipe': 'desimal',
        'desimal': 2,
        'izinkan_minus': true,
      })!;
      expect(b.izinkanMinus, isTrue);

      final c = AturanSelAsli.dari({'tipe': 'desimal', 'desimal': 2})!;
      expect(
        c.izinkanMinus,
        isNull,
        reason: 'server tidak menyebut = tidak diketahui',
      );
    });

    test(
      'sel jam/suhu (tipe bukan desimal) -> tanpa aturan -> mesin angka tidak dipakai',
      () {
        expect(AturanSelAsli.dari({'tipe': 'jam', 'desimal': null}), isNull);
        expect(
          AturanFormatSel.dari(
            AturanSelAsli.dari({'tipe': 'suhu', 'desimal': 1}),
          ),
          isNull,
        );
      },
    );
  });
}

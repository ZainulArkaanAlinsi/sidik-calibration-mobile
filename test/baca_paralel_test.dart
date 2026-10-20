import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/services/baca_paralel.dart';

/// `petaTerbatas` — pembacaan sel paralel terbatas (M01). Yang dijaga:
/// hasil ke-i selalu milik masukan ke-i walau selesainya acak, tidak pernah
/// lebih dari `batas` yang berjalan, dan satu galat tidak menghentikan yang
/// lain.
void main() {
  test('batas bawaan 3 (M01: 3-4 sekaligus)', () {
    expect(bacaSelSerentak, 3);
  });

  test('urutan hasil = urutan masukan, bukan urutan selesai', () async {
    // Yang dimulai belakangan selesai duluan.
    final masukan = List.generate(20, (i) => i);
    final hasil = await petaTerbatas<int, String>(masukan, (i) async {
      await Future<void>.delayed(Duration(milliseconds: 40 - i * 2));
      return 'v$i';
    });

    expect(hasil, [for (final i in masukan) 'v$i']);
  });

  test(
    'tidak pernah lebih dari batas yang berjalan; batasnya terpakai',
    () async {
      for (final batas in [1, 3, 4]) {
        var jalan = 0;
        var puncak = 0;

        await petaTerbatas<int, int>(List.generate(13, (i) => i), (i) async {
          jalan++;
          puncak = puncak < jalan ? jalan : puncak;
          await Future<void>.delayed(Duration(milliseconds: 3 + (i * 7) % 5));
          jalan--;
          return i;
        }, batas: batas);

        expect(puncak, batas, reason: 'batas $batas');
      }
    },
  );

  test('dimulai dalam urutan masukan', () async {
    final mulai = <int>[];
    await petaTerbatas<int, int>(List.generate(10, (i) => i), (i) async {
      mulai.add(i);
      await Future<void>.delayed(Duration(milliseconds: (10 - i) % 4));
      return i;
    });

    expect(mulai, List.generate(10, (i) => i));
  });

  test('masukan lebih sedikit dari batas, dan masukan kosong', () async {
    expect(await petaTerbatas<int, int>([7], (i) async => i * 2, batas: 4), [
      14,
    ]);
    expect(await petaTerbatas<int, int>([], (i) async => i), isEmpty);
  });

  test(
    'galat satu masukan tidak menghentikan yang lain; galat pertama dilempar',
    () async {
      final selesai = <int>[];

      await expectLater(
        petaTerbatas<int, int>(List.generate(8, (i) => i), (i) async {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          if (i == 5) throw StateError('lima');
          if (i == 2) throw StateError('dua');
          selesai.add(i);
          return i;
        }),
        throwsA(isA<StateError>().having((e) => e.message, 'pesan', 'dua')),
      );

      expect(selesai..sort(), [0, 1, 3, 4, 6, 7]);
    },
  );

  test('batas < 1 ditolak', () async {
    await expectLater(
      petaTerbatas<int, int>([1], (i) async => i, batas: 0),
      throwsArgumentError,
    );
  });
}

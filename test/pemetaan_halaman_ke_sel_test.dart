import 'dart:math';

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/worksheet_template.dart' show KotakSel;
import 'package:sidik_calibration/services/pemetaan_halaman_ke_sel.dart';

/// Ruang referensi 1000x2000: 100 px = 0,1 lebar dan 0,05 tinggi, supaya angka
/// normalisasi di bawah gampang dibaca. SEMUA data di sini sintetis; tes ini
/// membuktikan perilaku pemetaan, BUKAN akurasi OCR atau geometri formulir asli.
const _ref = (w: 1000, h: 2000);

const _sel = <String, KotakSel>{
  'a': KotakSel(x: 100, y: 100, w: 200, h: 100), // 0,10-0,30 x 0,05-0,10
  'b': KotakSel(x: 300, y: 100, w: 200, h: 100), // 0,30-0,50 (menempel di a)
  'c': KotakSel(x: 100, y: 400, w: 200, h: 100), // 0,10-0,30 x 0,20-0,25
};

KataHalaman _kata(
  String teks,
  double x0,
  double y0,
  double x1,
  double y1, [
  double? keyakinan = 0.95,
]) => KataHalaman(
  teks: teks,
  x0: x0,
  y0: y0,
  x1: x1,
  y1: y1,
  keyakinan: keyakinan,
);

// Kata mungil di tengah sel a / b / c.
KataHalaman _diA(String t, [double? k = 0.95]) =>
    _kata(t, 0.15, 0.06, 0.25, 0.09, k);
KataHalaman _diB(String t, [double? k = 0.95]) =>
    _kata(t, 0.35, 0.06, 0.45, 0.09, k);
KataHalaman _diC(String t, [double? k = 0.95]) =>
    _kata(t, 0.15, 0.21, 0.25, 0.24, k);

HasilPemetaanHalaman _petakan(
  List<KataHalaman> kata, {
  double minBagian = 0.3,
}) => petakanKataKeSel(
  kata: kata,
  sel: _sel,
  ukuranReferensi: _ref,
  minBagianKata: minBagian,
)!;

void main() {
  group('kata di tengah sel', () {
    test('satu kata yakin = usulan dengan teks apa adanya', () {
      final h = _petakan([_diA('333.7')]);
      expect(h.sel['a']!.status, StatusSelPetaan.usulan);
      expect(h.sel['a']!.teksMentah, '333.7');
      expect(h.sel['a']!.alasan, isEmpty);
      expect(h.tidakTerpetakan, isEmpty);
    });

    test(
      'sel tanpa kata tetap kosong, teksMentah null, tidak diisi tebakan',
      () {
        final h = _petakan([_diA('1')]);
        expect(h.sel['b']!.status, StatusSelPetaan.kosong);
        expect(h.sel['b']!.teksMentah, isNull);
        expect(h.sel['b']!.kata, isEmpty);
        expect(h.sel['c']!.status, StatusSelPetaan.kosong);
      },
    );

    test('semua kunci templat selalu ada di hasil, termasuk yang kosong', () {
      final h = _petakan(const []);
      expect(h.sel.keys.toSet(), _sel.keys.toSet());
      expect(
        h.sel.values.every((s) => s.status == StatusSelPetaan.kosong),
        isTrue,
      );
    });

    test('dua kata di sel berbeda masuk ke selnya masing-masing', () {
      final h = _petakan([_diA('10.2'), _diB('11.4'), _diC('9.9')]);
      expect(h.sel['a']!.teksMentah, '10.2');
      expect(h.sel['b']!.teksMentah, '11.4');
      expect(h.sel['c']!.teksMentah, '9.9');
    });
  });

  group('teks tidak pernah diubah', () {
    test('teks ngawur dikembalikan persis, tidak dikoreksi', () {
      for (final t in [
        'O,5',
        '133659',
        '1 234',
        'l5',
        '-',
        '0,0010',
        '12.5.3',
      ]) {
        final h = _petakan([_diA(t)]);
        expect(h.sel['a']!.teksMentah, t, reason: 'teks "$t" berubah');
      }
    });

    test('dua kata dalam satu sel: digabung satu spasi, ditandai ragu', () {
      final h = _petakan([
        _kata('418', 0.20, 0.06, 0.28, 0.09),
        _kata('333.7', 0.11, 0.06, 0.19, 0.09),
      ]);
      expect(h.sel['a']!.teksMentah, '333.7 418');
      expect(h.sel['a']!.status, StatusSelPetaan.ragu);
      expect(h.sel['a']!.alasan, {AlasanRagu.lebihDariSatuKata});
    });
  });

  group('keyakinan', () {
    test('di bawah ambang = ragu, teks tetap ada', () {
      final h = _petakan([_diA('7.5', 0.5)]);
      expect(h.sel['a']!.status, StatusSelPetaan.ragu);
      expect(h.sel['a']!.alasan, {AlasanRagu.keyakinanRendah});
      expect(h.sel['a']!.teksMentah, '7.5');
    });

    test('keyakinan null atau NaN = ragu (tidak dianggap yakin)', () {
      final a = _petakan([_diA('7.5', null)]);
      expect(a.sel['a']!.alasan, {AlasanRagu.keyakinanTidakAda});
      final b = _petakan([_diA('7.5', double.nan)]);
      expect(b.sel['a']!.alasan, {AlasanRagu.keyakinanTidakAda});
    });

    test('tepat di ambang masih usulan', () {
      final h = _petakan([_diA('7.5', 0.8)]);
      expect(h.sel['a']!.status, StatusSelPetaan.usulan);
    });
  });

  group('kata melintasi sel', () {
    test('kata menimpa dua sel: masuk utuh ke keduanya dan ditandai ragu', () {
      // 0,24-0,34: 60% di a, 40% di b. Dengan minBagian 0,3 keduanya memenuhi.
      final h = _petakan([
        _kata('55.5', 0.24, 0.06, 0.34, 0.09),
      ], minBagian: 0.3);
      for (final k in ['a', 'b']) {
        expect(h.sel[k]!.teksMentah, '55.5', reason: 'sel $k');
        expect(h.sel[k]!.status, StatusSelPetaan.ragu);
        expect(h.sel[k]!.alasan, contains(AlasanRagu.kataMelintasiSel));
      }
      expect(h.tidakTerpetakan, isEmpty);
    });

    test(
      'kata yang hanya sedikit menyentuh sel tetangga tidak ikut ke sana',
      () {
        // 0,26-0,31: ~80% di a, ~20% di b: hanya milik a.
        final h = _petakan([_kata('4.2', 0.26, 0.06, 0.31, 0.09)]);
        expect(h.sel['a']!.teksMentah, '4.2');
        expect(h.sel['b']!.status, StatusSelPetaan.kosong);
        expect(
          h.sel['a']!.alasan,
          isNot(contains(AlasanRagu.kataMelintasiSel)),
        );
      },
    );
  });

  group('kata di luar sel dan data rusak', () {
    test('kata di luar semua sel masuk tidakTerpetakan, tidak dibuang', () {
      final luar = _kata('X1', 0.7, 0.7, 0.8, 0.73);
      final h = _petakan([luar, _diA('1')]);
      expect(h.tidakTerpetakan, [luar]);
      expect(h.sel['a']!.teksMentah, '1');
    });

    test('kotak rusak atau teks kosong masuk tidakTerpetakan', () {
      final rusak = [
        _kata('1', 0.2, 0.06, 0.2, 0.09), // lebar nol
        _kata('2', 0.25, 0.09, 0.15, 0.06), // terbalik
        _kata('3', double.nan, 0.06, 0.25, 0.09),
        _kata('   ', 0.15, 0.06, 0.25, 0.09), // hanya spasi
      ];
      final h = _petakan(rusak);
      expect(h.tidakTerpetakan.length, rusak.length);
      expect(h.sel['a']!.status, StatusSelPetaan.kosong);
    });

    test(
      'sel berukuran nol tetap ada sebagai kosong dan tidak menampung kata',
      () {
        final h = petakanKataKeSel(
          kata: [_diA('1')],
          sel: const {
            'a': KotakSel(x: 100, y: 100, w: 200, h: 100),
            'nol': KotakSel(x: 100, y: 100, w: 0, h: 0),
          },
          ukuranReferensi: _ref,
        )!;
        expect(h.sel['nol']!.status, StatusSelPetaan.kosong);
        expect(h.sel['a']!.teksMentah, '1');
      },
    );
  });

  group('pemetaan mustahil = null (pemanggil jatuh ke pembaca on-device)', () {
    test('ukuran referensi null, nol, atau negatif', () {
      for (final u in <({int w, int h})?>[
        null,
        (w: 0, h: 100),
        (w: 100, h: -1),
      ]) {
        expect(
          petakanKataKeSel(kata: [_diA('1')], sel: _sel, ukuranReferensi: u),
          isNull,
        );
      }
    });

    test('templat tanpa sel', () {
      expect(
        petakanKataKeSel(
          kata: [_diA('1')],
          sel: const {},
          ukuranReferensi: _ref,
        ),
        isNull,
      );
    });
  });

  group('ambang pas (toleransi double) dan kata separuh keluar sel', () {
    // Dua kata di bawah SECARA MATEMATIKA persis di ambang, tetapi hasil double
    // sedikit di bawahnya (0,29999999999999993 dan 0,7999999999999999). Dicari
    // dengan skrip, bukan ditebak. Tanpa toleransi kedua tes ini gagal.
    test(
      'tepat 30% di sel a: a ikut memegang kata (melintasi), bukan kosong',
      () {
        // a: (0,3-0,216)/0,28 = 0,3 dan b: 0,7.
        final h = _petakan([_kata('6.6', 0.216, 0.06, 0.496, 0.09)]);
        expect(h.sel['a']!.kata, isNotEmpty);
        expect(h.sel['a']!.status, StatusSelPetaan.ragu);
        expect(h.sel['a']!.alasan, contains(AlasanRagu.kataMelintasiSel));
        expect(h.sel['b']!.alasan, contains(AlasanRagu.kataMelintasiSel));
      },
    );

    test('tepat 80% di dalam sel a: masih bersih (usulan), bukan ragu', () {
      // a: (0,3-0,108)/0,24 = 0,8; sisi b hanya 0,2 sehingga tidak tersentuh.
      final h = _petakan([_kata('6.6', 0.108, 0.06, 0.348, 0.09)]);
      expect(h.sel['a']!.status, StatusSelPetaan.usulan);
      expect(h.sel['b']!.status, StatusSelPetaan.kosong);
    });

    // Sel a = 0,10-0,30 dan b = 0,30-0,50 di sumbu x; y 0,06-0,09 ada di dalam
    // keduanya. Titik 50/50 di bawah dulu jadi ambang keputusan (bawaan 0,5)
    // dan membuat satu sisi menang tanpa tanda; sekarang kedua sel tersentuh.
    for (final lebar in [
      (0.2, 0.4),
      (0.27, 0.33),
      (0.28, 0.32),
      (0.26, 0.34),
    ]) {
      test('kata ${lebar.$1}-${lebar.$2} di perbatasan: kedua sel ragu, '
          'tidak ada yang menang sebagai usulan', () {
        final h = _petakan([_kata('55.5', lebar.$1, 0.06, lebar.$2, 0.09)]);
        for (final k in ['a', 'b']) {
          expect(h.sel[k]!.status, StatusSelPetaan.ragu, reason: 'sel $k');
          expect(h.sel[k]!.alasan, contains(AlasanRagu.kataMelintasiSel));
          expect(h.sel[k]!.teksMentah, '55.5');
        }
      });
    }

    test(
      'kata 53/47 antar dua sel: keduanya ragu, bukan usulan bersih di satu',
      () {
        final h = _petakan([_kata('8.1', 0.20, 0.06, 0.39, 0.09)]);
        expect(h.sel['a']!.status, StatusSelPetaan.ragu);
        expect(h.sel['b']!.status, StatusSelPetaan.ragu);
      },
    );

    test(
      'kata separuh di antara dua sel DAN separuh di luar sel tidak lenyap',
      () {
        // y 0,03-0,09: hanya dua pertiga tingginya di dalam sel, jadi tiap sel
        // memegang kira-kira sepertiga luas kata.
        final h = _petakan([_kata('7', 0.26, 0.03, 0.34, 0.09)]);
        expect(h.sel['a']!.status, StatusSelPetaan.ragu);
        expect(h.sel['b']!.status, StatusSelPetaan.ragu);
        expect(h.sel['a']!.teksMentah, '7');
      },
    );

    test('satu sel tersentuh tetapi sebagian kata di luar sel: ragu', () {
      final h = _petakan([_kata('7', 0.15, 0.03, 0.25, 0.09)]);
      expect(h.sel['a']!.status, StatusSelPetaan.ragu);
      expect(h.sel['a']!.alasan, {AlasanRagu.kataSebagianDiLuarSel});
    });

    test(
      'sel templat yang saling menimpa: kata masuk ke keduanya dan ragu',
      () {
        final h = petakanKataKeSel(
          kata: [_diA('3.3')],
          sel: const {
            'p': KotakSel(x: 100, y: 100, w: 200, h: 100),
            'q': KotakSel(x: 100, y: 100, w: 200, h: 100),
          },
          ukuranReferensi: _ref,
        )!;
        for (final k in ['p', 'q']) {
          expect(h.sel[k]!.status, StatusSelPetaan.ragu);
          expect(h.sel[k]!.alasan, contains(AlasanRagu.kataMelintasiSel));
        }
      },
    );
  });

  group('keyakinan di luar kontrak dan parameter', () {
    test('keyakinan di luar 0..1 tidak dianggap yakin', () {
      for (final y in [95.0, 1.5, -0.1]) {
        final h = _petakan([_diA('7.5', y)]);
        expect(
          h.sel['a']!.status,
          StatusSelPetaan.ragu,
          reason: 'keyakinan $y',
        );
        expect(h.sel['a']!.alasan, {AlasanRagu.keyakinanTidakAda});
      }
    });

    test('ambangKeyakinan non-default dipakai', () {
      final h = petakanKataKeSel(
        kata: [_diA('7.5', 0.95)],
        sel: _sel,
        ukuranReferensi: _ref,
        ambangKeyakinan: 0.99,
      )!;
      expect(h.sel['a']!.alasan, {AlasanRagu.keyakinanRendah});
    });

    test(
      'parameter mustahil melempar ArgumentError, tidak diam-diam usulan',
      () {
        void panggil({
          double ambang = 0.8,
          double min = 0.3,
          double bersih = 0.8,
        }) => petakanKataKeSel(
          kata: [_diA('1')],
          sel: _sel,
          ukuranReferensi: _ref,
          ambangKeyakinan: ambang,
          minBagianKata: min,
          bagianBersih: bersih,
        );
        expect(() => panggil(ambang: double.nan), throwsArgumentError);
        expect(() => panggil(ambang: 1.5), throwsArgumentError);
        expect(() => panggil(min: 0), throwsArgumentError);
        expect(() => panggil(min: 0.9, bersih: 0.5), throwsArgumentError);
        expect(() => panggil(bersih: 1.2), throwsArgumentError);
      },
    );
  });

  test('acak: keanggotaan sel cocok dengan hitungan independen berbasis Rect, '
      'tanpa duplikat dan tanpa kata hilang', () {
    final rnd = Random(7);
    // Grid 4x3 sel yang tidak saling menimpa di ruang 1000x2000.
    final sel = <String, KotakSel>{
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 4; c++)
          'r${r}c$c': KotakSel(
            x: 100.0 + c * 200,
            y: 200.0 + r * 200,
            w: 180,
            h: 150,
          ),
    };
    const pool = [
      'O,5',
      '133659',
      '1 234',
      'l5',
      '-',
      '0,0010',
      '12.5.3',
      '333.7',
      'X1',
      '418',
    ];
    final kata = List.generate(400, (_) {
      final x0 = rnd.nextDouble() * 0.9;
      final y0 = rnd.nextDouble() * 0.5;
      return KataHalaman(
        teks: pool[rnd.nextInt(pool.length)],
        x0: x0,
        y0: y0,
        x1: x0 + 0.02 + rnd.nextDouble() * 0.15,
        y1: y0 + 0.01 + rnd.nextDouble() * 0.05,
        keyakinan: rnd.nextBool() ? rnd.nextDouble() : null,
      );
    });

    final h = petakanKataKeSel(kata: kata, sel: sel, ukuranReferensi: _ref)!;

    Rect rect(KotakSel k) => Rect.fromLTRB(
      k.x / 1000,
      k.y / 2000,
      (k.x + k.w) / 1000,
      (k.y + k.h) / 2000,
    );

    // Hitungan independen: Rect.intersect, bukan rumus min/max di kode produksi.
    double bagianDi(KataHalaman w, KotakSel k) {
      final i = Rect.fromLTRB(w.x0, w.y0, w.x1, w.y1).intersect(rect(k));
      if (!(i.width > 0 && i.height > 0)) return 0.0;
      return i.width * i.height / ((w.x1 - w.x0) * (w.y1 - w.y0));
    }

    var terpetakan = 0;
    for (final w in kata) {
      var sentuh = 0;
      for (final e in sel.entries) {
        final bagian = bagianDi(w, e.value);
        final seharusnya = bagian + 1e-9 >= 0.3;
        expect(
          h.sel[e.key]!.kata.contains(w),
          seharusnya,
          reason:
              'kata "${w.teks}" ${w.x0},${w.y0} vs sel ${e.key} (bagian $bagian)',
        );
        if (seharusnya) sentuh++;
      }
      expect(h.tidakTerpetakan.contains(w), sentuh == 0);
      if (sentuh > 0) terpetakan++;
    }
    expect(
      terpetakan,
      greaterThan(20),
      reason: 'data uji terlalu jarang kena sel',
    );
    expect(
      h.tidakTerpetakan.length + terpetakan,
      kata.length,
      reason: 'ada kata hilang',
    );

    for (final s in h.sel.values) {
      expect(
        s.kata.toSet().length,
        s.kata.length,
        reason: 'duplikat di ${s.kunci}',
      );
      if (s.status == StatusSelPetaan.kosong) {
        expect(s.teksMentah, isNull);
        expect(s.kata, isEmpty);
        continue;
      }
      expect(s.teksMentah, s.kata.map((k) => k.teks).join(' '));
      // Satu-satunya jalan ke "usulan": tepat satu kata, keyakinan sah >= 0,8,
      // dan hampir seluruh kata berada di dalam sel itu.
      if (s.status == StatusSelPetaan.usulan) {
        expect(s.kata.length, 1);
        final k = s.kata.single;
        final y = k.keyakinan;
        expect(y != null && y >= 0.8 && y <= 1, isTrue);
        expect(bagianDi(k, sel[s.kunci]!) + 1e-9, greaterThanOrEqualTo(0.8));
      }
    }
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/ocr_angka/dekoder_ctc.dart';

/// Paritas dekoder CTC + whitelist + skor `jalur` dengan rig `sidik-ocr-eval`.
///
/// Fixture `test/fixtures/ocr_angka/paritas_dekode.json`: peluang mentah 14
/// kolom (B-en, set uji SINTETIS) + teks/skor hasil `dekode.py` rig. SEMUA
/// SINTETIS — tidak ada tulisan teknisi.
void main() {
  final fx =
      jsonDecode(
            File(
              'test/fixtures/ocr_angka/paritas_dekode.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final contoh = (fx['contoh'] as List).cast<Map<String, dynamic>>();
  final kolomModel = (fx['kolom_model'] as List).cast<int>();
  final kelasModel = fx['kelas_model'] as int;

  Float64List mentah(Map<String, dynamic> c) => Float64List.fromList([
    for (final v in c['mentah_ppm'] as List) (v as int) / 1e6,
  ]);

  group('dekode — paritas dengan rig', () {
    test('fixture berisi contoh beragam', () {
      expect(contoh.length, greaterThanOrEqualTo(15));
      expect(
        contoh.map((c) => c['kondisi']).toSet(),
        containsAll(['bersih', 'garis', 'noise', 'coretan']),
      );
    });

    for (final c in contoh) {
      test('${c['file']} (${c['kondisi']}, "${c['label']}")', () {
        final h = DekoderCtc.dekode(mentah(c), c['frame'] as int);

        expect(h.teks, c['teks']);
        // Fixture dibulatkan ke 1e-6, rig menghitung dalam float32.
        expect(h.jalur, closeTo((c['jalur'] as num).toDouble(), 2e-4));

        final pk = (c['peluang_karakter'] as List).cast<num>();
        expect(h.peluangKarakter.length, pk.length);
        for (var i = 0; i < pk.length; i++) {
          expect(h.peluangKarakter[i], closeTo(pk[i].toDouble(), 2e-4));
        }
      });
    }
  });

  group('ambilKolom — dari keluaran model selebar kelas penuh', () {
    // Sisipkan 14 kolom fixture ke baris selebar 438 pada indeks kelas model,
    // sisanya massa kecil, lalu dekode lewat jalur produksi.
    Float32List penuh(Map<String, dynamic> c) {
      final t = c['frame'] as int;
      final m = mentah(c);
      final k = Float32List(t * kelasModel);
      for (var f = 0; f < t; f++) {
        for (var j = 0; j < kolomModel.length; j++) {
          k[f * kelasModel + kolomModel[j]] = m[f * 14 + j].toDouble();
        }
      }
      return k;
    }

    for (final c in contoh.take(8)) {
      test('${c['file']} identik dengan jalur 14 kolom', () {
        final t = c['frame'] as int;
        final diambil = DekoderCtc.ambilKolom(
          penuh(c),
          t,
          kelasModel,
          kolomModel,
        );

        expect(diambil.length, t * 14);
        final h = DekoderCtc.dekode(diambil, t);
        final langsung = DekoderCtc.dekode(mentah(c), t);

        expect(h.teks, langsung.teks);
        expect(h.jalur, closeTo(langsung.jalur, 1e-6));
      });
    }

    test('baris yang jumlahnya bukan 1 dianggap logit lalu di-softmax', () {
      // 2 frame × 4 kelas; kolom whitelist = [0, 1, 2]. Frame 0 condong ke 1.
      final logit = Float32List.fromList([0, 5, 0, 0, 5, 0, 0, 0]);
      final p = DekoderCtc.ambilKolom(logit, 2, 4, [0, 1, 2]);

      final e = [1.0, 148.4131591, 1.0, 1.0];
      final jumlah = e.reduce((a, b) => a + b);
      expect(p[1], closeTo(148.4131591 / jumlah, 1e-6));
      expect(p[0], closeTo(1.0 / jumlah, 1e-6));
    });

    test(
      'kolom di luar kelas atau keluaran terlalu pendek -> ArgumentError',
      () {
        expect(
          () => DekoderCtc.ambilKolom(Float32List(8), 2, 4, [0, 4]),
          throwsArgumentError,
        );
        expect(
          () => DekoderCtc.ambilKolom(Float32List(7), 2, 4, [0, 1]),
          throwsArgumentError,
        );
      },
    );
  });

  group('dekode — aturan CTC', () {
    // Kolom: blank, 0..9, ., ,, - (14). Bangun frame "satu-panas".
    Float64List frameDari(List<int> kelasPerFrame, {double p = 0.9}) {
      final m = Float64List(kelasPerFrame.length * 14);
      for (var t = 0; t < kelasPerFrame.length; t++) {
        for (var k = 0; k < 14; k++) {
          m[t * 14 + k] = k == kelasPerFrame[t] ? p : (1 - p) / 13;
        }
      }
      return m;
    }

    test('karakter kembar berurutan dilebur, blank memisahkan', () {
      // 5 5 | blank | 5 -> "55" (kolom 6 = digit 5)
      final h = DekoderCtc.dekode(frameDari([6, 6, 0, 6]), 4);
      expect(h.teks, '55');
    });

    test('tanpa blank, kembar dilebur jadi satu', () {
      expect(DekoderCtc.dekode(frameDari([6, 6, 6]), 3).teks, '5');
    });

    test('semua blank -> teks kosong dan jalur 0', () {
      final h = DekoderCtc.dekode(frameDari([0, 0, 0]), 3);

      expect(h.teks, isEmpty);
      expect(h.jalur, 0.0);
      expect(h.peluangKarakter, isEmpty);
    });

    test(
      'peluang karakter = puncak di run-nya; jalur = rata-rata geometrik semua frame',
      () {
        final m = Float64List(3 * 14);
        void baris(int t, int kelas, double p) {
          for (var k = 0; k < 14; k++) {
            m[t * 14 + k] = k == kelas ? p : (1 - p) / 13;
          }
        }

        baris(0, 2, 0.6); // digit 1
        baris(1, 2, 0.8); // digit 1, lebih tinggi
        baris(2, 0, 0.9); // blank

        final h = DekoderCtc.dekode(m, 3);
        expect(h.teks, '1');
        expect(h.peluangKarakter.single, closeTo(0.8, 1e-12));
        // exp(mean(log([.6,.8,.9])))
        expect(h.jalur, closeTo(0.7563, 1e-3));
      },
    );

    test('whitelist: kelas di luar 14 kolom tidak bisa muncul', () {
      // Semua massa di blank/karakter yang diizinkan; alfabet hanya 13 simbol.
      final h = DekoderCtc.dekode(frameDari([11, 12, 13]), 3);
      expect(h.teks, '.,-');
    });

    test('ukuran tak cocok -> ArgumentError', () {
      expect(() => DekoderCtc.dekode(Float64List(10), 3), throwsArgumentError);
      expect(() => DekoderCtc.dekode(Float64List(0), 0), throwsArgumentError);
    });
  });
}

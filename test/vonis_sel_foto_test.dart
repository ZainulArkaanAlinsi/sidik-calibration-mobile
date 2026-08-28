import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Vonis sel jalur FOTO — yang menentukan sel mana yang wajib dilihat teknisi
/// sebelum angkanya mendarat di form.
///
/// Berkas ini menjaga TIGA hal yang kalau bergeser diam-diam langsung
/// menerbitkan angka yang belum diperiksa:
///
///  1. **Keyakinan yang tidak dilaporkan bukan izin.** ML Kit pulang `null` di
///     sebagian perangkat. Diperlakukan sebagai "yakin", seluruh sel di
///     perangkat itu lolos tanpa dilihat siapa pun.
///  2. **Tulisan tangan tidak pernah hijau.** Pengenal teks tetap percaya diri
///     waktu salah membaca coretan tangan, jadi keyakinan tinggi justru bukan
///     alasan melewatkan pemeriksaan.
///  3. **Ambangnya dibawa dari luar.** Begitu server mengirim angkanya, tidak
///     boleh ada angka tandingan yang tertinggal di dalam fungsi.
void main() {
  TeksTerbaca kata(String teks, {double? keyakinan}) =>
      (teks: teks, kotak: Rect.zero, keyakinan: keyakinan);

  group('keyakinan tidak dilaporkan', () {
    test('null jadi tidakDiketahui, BUKAN hijau maupun merah', () {
      expect(NilaiVonisFoto.dari(null), VonisFoto.tidakDiketahui);
    });

    test('tidakDiketahui NGGAK boleh keisi otomatis', () {
      expect(
        VonisFoto.tidakDiketahui.bolehOtomatis,
        isFalse,
        reason: 'Keyakinan yang nggak dilaporkan itu ketidaktahuan, bukan izin. '
            'Dibolehkan otomatis, seluruh sel di perangkat yang nggak menyetel '
            'confidence lolos tanpa dilihat siapa pun.',
      );
    });

    test('angkanya tetap ditampilkan — yang hilang penilaiannya, bukan bacaannya', () {
      expect(VonisFoto.tidakDiketahui.nilainyaDitampilkan, isTrue);
    });
  });

  group('tulisan tangan nggak pernah hijau', () {
    test('keyakinan 0,99 pun berhenti di kuning', () {
      expect(
        NilaiVonisFoto.dari(0.99),
        VonisFoto.kuning,
        reason: 'Pengenal teks tetap pede waktu salah baca coretan tangan — '
            '`7,02` jadi `7.2` dengan keyakinan tinggi. Keyakinan tinggi '
            'justru bukan alasan melewatkan pemeriksaan.',
      );
    });

    test('nggak ada satu pun sel jalur foto yang boleh keisi otomatis', () {
      for (final k in [null, 0.0, 0.5, 0.7, 0.89, 0.9, 0.99, 1.0]) {
        expect(
          NilaiVonisFoto.dari(k).bolehOtomatis,
          isFalse,
          reason: 'keyakinan $k lolos tanpa dilihat teknisi',
        );
      }
    });

    test('teks CETAK boleh hijau — jalurnya disediakan, cuma belum dipakai', () {
      expect(
        NilaiVonisFoto.dari(0.95, tulisanTangan: false),
        VonisFoto.hijau,
      );
    });
  });

  group('ambang', () {
    test('di bawah ambang kuning jadi merah', () {
      expect(NilaiVonisFoto.dari(0.69), VonisFoto.merah);
    });

    test('tepat di ambang kuning sudah kuning, bukan merah', () {
      expect(NilaiVonisFoto.dari(0.70), VonisFoto.kuning);
    });

    test('merah nilainya NGGAK ditampilkan duluan', () {
      expect(
        VonisFoto.merah.nilainyaDitampilkan,
        isFalse,
        reason: 'Nampilin angka yang divonis nggak bisa dipercaya bikin '
            'teknisi cuma menyetujui apa yang udah ada.',
      );
    });

    test('ambang dari luar beneran dipakai, bukan angka bawaan diam-diam', () {
      const ketat = AmbangKeyakinan(hijau: 0.99, kuning: 0.95);

      expect(
        NilaiVonisFoto.dari(0.80, ambang: ketat),
        VonisFoto.merah,
        reason: '0,80 kuning di ambang bawaan, tapi merah di ambang ketat. '
            'Kalau ini kuning, ada angka bawaan yang masih nempel di dalam.',
      );
    });

    test('ambang hijau wajib di atas kuning', () {
      expect(
        () => AmbangKeyakinan(hijau: 0.5, kuning: 0.9),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('pintasan dariTeks membaca keyakinan potongan OCR-nya', () {
    expect(NilaiVonisFoto.dariTeks(kata('7,02', keyakinan: 0.4)), VonisFoto.merah);
    expect(NilaiVonisFoto.dariTeks(kata('7,02')), VonisFoto.tidakDiketahui);
  });
}

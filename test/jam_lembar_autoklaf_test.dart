import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/jam_lembar.dart';

/// Kolom `Time` Autoklaf nggak bisa lagi menghasilkan bentuk yang ditolak
/// server.
///
/// **Jalan buntu nyata.** Kotak jam dulu nerima ketikan bebas asal angka &
/// titik dua, lalu dikirim apa adanya. Backend nuntut
/// `date_format:H:i,H:i:s` (`AutoclaveStoreRequest:89`,
/// `AutoclaveCalculationRequest:49`), jadi `8:30` ditolak — dan penolakannya
/// nyampe ke layar teknisi sebagai:
///
///     The waktu.0 field must match the format H:i. (and 5 more errors)
///
/// `waktu.0` bukan nama yang ada di kertas kerjanya. Dua tombol sekaligus mati
/// (hitung & simpan), dan nggak ada satu pun petunjuk kolom mana yang salah.
///
/// Yang dikunci di sini BENTUK KELUARANNYA, diadu ke pola yang sama persis
/// dipakai Laravel — bukan ke daftar contoh yang kebetulan lulus.
void main() {
  /// `H:i` / `H:i:s` versi Laravel: jam 0-23, menit & detik 0-59, dan
  /// [normalisasiJam] selalu ngeluarin bentuk berdetik.
  final polaBackend = RegExp(r'^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$');

  group('normalisasiJam', () {
    test('bentuk yang biasa diketik teknisi jadi H:i:s', () {
      const harapan = {
        '2': '02:00:00',
        '02': '02:00:00',
        '830': '08:30:00',
        '0830': '08:30:00',
        '8:30': '08:30:00',
        '08:30': '08:30:00',
        '083015': '08:30:15',
        '08:30:15': '08:30:15',
        '02:00:00': '02:00:00',
        // Bentuk yang dulu ditolak server tanpa penjelasan.
        '08.30': '08:30:00',
        ' 08:30 ': '08:30:00',
      };

      harapan.forEach((mentah, hasil) {
        expect(normalisasiJam(mentah), hasil, reason: 'input: "$mentah"');
        expect(
          polaBackend.hasMatch(hasil),
          isTrue,
          reason: '"$hasil" mesti lolos date_format:H:i:s punya backend',
        );
      });
    });

    test('kosong balik null — kolom boleh dilewat, itu bukan kesalahan', () {
      expect(normalisasiJam(''), isNull);
      expect(normalisasiJam('   '), isNull);
      expect(normalisasiJam(':'), isNull);
    });

    test('jam/menit/detik di luar akal ditolak di layar, bukan dikirim', () {
      expect(normalisasiJam('25'), isNull, reason: 'jam 25 nggak ada');
      expect(normalisasiJam('0870'), isNull, reason: 'menit 70 nggak ada');
      expect(normalisasiJam('086130'), isNull, reason: 'menit 61 nggak ada');
      expect(normalisasiJam('083099'), isNull, reason: 'detik 99 nggak ada');
    });

    test('apa pun yang balik non-null SELALU lolos pola backend', () {
      // Sapuan menyeluruh: tiap detik dalam sehari, plus bentuk pendek.
      for (var j = 0; j < 24; j++) {
        for (var m = 0; m < 60; m += 7) {
          final mentah = '${j.toString().padLeft(2, '0')}'
              '${m.toString().padLeft(2, '0')}';
          final hasil = normalisasiJam(mentah);

          expect(hasil, isNotNull, reason: 'input: "$mentah"');
          expect(polaBackend.hasMatch(hasil!), isTrue, reason: 'hasil: $hasil');
        }
      }
    });
  });

  group('FormatJamLembar', () {
    /// Ketik satu karakter demi satu, persis seperti jari teknisi.
    String ketik(String urutan) {
      const formatter = FormatJamLembar();
      var nilai = TextEditingValue.empty;

      for (final c in urutan.split('')) {
        final berikut = TextEditingValue(
          text: nilai.text + c,
          selection: TextSelection.collapsed(offset: nilai.text.length + 1),
        );
        nilai = formatter.formatEditUpdate(nilai, berikut);
      }

      return nilai.text;
    }

    test('titik dua muncul sendiri — teknisi cukup ngetik angka', () {
      expect(ketik('0'), '0');
      expect(ketik('08'), '08');
      expect(ketik('083'), '08:3');
      expect(ketik('0830'), '08:30');
      expect(ketik('08301'), '08:30:1');
      expect(ketik('083015'), '08:30:15');
    });

    test('digit ke-7 dan seterusnya diabaikan, bukan bikin kotak kacau', () {
      expect(ketik('08301599'), '08:30:15');
    });

    test('titik dua yang ikut diketik nggak bikin dobel', () {
      expect(ketik('08:30'), '08:30');
      expect(ketik('08:30:15'), '08:30:15');
    });

    test('hasil ketikan penuh langsung lolos pola backend', () {
      expect(polaBackend.hasMatch(ketik('083015')), isTrue);
      expect(normalisasiJam(ketik('0830')), '08:30:00');
    });
  });
}

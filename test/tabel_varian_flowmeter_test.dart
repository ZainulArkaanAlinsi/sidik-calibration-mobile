import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_aliran.dart';

/// Tabel khusus metode Flowmeter mengikuti metode yang dipilih.
///
/// Satu kertas (0538) melayani dua metode — UFM dan Gravimetri — dan server
/// menandai tabel milik satu metode dengan `tampil_kalau`. HP dulu cuma
/// membaca penanda itu di field, jadi kedua set tabel tergambar sekaligus
/// (audit 6 Okt 2026).
void main() {
  const kunciVarian = 'spesifikasi_alat.flowmeter.varian_metode';

  for (final e in <String, Map<String, dynamic> Function()>{
    'flowrate': contohBentukLembarKerjaFlowmeterFlowrate,
    'totalizer': contohBentukLembarKerjaFlowmeterTotalizer,
  }.entries) {
    group(e.key, () {
      LembarKerjaState isianBaru() => LembarKerjaState(
        bentuk: LembarKerja.fromJson(e.value()),
        clientRequestId: 'uji-varian-${e.key}',
      );

      List<TabelHasil> semuaTabel(LembarKerjaState isian) =>
          isian.bentuk.bagian.expand((b) => b.tabel).toList();

      List<TabelHasil> milik(LembarKerjaState isian, String varian) => [
        for (final t in semuaTabel(isian))
          if (t.tampilKalau?.kode == kunciVarian && t.tampilKalau!.nilai.contains(varian)) t,
      ];

      test('penanda tabel terbaca dari bentuk server', () {
        final isian = isianBaru();
        expect(milik(isian, 'gravimetri'), isNotEmpty);
      });

      test('metode belum dipilih: semua tabel tetap tampil', () {
        final isian = isianBaru();
        expect(semuaTabel(isian).every(isian.tabelTampil), isTrue);
      });

      test('UFM dipilih: tabel khusus Gravimetri disembunyikan, isinya tetap', () {
        final isian = isianBaru();
        final grav = milik(isian, 'gravimetri');
        isian.teks[kunciVarian]?.text = 'ufm';

        for (final t in grav) {
          expect(isian.tabelTampil(t), isFalse, reason: '${t.judul} masih tampil di metode UFM');
        }
        for (final t in milik(isian, 'ufm')) {
          expect(isian.tabelTampil(t), isTrue);
        }
        expect(
          semuaTabel(isian).where((t) => t.tampilKalau == null).every(isian.tabelTampil),
          isTrue,
          reason: 'tabel bersama kedua metode wajib tetap tampil',
        );
      });

      test('Gravimetri dipilih: tabel khusus UFM disembunyikan', () {
        final isian = isianBaru();
        isian.teks[kunciVarian]?.text = 'gravimetri';

        for (final t in milik(isian, 'ufm')) {
          expect(isian.tabelTampil(t), isFalse, reason: '${t.judul} masih tampil di metode Gravimetri');
        }
        for (final t in milik(isian, 'gravimetri')) {
          expect(isian.tabelTampil(t), isTrue);
        }
      });
    });
  }
}

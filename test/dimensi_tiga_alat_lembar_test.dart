import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_dimensi.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Dial Indicator, Jangka Sorong, Sieve Mesh (alat ke-30..32) — bentuk ASLI
/// server (digenerate ke `contoh_lembar_kerja_dimensi.dart`) disuapkan ke parser
/// dan penyusun payload.
///
/// Yang dijaga PAYLOAD-nya, bukan tampilan: TIDS, Timbangan, dan Anak Timbangan
/// sama-sama lembar yang kegambar rapi tapi berangkat tanpa kunci yang dibaca
/// server — nol titik terhitung, tanpa error di kedua sisi.
void main() {
  LembarKerjaState isianDari(Map<String, dynamic> bentuk) {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(bentuk),
      clientRequestId: 'uji-dimensi',
    );

    isian.alat = const EquipmentLookup(
      id: 30,
      namaAlat: 'Alat contoh',
      serialNumber: 'UJI-01',
      kategori: 'panjang',
      status: 'aktif',
      satuan: 'mm',
      rangeMax: 25,
      resolusi: 0.01,
    );

    return isian;
  }

  TabelHasil tabel(LembarKerjaState isian, String bagian, [int i = 0]) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == bagian).tabel[i];

  test('mode mock tidak jatuh ke lembar pH untuk ketiga profil', () async {
    final layanan = MockLembarKerjaService();

    for (final profil in ['dial_indicator', 'jangka_sorong', 'sieve']) {
      final bentuk = await layanan.ambilBentuk('mock-token-1', profil: profil);
      expect(
        bentuk.judul.toLowerCase(),
        isNot(contains('ph')),
        reason: '$profil jatuh ke lembar pH',
      );
    }
  });

  group('Dial Indicator', () {
    test(
      'tumpukan balok berkoma desimal + enam penunjukan UP/DOWN sampai ke payload',
      () {
        final isian = isianDari(contohBentukLembarKerjaDialIndicator());
        final hasil = tabel(isian, 'hasil');
        final titik = isian.titikUntukBaris(isian.barisTabel(hasil), 0, hasil)!;

        expect(hasil.pengulangan, hasLength(6));

        titik.kotakBarisCtl(hasil.kunciTabel, 'nominal').text = '2,5+1,3+1,2';
        for (var r = 0; r < 6; r++) {
          titik.kotak(hasil.kunciTabel, 'pembacaan', r).text = '5,00';
        }

        final json = isian
            .toSubmission(draft: true)
            .measurements
            .first
            .toJson();

        // Koma = koma DESIMAL: tiga keping, bukan [2, 5, 1, 3, 1, 2].
        expect(json['nominal'], [2.5, 1.3, 1.2]);
        expect(json['pembacaan'], List.filled(6, 5.0));
      },
    );

    test('blok Evaluation masuk spesifikasi_alat, bukan titik', () {
      final isian = isianDari(contohBentukLembarKerjaDialIndicator());
      final evaluasi = tabel(isian, 'evaluasi');
      final baris = isian.titikUntukBaris(
        isian.barisTabel(evaluasi),
        0,
        evaluasi,
      )!;

      for (var r = 0; r < 10; r++) {
        baris.kotak(evaluasi.kunciTabel, 'pembacaan', r).text = '25,01';
      }

      final kiriman = isian.toSubmission(draft: true);
      final blok =
          kiriman.spesifikasiAlat['dial_indicator'] as Map<String, dynamic>;
      final isi = ((blok['pra_evaluasi'] as Map)['baris'] as List)
          .cast<Map<String, dynamic>>();

      expect(isi.first['pembacaan'], List.filled(10, 25.01));
    });
  });

  group('Jangka Sorong', () {
    test(
      'baris ketiga tabel titik terkirim dengan kunci js_* masing-masing',
      () {
        final isian = isianDari(contohBentukLembarKerjaJangkaSorong());

        void isi(String bagian, String nilai) {
          final t = tabel(isian, bagian);
          final titik = isian.titikUntukBaris(isian.barisTabel(t), 1, t)!;
          for (var r = 0; r < 2; r++) {
            titik.kotak(t.kunciTabel, 'pembacaan', r).text = nilai;
          }
        }

        isi('hasil_outside', '25,02');
        isi('hasil_inside', '25,00');
        isi('hasil_depth', '20,00');

        final json = isian
            .toSubmission(draft: true)
            .measurements
            .map((m) => m.toJson())
            .toList();

        final outside = json.where((m) => m.containsKey('js_outside')).toList();
        expect(outside, isNotEmpty, reason: 'tabel Outside tidak terkirim');
        expect(
          json.any((m) => m.containsKey('js_inside')),
          isTrue,
          reason: 'tabel Inside tidak terkirim',
        );
        expect(
          json.any((m) => m.containsKey('js_depth')),
          isTrue,
          reason: 'tabel Depth tidak terkirim',
        );
        expect(
          (outside.first['js_outside'] as List).whereType<double>(),
          contains(25.02),
        );
      },
    );
  });

  group('Sieve Mesh', () {
    test(
      'opening terkirim ke spesifikasi_alat.sieve.opening dengan nomor opening',
      () {
        final isian = isianDari(contohBentukLembarKerjaSieve());
        final opening = tabel(isian, 'hasil');
        final titik = isian.titikUntukBaris(
          isian.barisTabel(opening),
          0,
          opening,
        )!;

        titik.kotak(opening.kunciTabel, 'warp', 0).text = '19,06';
        titik.kotak(opening.kunciTabel, 'weft', 0).text = '18,94';
        titik.kotak(opening.kunciTabel, 'kawat', 0).text = '3,34';

        final kiriman = isian.toSubmission(draft: true);
        final blok = kiriman.spesifikasiAlat['sieve'] as Map<String, dynamic>;
        final isi = ((blok['opening'] as Map)['baris'] as List)
            .cast<Map<String, dynamic>>();

        expect(
          isi.first['titik_ukur'],
          1.0,
          reason: 'nomor opening hilang — opening 1..6 sumber pengulangan',
        );
        expect(isi.first['warp'], [19.06]);
        expect(isi.first['weft'], [18.94]);
        expect(isi.first['kawat'], [3.34]);
      },
    );
  });
}

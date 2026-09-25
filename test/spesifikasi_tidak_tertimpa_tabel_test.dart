import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_gaya.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_massa.dart';

/// **Isian spesifikasi tidak boleh ditimpa tabel yang disimpan ke blok yang
/// sama.**
///
/// Chaos review 25 Sep 2026. `_tanamTabelSpesifikasi` menanam tabel ber-
/// `simpan_ke: spesifikasi_alat.X` dengan menimpa kunci `X` utuh
/// (`{baris: …}`). Dua lembar kena:
///
/// - **Timbangan** — kotak "beban yang dipakai" (`keterulangan.mid.nominal`,
///   `.maks.nominal`) hilang; diketik 40/90, yang terkirim 50/100 bawaan.
/// - **Gaya** — tabel Preload menunjuk `spesifikasi_alat.gaya`, jadi satuan,
///   standar, kapasitas, dan misalignment ketiga alat Gaya lenyap.
///
/// Perbaikannya di server (`simpan_ke` ke sub-kunci sendiri); test ini
/// menjaga bentuk yang benar-benar keluar dari HP, dari bentuk server.
void main() {
  EquipmentLookup alat(String serial, String kategori, String satuan) =>
      EquipmentLookup(
        id: 1,
        namaAlat: 'Alat uji',
        serialNumber: serial,
        kategori: kategori,
        status: 'aktif',
        satuan: satuan,
        rangeMax: 100,
        resolusi: 0.01,
      );

  TabelHasil tabelKe(LembarKerjaState isian, String simpanKe) => isian
      .bentuk
      .bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.simpanKe == simpanKe);

  test('Timbangan: beban keterulangan yang diketik ikut terkirim', () {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTimbangan()),
      clientRequestId: 'uji-ket',
    )..alat = alat('TB-100', 'massa', 'kg');

    isian.teks['spesifikasi_alat.keterulangan.mid.nominal']!.text = '40';
    isian.teks['spesifikasi_alat.keterulangan.maks.nominal']!.text = '90';

    final ket = tabelKe(isian, 'spesifikasi_alat.keterulangan.tabel');
    isian
            .titikUntukBaris(isian.barisTabel(ket), 0, ket)!
            .kotak(ket.kunciTabel, 'pembacaan', 0)
            .text =
        '40.02';

    final blok = isian.spesifikasiAlat['keterulangan'] as Map<String, dynamic>;

    expect(
      (blok['mid'] as Map)['nominal'],
      '40',
      reason: 'Beban Middle yang diketik tertimpa tabel.',
    );
    expect((blok['maks'] as Map)['nominal'], '90');
    expect(
      ((blok['tabel'] as Map)['baris'] as List).first['pembacaan'].first,
      40.02,
    );
  });

  test('Load Cell: satuan, misalignment, dan preload sampai bersamaan', () {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaLoadCell()),
      clientRequestId: 'uji-gaya',
    )..alat = alat('DEMO-LC-001', 'gaya', 'kN');

    isian.teks['spesifikasi_alat.gaya.kapasitas']!.text = '100';
    isian.teks['spesifikasi_alat.gaya.misalignment.1']!.text = '8,237';

    final preload = tabelKe(isian, 'spesifikasi_alat.gaya.preload');
    isian
            .titikUntukBaris(isian.barisTabel(preload), 1, preload)!
            .kotak(preload.kunciTabel, 'pembacaan', 0)
            .text =
        '68.86';

    final gaya = isian.spesifikasiAlat['gaya'] as Map<String, dynamic>;

    expect(
      gaya['kapasitas'],
      '100',
      reason: 'Isian Gaya tertimpa tabel Preload.',
    );
    expect((gaya['misalignment'] as Map)['1'], '8,237');
    expect(
      ((gaya['preload'] as Map)['baris'] as List)[1]['pembacaan'].first,
      68.86,
    );
  });

  test('Proving Ring: deret UP & DOWN menempel di titik yang sama', () {
    final isian = LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerjaProvingRing()),
      clientRequestId: 'uji-pr',
    )..alat = alat('DEMO-PR-001', 'gaya', 'kgf');

    final up = tabelKe(isian, 'measurements[].gaya_up');
    final down = tabelKe(isian, 'measurements[].gaya_down');

    final tUp = isian.titikUntukBaris(isian.barisTabel(up), 0, up)!;
    tUp.titikCtl.text = '30';
    for (var r = 0; r < 3; r++) {
      tUp.kotak(up.kunciTabel, 'pembacaan', r).text = '237';
      isian
              .titikUntukBaris(isian.barisTabel(down), 0, down)!
              .kotak(down.kunciTabel, 'pembacaan', r)
              .text =
          '238';
    }

    final titik = isian
        .toSubmission(draft: true)
        .measurements
        .map((m) => m.toJson())
        .firstWhere((m) => m.containsKey('gaya_up'));

    expect(titik['titik_ukur'], 30.0);
    expect(titik['gaya_up'], [237.0, 237.0, 237.0]);
    expect(titik['gaya_down'], [238.0, 238.0, 238.0]);
  });
}

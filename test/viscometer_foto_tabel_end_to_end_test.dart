import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Foto tabel Viscometer, **dari bentuk lembar yang beneran dikirim backend**.
///
/// Test pemetaan yang lain menyusun tabelnya sendiri, jadi mereka nggak bisa
/// nangkep kelas bug ini: bentuk yang dipakai layar datang dari API, dan
/// ketiga kegagalan Viscometer justru lahir DI SANA, bukan di algoritmanya.
///
///  1. Kolom `Standard` di kertas nulis label larutan bulat (`100`/`1000`/
///     `60000`), sementara `titik_ukur` yang dihitung nilai sertifikat pada
///     25 °C (`99,65` / `1018` / `59003`). Titik ke-2 & ke-3 meleset 1,8 % —
///     di luar toleransi jangkar angka, jadi dua dari tiga baris nggak akan
///     PERNAH kejangkar lewat nilainya.
///  2. `prefiks_pengulangan` NULL (cuma Spectrophotometer yang ngirim `X`),
///     dan kertas Rev.3 nyetak kepala kolom sebagai nomor polos `1`..`5` —
///     bukan `X1` / `Repeat 1` yang dicari jalur bawaan.
///  3. Tiap Repeat punya dua sub-kolom (`cP` + `°C`), jadi label satuannya
///     wajib kebaca dua-duanya.
///
/// Fixture-nya keluaran `ViscometerProfile::bentukLembarKerja()` apa adanya
/// (`test/fixtures/viscometer-bentuk-hasil.json`), cuma daftar pilihan
/// spindle/model yang dipangkas — kalau backend mengubah bentuknya, test ini
/// yang duluan merah.
void main() {
  final json =
      jsonDecode(
            File('test/fixtures/viscometer-bentuk-hasil.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  final bentuk = LembarKerja.fromJson(json);

  TabelHasil tabelHasil(String tahap) => bentuk.bagian
      .expand((b) => b.tabel)
      .firstWhere((t) => t.tahap == tahap);

  /// Pembacaan & suhu larutan **disalin dari sesi master lab**
  /// (`Master_Olah_Data_Viscometer_CSV/INPUT DATA.csv` baris 34-38, tahap
  /// Before maupun After isinya sama persis). Bukan angka karangan: kalau
  /// nanti hasil app diadu ke workbook, ini angka yang sama yang dipakai.
  ///
  /// Ditulis berkoma seperti yang ditulis tangan teknisi di kertas; master
  /// menyimpannya bertitik karena itu Excel.
  final bacaan = {
    '100': ['97,3', '96,9', '96,8', '95,9', '96,7'],
    '1000': ['919,6', '918,7', '917,4', '916,3', '916,3'],
    // Repeat 5 titik 60000 cP di master isinya `631.74.2` — DUA titik
    // desimal. Lihat `docs/pertanyaan-lab-viscometer.md` §1: Excel
    // melewatkannya waktu AVERAGE, dan angka sebenarnya belum dijawab lab.
    // Di sini dia jadi kasus uji, bukan diperbaiki diam-diam.
    '60000': ['63181,3', '63079,8', '63172,1', '63174,2', '631.74.2'],
  };
  final suhu = {
    '100': ['26,6', '26,5', '26,5', '26,6', '26,4'],
    '1000': ['27,3', '27,4', '27,2', '27,3', '27,3'],
    '60000': ['24,6', '24,6', '24,6', '24,6', '24,6'],
  };

  const xStandar = 150.0;
  const yNomor = 110.0;
  const ySatuan = 150.0;

  TeksTerbaca kata(String teks, double x, double y) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
  );

  double xBacaan(int r) => 320.0 + r * 300.0;
  double xSuhu(int r) => xBacaan(r) + 140.0;
  double xNomor(int r) => xBacaan(r) + 70.0;

  /// Hasil OCR foto kertas Viscometer Rev.3: kepala kolom NOMOR POLOS,
  /// kolom Standard berisi label bulat, tiap Repeat dua sub-kolom.
  List<TeksTerbaca> fotoKertas({String satuanSuhu = '°C'}) {
    final hasil = <TeksTerbaca>[kata('UUT Reading', xBacaan(0), 60)];

    for (var r = 0; r < 5; r++) {
      hasil
        ..add(kata('${r + 1}', xNomor(r), yNomor))
        ..add(kata('cP', xBacaan(r), ySatuan))
        ..add(kata(satuanSuhu, xSuhu(r), ySatuan));
    }

    var y = 220.0;

    for (final label in ['100', '1000', '60000']) {
      hasil.add(kata(label, xStandar, y));

      for (var r = 0; r < 5; r++) {
        hasil
          ..add(kata(bacaan[label]![r], xBacaan(r), y))
          ..add(kata(suhu[label]![r], xSuhu(r), y));
      }

      y += 80;
    }

    return hasil;
  }

  /// Persis yang dikerjakan `_LembarKerjaTabelState._foto()`.
  HasilPetaTabel petakanSepertiLayar(
    List<TeksTerbaca> terbaca,
    TabelHasil tabel,
    LembarKerjaState isian,
  ) {
    final titik = isian.titikTabel(tabel);

    return const PetaTabelFoto().petakan(
      terbaca: terbaca,
      titikUkur: [for (final t in titik) t.titikUkur],
      pengulangan: tabel.pengulangan,
      fieldPerRepeat: [for (final k in tabel.kolom) k.kode],
      labelField: {for (final k in tabel.kolom) k.kode: k.label},
      labelTercetak: {for (final t in titik) t.titikUkur: t.label},
      kepalaPengulangan: tabel.prefiksPengulangan == null
          ? const {}
          : {
              for (final r in tabel.pengulangan)
                r: [
                  '${tabel.prefiksPengulangan}$r',
                  ...PetaTabelFoto.kepalaBawaan(r),
                ],
            },
    );
  }

  test('bentuk dari backend memang yang bikin dua bug ini mungkin', () {
    final tabel = tabelHasil('sesudah_adjustment');

    // Kalau salah satu dari tiga ini berubah di backend, penanganan di sisi
    // layar harus ditinjau ulang — bukan diam-diam ikut berubah.
    expect(
      tabel.prefiksPengulangan,
      isNull,
      reason: 'kepala kolom nomor polos berangkat dari sini',
    );
    expect(
      [for (final b in tabel.barisUntuk(bentuk.satuan)) b.label],
      ['100', '1000', '60000'],
      reason: 'label kertas, bukan titik ukur',
    );
    expect(
      [for (final b in tabel.barisUntuk(bentuk.satuan)) b.titikUkur],
      [99.65, 1018.0, 59003.0],
      reason: 'nilai sertifikat @25 °C — beda 1,8 % dari labelnya',
    );
    expect([for (final k in tabel.kolom) k.label], ['cP', '°C']);
  });

  test('foto kertas Rev.3 → sesi master mendarat benar, nol nyasar', () {
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'e2e');
    addTearDown(isian.dispose);

    final tabel = tabelHasil('sesudah_adjustment');
    final hasil = petakanSepertiLayar(fotoKertas(), tabel, isian);

    expect(hasil.kosong, isFalse, reason: 'inilah yang gagal di lapangan');
    expect(hasil.labelKolomKurang, isEmpty);
    expect(hasil.repeatKetemu, containsAll([1, 2, 3, 4, 5]));
    expect(hasil.titikKetemu, containsAll([99.65, 1018.0, 59003.0]));

    // 30 sel di kertas, satu di antaranya rusak di masternya sendiri
    // (`631.74.2`) — jadi 29 yang sah.
    expect(hasil.sel, hasLength(29));
    expect(hasil.angkaTakTerpetakan, 0, reason: 'nggak ada yang nyasar');

    final peta = {
      for (final s in hasil.sel)
        '${s.titikUkur}|${s.repeatNo}|${s.fieldId}': s.teks,
    };

    const titikPerLabel = {'100': 99.65, '1000': 1018.0, '60000': 59003.0};

    for (final e in titikPerLabel.entries) {
      for (var r = 0; r < 5; r++) {
        final kunci = '${e.value}|${r + 1}|pembacaan';
        final harusnya = bacaan[e.key]![r];

        if (harusnya == '631.74.2') {
          // Dua titik desimal — nggak bisa dibaca sebagai satu angka. Yang
          // benar DIBUANG, bukan ditebak jadi `631,74` atau `63174,2`:
          // menebak berarti memasukkan angka karangan ke dokumen
          // terakreditasi. Teknisi mengetiknya ulang dari kertas.
          expect(peta[kunci], isNull, reason: 'sel rusak nggak boleh ditebak');
        } else {
          expect(peta[kunci], harusnya, reason: 'baris ${e.key} cP, Repeat ${r + 1}');
        }

        expect(
          peta['${e.value}|${r + 1}|suhu'],
          suhu[e.key]![r],
          reason: 'baris ${e.key} °C, Repeat ${r + 1}',
        );
      }
    }
  });

  test('angkanya beneran masuk kotak isian formulir', () {
    // Petakan doang nggak cukup: yang bikin teknisi percaya itu angkanya
    // muncul di kotak yang benar, dan itu langkah terpisah.
    final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'e2e');
    addTearDown(isian.dispose);

    final tabel = tabelHasil('sesudah_adjustment');
    final hasil = petakanSepertiLayar(fotoKertas(), tabel, isian);

    final terisi = isian.terapkanHasilFotoTabel(
      hasil.sel,
      tahap: tabel.tahap,
      pengulangan: tabel.pengulangan,
    );

    expect(terisi, 29, reason: '30 sel kertas, satu rusak di master');

    // Pembacaan dipangkas ke resolusi titiknya (0,1 cP → satu desimal) oleh
    // `_isiSel`; suhu tidak.
    expect(
      isian.titik[1018.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '919,6',
      reason: 'baris 1000 cP — yang dulu nggak pernah kejangkar sama sekali',
    );
    expect(
      isian.titik[59003.0]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '63181,3',
      reason: 'baris 60000 cP — baris kedua yang dulu ilang',
    );
    expect(
      isian.titik[59003.0]!.kotak('sesudah_adjustment', 'pembacaan', 4).text,
      isEmpty,
      reason: 'sel rusak master dibiarkan kosong buat diketik teknisi',
    );
    expect(
      parseAngka(
        isian.titik[59003.0]!.kotak('sesudah_adjustment', 'suhu', 4).text,
      ),
      24.6,
      reason: 'suhu Repeat 5 tetap masuk walau pembacaannya rusak',
    );
  });

  test('tabel Before & After dua-duanya jalan', () {
    for (final tahap in ['sebelum_adjustment', 'sesudah_adjustment']) {
      final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'e2e');
      addTearDown(isian.dispose);

      final hasil = petakanSepertiLayar(
        fotoKertas(),
        tabelHasil(tahap),
        isian,
      );

      expect(hasil.sel, hasLength(29), reason: 'tahap $tahap');
    }
  });

  test('`°C` yang kebaca meleset nggak bikin seluruh tabel batal', () {
    for (final varian in ['oC', 'C', '0C', '˚C']) {
      final isian = LembarKerjaState(bentuk: bentuk, clientRequestId: 'e2e');
      addTearDown(isian.dispose);

      final hasil = petakanSepertiLayar(
        fotoKertas(satuanSuhu: varian),
        tabelHasil('sesudah_adjustment'),
        isian,
      );

      expect(hasil.sel, hasLength(29), reason: 'satuan suhu kebaca `$varian`');
    }
  });
}

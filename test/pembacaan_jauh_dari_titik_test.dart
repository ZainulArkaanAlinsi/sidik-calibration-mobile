import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Salah satuan ditahan di HP, bukan dibiarin nyampe admin.
///
/// Sesi 53 (12 Agt 2026): teknisi milih baris varian **1,412 mS/cm** lalu
/// ngetik **1413** — itu angka µS/cm, 1000× lipat. Backend ngitung
/// Error = 1413 − 1,412 = 1411,588, dan lembarnya nyampe admin kelihatan sehat.
/// `pembacaan_di_luar_rentang` emang nyala 7×, tapi cuma peringatan — dan orang
/// yang bisa mbenerin, teknisi yang lagi berdiri di depan alatnya, udah nggak
/// di situ.
///
/// Diadu ke nominal BARISNYA, bukan ke rentang alat: dua-duanya udah dalam
/// satuan yang sama persis, jadi nggak ada konversi yang bisa salah dan aturan
/// metrologi backend nggak perlu disalin ke Dart buat melenceng belakangan.
void main() {
  LembarKerja lembarConductivity() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
    'judul': 'Calibration Worksheet - Conductivity Meter',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': null,
    'satuan_campuran': true,
    'suhu_wajib': true,
    'satuan_suhu': '°C',
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'CALIBRATION RESULT',
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'judul': 'After adjustment Reading',
            'kolom': [
              {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
              {'kode': 'suhu', 'label': '°C', 'tipe': 'angka'},
            ],
            'pengulangan': [1, 2, 3, 4, 5],
            'baris': [
              {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'desimal': 1},
              {'titik_ukur': 1.412, 'label': '1,412', 'satuan': 'mS/cm', 'desimal': 3},
              {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'desimal': 2},
            ],
          },
        ],
      },
    ],
  });

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: lembarConductivity(),
    clientRequestId: 'tes-jauh',
  );

  void isi(LembarKerjaState isian, double titik, List<String> nilai) {
    for (var i = 0; i < nilai.length; i++) {
      isian.titik[titik]!.kotak('sesudah_adjustment', 'pembacaan', i).text =
          nilai[i];
    }
  }

  test('1413 di baris 1,412 mS/cm ketahan — persis kasus sesi 53', () {
    final isian = isianBaru();
    isi(isian, 1.412, ['1413', '1413', '1413', '1413', '1413']);

    expect(isian.titikPembacaanJauh.map((t) => t.titikUkur), [1.412]);
  });

  test('angka yang benar di baris yang sama lolos', () {
    final isian = isianBaru();
    isi(isian, 1.412, ['1.413', '1.412', '1.414']);

    expect(isian.titikPembacaanJauh, isEmpty);
  });

  test('koma kegeser ke bawah juga ketahan', () {
    final isian = isianBaru();
    isi(isian, 111, ['11.067']);

    expect(isian.titikPembacaanJauh.map((t) => t.titikUkur), [111]);
  });

  test('alat jelek tapi masih se-orde tetap boleh dikirim', () {
    final isian = isianBaru();

    // Melesetnya besar (−28%) tapi masih angka yang mungkin datang dari alat
    // yang lagi diukur di titik ini. Kalibrasi emang buat ngukur yang kayak
    // gini; yang ditahan cuma angka yang mustahil.
    isi(isian, 25, ['18.0', '18.2', '17.9']);

    expect(isian.titikPembacaanJauh, isEmpty);
  });

  test('sel kosong & baris yang belum disentuh nggak bikin ketahan', () {
    final isian = isianBaru();
    isi(isian, 25, ['25.0', '', '25.1']);

    expect(isian.titikPembacaanJauh, isEmpty);
  });

  test('cuma baris yang salah yang disebut, bukan seluruh lembar', () {
    final isian = isianBaru();
    isi(isian, 25, ['25.0', '25.1']);
    isi(isian, 1.412, ['1413']);
    isi(isian, 111, ['110.67']);

    expect(isian.titikPembacaanJauh.map((t) => t.label), ['1,412']);
  });
}

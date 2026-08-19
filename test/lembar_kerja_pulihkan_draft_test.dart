import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart'
    show Keputusan;
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Draft yang dibuka lagi harus balik UTUH — termasuk tabel pengukurannya.
///
/// Sebelum ini `muatDariSesi` cuma mulangin kolom header. Docblock-nya nunjuk
/// ke `terapkanPembacaan` buat tabel Before/After, dan metode itu nggak pernah
/// ditulis — nggak ada di seluruh `lib/`. Jadi teknisi yang nyimpen draft terus
/// mbuka lagi dapat tabel kosong, dan mesti ngetik ulang semua angka dari
/// kertas. Sesi yang dibalikin admin buat direvisi kena hal yang sama, dan di
/// situ lebih parah: yang kekirim balik ke admin cuma sisa yang sempat diketik
/// ulang.
///
/// 493 tes lain hijau semua waktu lubang ini nganggur, jadi yang diuji di sini
/// bukan "metodenya ada" tapi angkanya beneran mendarat di baris yang benar.
void main() {
  /// Bentuk Conductivity generik — 4 baris, titik tengah dua varian satuan.
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
              {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm', 'desimal': 0},
              {'titik_ukur': 12880, 'label': '12880', 'satuan': 'µS/cm', 'desimal': 0},
            ],
          },
        ],
      },
    ],
  });

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: lembarConductivity(),
    clientRequestId: 'tes-pulih',
  );

  /// Satu baris `pembacaan_mentah` seperti yang dikirim
  /// `GET /api/calibrations/{id}`.
  RawMeasurement mentah({
    required int titikKe,
    required double titikUkur,
    required int pembacaanKe,
    required double pembacaan,
    double? suhu,
    int? standardId,
    TahapPembacaan tahap = TahapPembacaan.sesudahAdjustment,
  }) => RawMeasurement(
    id: titikKe * 100 + pembacaanKe,
    titikKe: titikKe,
    titikUkur: titikUkur,
    standardId: standardId,
    pembacaanKe: pembacaanKe,
    pembacaan: pembacaan,
    suhu: suhu,
    tahap: tahap,
    inputSource: 'manual',
    isVerified: true,
  );

  /// Satu titik hasil hitung — sumber cadangan centang standar buat sesi yang
  /// dikirim sebelum `raw_measurements.standard_id` ada.
  MeasurementResult hasil({required double titikUkur, int? standardId}) =>
      MeasurementResult(
        titikKe: 1,
        titikUkur: titikUkur,
        standardId: standardId,
        rataRata: 0,
        error: 0,
        koreksi: 0,
        standarDeviasi: 0,
        jumlahPengulangan: 3,
        typeA: 0,
        typeB: 0,
        ketidakpastianGabungan: 0,
        faktorCakupanK: 2,
        ketidakpastianDiperluas: 0,
        toleransi: 0,
        keputusan: Keputusan.pass,
      );

  String sel(LembarKerjaState isian, double titik, int index) =>
      isian.titik[titik]!.kotak('sesudah_adjustment', 'pembacaan', index).text;

  test('pembacaan tersimpan balik ke sel yang benar waktu draft dibuka', () {
    final isian = isianBaru();

    final kebuang = isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02, suhu: 25.2),
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 2, pembacaan: 25.01),
      mentah(titikKe: 2, titikUkur: 1412, pembacaanKe: 1, pembacaan: 1412.4),
    ]);

    expect(kebuang, 0);
    expect(sel(isian, 25, 0), '25.02');
    expect(sel(isian, 25, 1), '25.01');
    expect(sel(isian, 1412, 0), '1412.4');
    expect(
      isian.titik[25]!.kotak('sesudah_adjustment', 'suhu', 0).text,
      '25.2',
    );
  });

  test('`titik_ke` yang kegeser nggak bikin angkanya mendarat di baris lain', () {
    final isian = isianBaru();

    // Persis bentuk sesi 50 di database: baris pertama lembar di-hide, jadi
    // `titik_ke` tersimpan mulai dari 2 — padahal 25 µS/cm itu baris pertama.
    isian.terapkanPembacaan([
      mentah(titikKe: 2, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02),
      mentah(titikKe: 3, titikUkur: 1412, pembacaanKe: 1, pembacaan: 1412.4),
      mentah(titikKe: 4, titikUkur: 12880, pembacaanKe: 1, pembacaan: 12881),
    ]);

    expect(sel(isian, 25, 0), '25.02');
    expect(sel(isian, 1412, 0), '1412.4');
    expect(sel(isian, 12880, 0), '12881');
  });

  test('beda pembulatan bolak-balik JSON tetap ketemu barisnya', () {
    final isian = isianBaru();

    // `decimal(20,8)` yang dibaca ulang nggak dijamin bit-identik sama angka
    // di bentuk lembar.
    final kebuang = isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25.000000001, pembacaanKe: 1, pembacaan: 25.02),
    ]);

    expect(kebuang, 0);
    expect(sel(isian, 25, 0), '25.02');
  });

  test('sel yang udah diketik teknisi nggak ditimpa data lama', () {
    final isian = isianBaru();

    // Layar kebuka duluan, teknisi ngetik, baru detail sesinya nyampe.
    isian.titik[25]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '25.99';

    isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02),
    ]);

    expect(sel(isian, 25, 0), '25.99');
  });

  test('pembacaan yang barisnya nggak ada dihitung, bukan didiemin', () {
    final isian = isianBaru();

    final kebuang = isian.terapkanPembacaan([
      // Baris varian mS/cm nggak ada di bentuk ini.
      mentah(titikKe: 1, titikUkur: 1.412, pembacaanKe: 1, pembacaan: 1.4124),
      // Pengulangan ke-9, lembarnya cuma 5 kolom.
      mentah(titikKe: 2, titikUkur: 25, pembacaanKe: 9, pembacaan: 25.02),
    ]);

    expect(kebuang, 2);
  });

  test('as-found kepisah dari as-left, nggak numpuk di satu tabel', () {
    final isian = isianBaru();

    isian.terapkanPembacaan([
      mentah(
        titikKe: 1,
        titikUkur: 25,
        pembacaanKe: 1,
        pembacaan: 24.50,
        tahap: TahapPembacaan.sebelumAdjustment,
      ),
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02),
    ]);

    expect(
      isian.titik[25]!.kotak('sebelum_adjustment', 'pembacaan', 0).text,
      '24.5',
    );
    expect(sel(isian, 25, 0), '25.02');
  });

  test('centang standar per titik ikut pulih dari baris mentah', () {
    final isian = isianBaru();

    isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02, standardId: 22),
      mentah(titikKe: 2, titikUkur: 1412, pembacaanKe: 1, pembacaan: 1412.4, standardId: 23),
    ]);

    expect(isian.titik[25]!.standardId, 22);
    expect(isian.titik[1412]!.standardId, 23);
    // Baris yang nggak ada pembacaannya tetap nggak kecentang.
    expect(isian.titik[12880]!.standardId, isNull);
  });

  test('sesi lama tanpa `standard_id` di baris mentah jatuh ke hasil hitung', () {
    final isian = isianBaru();

    isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02),
    ]);
    expect(isian.titik[25]!.standardId, isNull);

    isian.terapkanStandarDariHasil([hasil(titikUkur: 25, standardId: 22)]);

    expect(isian.titik[25]!.standardId, 22);
  });

  test('centang dari baris mentah menang atas hasil hitung', () {
    final isian = isianBaru();

    isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02, standardId: 22),
    ]);
    isian.terapkanStandarDariHasil([hasil(titikUkur: 25, standardId: 99)]);

    expect(isian.titik[25]!.standardId, 22);
  });

  test('pulih lalu kirim ulang = isi yang sama, bukan tabel bolong', () {
    final isian = isianBaru();
    isian.alat = null;

    isian.terapkanPembacaan([
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 1, pembacaan: 25.02, suhu: 25.2),
      mentah(titikKe: 1, titikUkur: 25, pembacaanKe: 2, pembacaan: 25.01, suhu: 25.2),
      mentah(titikKe: 2, titikUkur: 1412, pembacaanKe: 1, pembacaan: 1412.4, suhu: 25.1),
    ]);

    final titik25 = isian.titik[25]!.toSubmission();
    final titik1412 = isian.titik[1412]!.toSubmission();

    expect(titik25.pembacaan.take(2).toList(), [25.02, 25.01]);
    expect(titik25.suhu.take(2).toList(), [25.2, 25.2]);
    expect(titik1412.pembacaan.first, 1412.4);

    // Sel yang emang nggak pernah diisi tetap null — bukan diisi 0.
    expect(titik25.pembacaan[2], isNull);
  });
}

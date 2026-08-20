import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Baris tabel dikunci per BARIS, bukan cuma per titik ukur.
///
/// ## Kenapa ini ada
///
/// Delapan alat lama: satu baris = satu titik ukur, dan `titik_ukur`-nya unik
/// (pH 4/7/10, Turbidimeter 1/100/1000). Selama itu benar, `titik_ukur` sendiri
/// cukup jadi kunci — dan begitulah kodenya dulu.
///
/// Autoklaf mematahkan anggapan itu. Kedelapan barisnya — `Time`, Temp Disk
/// 1-3, Indikator Suhu, Indikator Pressure, Tekanan atm awal, Suhu Ruang —
/// adalah BESARAN YANG BERBEDA, bukan tiga level dari besaran yang sama. Nggak
/// ada titik ukurnya, jadi backend mengirim `titik_ukur: 0` buat kedelapannya.
///
/// Dikunci pakai `titik_ukur`, kedelapan baris itu jatuh ke SATU `TitikState`
/// dan saling menimpa: yang keisi cuma satu baris, tujuh sisanya kosong tiap
/// tabel dibangun ulang. Nggak ada error — cuma tujuh baris data yang hilang.
///
/// Test ini menjaga dua arah sekaligus, dan arah kedua yang lebih penting:
/// perubahan kuncinya TIDAK BOLEH menggeser perilaku sembilan alat yang sudah
/// jalan di produksi.
void main() {
  /// Bentuk mirip Autoklaf: satu tabel, delapan baris, semua `titik_ukur: 0`.
  ///
  /// Ditulis di sini alih-alih memakai mock Autoklaf, supaya yang diuji
  /// PERILAKU KUNCINYA — bukan kebetulan isi satu berkas mock.
  LembarKerja bentukBarisKembar() => LembarKerja.fromJson({
    'judul': 'Uji baris kembar',
    'jumlah_pengulangan': 5,
    'satuan': null,
    'bagian': [
      {
        'kode': 'hasil',
        'halaman': 1,
        'judul': 'HASIL',
        'field': <Map<String, dynamic>>[],
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'judul': 'Pengukuran Berulang',
            'sumbu_pengulangan': 'kolom',
            'baris': [
              {'titik_ukur': 0, 'label': 'Time', 'tipe': 'jam'},
              {'titik_ukur': 0, 'label': 'Temp. Disk 1', 'satuan': '°C'},
              {'titik_ukur': 0, 'label': 'Temp. Disk 2', 'satuan': '°C'},
              {'titik_ukur': 0, 'label': 'Temp. Disk 3', 'satuan': '°C'},
              {'titik_ukur': 0, 'label': 'Indikator Suhu', 'satuan': '°C'},
              {'titik_ukur': 0, 'label': 'Indikator Pressure'},
              {'titik_ukur': 0, 'label': 'Tekanan atm awal'},
              {'titik_ukur': 0, 'label': 'Suhu Ruang', 'satuan': '°C'},
            ],
            'kolom': [
              {'kode': 'pembacaan', 'label': 'Nilai'},
            ],
            'pengulangan': [1, 2, 3, 4, 5],
          },
        ],
      },
    ],
  });

  test('delapan baris ber-titik_ukur sama dapat state sendiri-sendiri', () {
    final isian = LembarKerjaState(
      bentuk: bentukBarisKembar(),
      clientRequestId: 'uji-kembar',
    );
    addTearDown(isian.dispose);

    expect(
      isian.titik.length,
      8,
      reason: 'Kedelapan baris Autoklaf harus punya TitikState sendiri. '
          'Kalau cuma 1, tujuh baris datanya saling nimpa tanpa satu pun error.',
    );

    // Labelnya ikut kebawa utuh — itu satu-satunya cara teknisi tahu baris mana
    // yang lagi diisi, karena angka titik ukurnya nol semua.
    expect(
      isian.titik.values.map((t) => t.label).toList(),
      [
        'Time',
        'Temp. Disk 1',
        'Temp. Disk 2',
        'Temp. Disk 3',
        'Indikator Suhu',
        'Indikator Pressure',
        'Tekanan atm awal',
        'Suhu Ruang',
      ],
    );
  });

  test('isian tiap baris nggak bocor ke baris lain', () {
    final isian = LembarKerjaState(
      bentuk: bentukBarisKembar(),
      clientRequestId: 'uji-kembar',
    );
    addTearDown(isian.dispose);

    final kunci = isian.titik.keys.toList();
    isian.titik[kunci[1]]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '121.27';
    isian.titik[kunci[2]]!.kotak('sesudah_adjustment', 'pembacaan', 0).text =
        '121.30';

    expect(
      isian.titik[kunci[1]]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '121.27',
      reason: 'Disk 2 nimpa Disk 1 — persis kegagalan yang bikin test ini ada.',
    );
    expect(
      isian.titik[kunci[2]]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '121.30',
    );
  });

  test('baris jam kebawa tipenya, baris angka tetap null', () {
    final isian = LembarKerjaState(
      bentuk: bentukBarisKembar(),
      clientRequestId: 'uji-kembar',
    );
    addTearDown(isian.dispose);

    final semua = isian.titik.values.toList();
    expect(semua.first.tipe, 'jam', reason: 'Baris Time diisi jam, bukan angka.');
    expect(semua.skip(1).map((t) => t.tipe), everyElement(isNull));
  });

  /// ARAH SEBALIKNYA, dan ini yang menjaga sembilan alat produksi.
  ///
  /// Selama `titik_ukur`-nya unik, kuncinya WAJIB tetap `titik_ukur` itu
  /// sendiri — bukan indeks. Banyak kode (dan banyak test) menyebut barisnya
  /// langsung lewat angkanya, mis. `isian.titik[1412]`. Kalau kuncinya diam-diam
  /// jadi indeks, semuanya berhenti ketemu.
  test('alat bertitik unik tetap dikunci pakai angka titiknya', () {
    for (final (nama, bentuk) in [
      ('pH Meter', contohBentukLembarKerja()),
      ('Turbidimeter', contohBentukLembarKerjaTurbidi()),
      ('Chlorine', contohBentukLembarKerjaChlorine()),
      ('Spectrophotometer', contohBentukLembarKerjaSpectro()),
      ('Viscometer', contohBentukLembarKerjaVisco()),
      ('DO Meter', contohBentukLembarKerjaDo()),
      ('Gas Detector', contohBentukLembarKerjaGas()),
    ]) {
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson(bentuk),
        clientRequestId: 'uji-$nama',
      );

      for (final e in isian.titik.entries) {
        expect(
          e.key,
          e.value.titikUkur,
          reason: '$nama: kunci barisnya bergeser dari titik ukurnya. '
              'Kode & test yang nyebut `titik[<angka>]` bakal berhenti ketemu.',
        );
      }

      isian.dispose();
    }
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Urutan titik yang dikirim = urutan BARIS di lembar, bukan urutan angka.
///
/// Backend ngasih `titik_ke` dari posisi array `measurements`, dan sertifikat
/// nyetak barisnya per `titik_ke` — jadi urutan di sini mendarat langsung di
/// dokumen yang dikirim ke pelanggan.
///
/// Dulu di `toSubmission()` ada `..sort((a, b) => a.titikUkur.compareTo(...))`.
/// Buat lembar yang satuannya seragam itu nggak kelihatan salah, tapi
/// Conductivity nyampur µS/cm sama mS/cm dalam satu lembar:
///
///  - varian µS/cm → 25 < 111 < 1412, titik tengah kelempar ke baris 3
///  - varian mS/cm → 1,412 < 25 < 111, titik tengah naik ke baris 1
///
/// Master lab urut `25 µS/cm → 1412 µS/cm → 111 mS/cm`. Sesi 51 — yang
/// angkanya udah cocok sama master — tetap kesimpen `[25, 111.193568, 1412]`.
void main() {
  /// Bentuk Conductivity yang udah disusutin ke alat: titik tengah µS/cm.
  LembarKerja lembar(List<Map<String, Object?>> baris) => LembarKerja.fromJson({
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
            'baris': baris,
          },
        ],
      },
    ],
  });

  /// Urutan baris persis kayak master: 25 µS/cm → 1412 µS/cm → 111 mS/cm.
  final barisMikro = [
    {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'desimal': 1},
    {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm', 'desimal': 0},
    {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'desimal': 2},
  ];

  /// Varian mS/cm — titik tengahnya angka terkecil di lembar.
  final barisMili = [
    {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'desimal': 1},
    {'titik_ukur': 1.412, 'label': '1,412', 'satuan': 'mS/cm', 'desimal': 3},
    {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'desimal': 2},
  ];

  LembarKerjaState isianDari(List<Map<String, Object?>> baris) {
    final isian = LembarKerjaState(
      bentuk: lembar(baris),
      clientRequestId: 'tes-urutan',
    );

    // `toSubmission` butuh alat — identitas barangnya, bukan kolom wajib.
    isian.alat = const EquipmentLookup(
      id: 11,
      namaAlat: 'Conductivitymeter',
      serialNumber: 'C12345',
      kategori: 'konduktivitas',
      status: 'aktif',
      satuan: 'mS/cm',
    );

    return isian;
  }

  List<double> urutanKirim(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.titikUkur)
      .toList();

  test('varian µS/cm: 1412 tetap di baris 2, bukan kelempar ke baris 3', () {
    expect(urutanKirim(isianDari(barisMikro)), [25, 1412, 111]);
  });

  test('varian mS/cm: 1,412 tetap di baris 2, bukan naik ke baris 1', () {
    expect(urutanKirim(isianDari(barisMili)), [25, 1.412, 111]);
  });

  test('urutan nggak berubah walau cuma sebagian baris diisi', () {
    final isian = isianDari(barisMikro);

    // Cuma titik tengah yang diisi — baris kosong tetap ikut kekirim supaya
    // admin lihat kolom mana yang bolong.
    isian.titik[1412]!.kotak('sesudah_adjustment', 'pembacaan', 0).text = '1413';

    expect(urutanKirim(isian), [25, 1412, 111]);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';

/// Nomor sertifikat kebaca dari bentuk respons yang BENERAN dikirim server.
///
/// **Kenapa test ini ada.** `CalibrationHistoryItem.fromJson` dulu baca
/// `json['nomor_sertifikat']` di tingkat atas — kunci yang nggak pernah ada di
/// respons `GET /api/calibrations`. Nomornya datang bersarang di
/// `sertifikat.nomor`. Jadi buat SETIAP sesi yang sertifikatnya udah terbit,
/// nilainya null.
///
/// Nggak ada satu pun test yang nangkep itu selama ini karena
/// `MockHistoryService` ngisi `nomorSertifikat` langsung lewat konstruktor —
/// `fromJson` yang salah nggak pernah kelewatan jalur mock. Makanya di sini
/// yang diuji `fromJson`-nya langsung, dengan JSON yang disalin apa adanya dari
/// respons server lokal (21 Agt 2026), bukan dari mock.
void main() {
  /// Disalin dari `GET /api/calibrations` sesi 163, dipangkas ke kunci yang
  /// dibaca `fromJson`. Bentuk bersarangnya dipertahankan persis.
  Map<String, dynamic> barisDariServer({Object? sertifikat}) => {
        'id': 163,
        'status': 'disetujui',
        'tanggal_kalibrasi': '2026-08-20',
        'equipment': {'nama_alat': 'pH Meter Bench'},
        'teknisi': {'nama': 'Uji Alur Sesi'},
        'hasil': {'keputusan': 'FAIL'},
        'certificate_id': 93,
        'sertifikat': ?sertifikat,
      };

  test('nomor kebaca dari `sertifikat.nomor`, bukan tingkat atas', () {
    final item = CalibrationHistoryItem.fromJson(
      barisDariServer(
        sertifikat: {
          'id': 93,
          'nomor': 'CAL/2026/08/0049',
          'status': 'terbit',
        },
      ),
    );

    expect(item.nomorSertifikat, 'CAL/2026/08/0049');
    expect(item.certificateId, 93);
  });

  test('sesi tanpa sertifikat tetap null, bukan crash', () {
    final item = CalibrationHistoryItem.fromJson(barisDariServer());

    expect(item.nomorSertifikat, isNull);
  });

  test('kunci tingkat atas dipakai sebagai cadangan kalau backend nambahin', () {
    final json = barisDariServer()..['nomor_sertifikat'] = 'CAL/2026/08/0049';

    expect(
      CalibrationHistoryItem.fromJson(json).nomorSertifikat,
      'CAL/2026/08/0049',
    );
  });
}

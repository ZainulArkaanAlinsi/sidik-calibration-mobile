import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_history_item.dart';

/// Sertifikat yang GAGAL digenerate tetap punya `certificate_id`, karena
/// barisnya lahir saat sesi disetujui. Dulu alur kerja cuma melihat id itu,
/// menganggap sertifikatnya siap kirim, dan tombol "Coba generate lagi" tidak
/// pernah terjangkau dari aplikasi (CAL/2026/10/0015, 9 Okt 2026).
void main() {
  CalibrationHistoryItem sesi({int? certificateId, String? statusSertifikat}) =>
      CalibrationHistoryItem(
        id: 52,
        namaAlat: 'Labu Ukur',
        namaTeknisi: 'Teknisi',
        status: CalibrationStatus.disetujui,
        certificateId: certificateId,
        statusSertifikat: statusSertifikat,
      );

  test('belum ada baris sertifikat = belum jadi', () {
    expect(sesi().sertifikatBelumJadi, isTrue);
  });

  test('sertifikat gagal = belum jadi walau id-nya ada', () {
    expect(
      sesi(certificateId: 40, statusSertifikat: 'gagal').sertifikatBelumJadi,
      isTrue,
    );
  });

  test('sertifikat masih di antrean = belum jadi', () {
    expect(
      sesi(certificateId: 40, statusSertifikat: 'menunggu_generate')
          .sertifikatBelumJadi,
      isTrue,
    );
  });

  test('sertifikat terbit dan dibatalkan tetap di tahap kirim', () {
    expect(
      sesi(certificateId: 39, statusSertifikat: 'terbit').sertifikatBelumJadi,
      isFalse,
    );
    expect(
      sesi(certificateId: 39, statusSertifikat: 'dibatalkan')
          .sertifikatBelumJadi,
      isFalse,
    );
  });

  test('server lama tanpa status = perilaku lama (id ada = siap kirim)', () {
    expect(sesi(certificateId: 39).sertifikatBelumJadi, isFalse);
  });

  test('status baru yang belum dikenal APK ini tidak dianggap belum jadi', () {
    expect(
      sesi(certificateId: 39, statusSertifikat: 'status_baru')
          .sertifikatBelumJadi,
      isFalse,
    );
  });
}

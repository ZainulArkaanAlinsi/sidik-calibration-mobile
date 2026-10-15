import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';

/// Sejak 16 Okt 2026 `approve` mengembalikan `certificate_id` non-null: server
/// membuat baris placeholder (status `gagal`) sebelum job PDF jalan. Layar
/// tidak boleh membaca `certificate_id != null` sebagai "sudah terbit".
CalibrationHistoryItem _item({int? certId, String? status}) =>
    CalibrationHistoryItem.fromJson({
      'id': 1,
      'status': 'disetujui',
      'certificate_id': certId,
      'sertifikat': certId == null ? null : {'nomor': 'X-1', 'status': status},
      'equipment': {'nama_alat': 'Timbangan'},
      'teknisi': {'nama': 'Andi'},
    });

void main() {
  test('riwayat: placeholder gagal punya id tetapi BUKAN terbit', () {
    final placeholder = _item(certId: 9, status: 'gagal');
    expect(placeholder.certificateId, 9);
    expect(placeholder.sertifikatTerbit, isFalse);

    expect(
      _item(certId: 9, status: 'menunggu_generate').sertifikatTerbit,
      isFalse,
    );
    expect(_item(certId: 9, status: 'terbit').sertifikatTerbit, isTrue);
    expect(_item().sertifikatTerbit, isFalse);
  });

  test('detail: tombol sertifikat dari status, bukan dari id', () {
    CertificateRef ref(String status) =>
        CertificateRef(id: 9, nomor: 'X-1', status: status);

    bool bisa(String status) => ref(status).bisaDibuka;

    expect(bisa('gagal'), isFalse);
    expect(bisa('menunggu_generate'), isFalse);
    expect(bisa('terbit'), isTrue);
    expect(bisa('ditarik'), isTrue);
    expect(bisa('dibatalkan'), isTrue);
  });
}

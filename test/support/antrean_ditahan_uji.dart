// Perkakas uji Setujui di KARTU Antrean Approval untuk jenis alat yang
// penerbitannya ditahan (PR #280). Dipakai test layar dan harness PNG.
//
// Badan 422 disalin dari API NYATA (uji kontrak 19 Nov 2026,
// `kontrak/hasil/dart-ditahan.json` DT-P-proving_ring).
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';

import 'riwayat_ditahan_uji.dart';

final badan422DitahanUji = <String, dynamic>{
  'kode': 'profil_ditahan',
  'message':
      'Penerbitan sertifikat jenis alat ini ditahan menunggu keputusan '
      'Technical Manager: $alasanProvingRingUji. Lembar tetap bisa diisi '
      'dan dihitung.',
  'profil': 'proving_ring',
  'varian': null,
  'rujukan_tm': 'TM-4',
  'alasan': alasanProvingRingUji,
  'penahan': [
    {
      'penyimpangan': 'profil_ditahan',
      'pesan': 'Ditahan menunggu keputusan Technical Manager (TM-4): ...',
    },
  ],
};

class ApprovalDitahanUji implements ApprovalService {
  int panggilan = 0;

  @override
  Future<int?> approve(
    String token,
    int calibrationId, {
    bool abaikanPeringatan = false,
    String? nomorSertifikat,
  }) async {
    panggilan++;
    throw ApiException(
      badan422DitahanUji['message']! as String,
      status: 422,
      body: badan422DitahanUji,
    );
  }

  @override
  Future<void> retryGenerate(String token, int certificateId) async {}
}

class AntreanSatuUji extends MockHistoryService {
  CalibrationHistoryItem get _item => CalibrationHistoryItem(
    id: 42,
    namaAlat: 'Proving Ring',
    namaTeknisi: 'Teknisi Sidik',
    tanggalKalibrasi: DateTime(2026, 11, 18),
    status: CalibrationStatus.menungguApproval,
    nomorOrder: 'ORD/KT/proving_ring',
    nomorOrderDiketahui: true,
  );

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async => [
    _item,
  ];

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => [_item];
}

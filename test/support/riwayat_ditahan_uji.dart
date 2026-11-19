// Detail sesi `GET /calibrations/{id}` untuk uji penerbitan ditahan (PR #280):
// penahanannya dibaca dari [bacaDitahan] tiap kali detail dimuat, supaya tes
// bisa membalik keadaan server (TM melepas, atau klien yang datanya basi) di
// tengah jalan.
//
// Teks alasan dan rujukan disalin dari respons API NYATA (uji kontrak app-API
// 19 Nov 2026, `kontrak/hasil/dart-ditahan.json`, DT-D-proving_ring).
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/penerbitan_ditahan.dart';
import 'package:sidik_calibration/services/history_service.dart';

const alasanProvingRingUji =
    'Proving Ring: U95 tercetak 2,3 kgf (pita 0 sampai 500 kgf lampiran '
    'LK-285-IDN), sedangkan master 22,4 kgf (pita 10 sampai 88 kN), sekitar '
    '10 kali lebih besar daripada sertifikat yang sudah pernah terbit. Pita '
    'CMC mana yang benar (G14) belum diputuskan';

const ditahanProvingRingUji = PenerbitanDitahan(
  ditahan: true,
  alasan: alasanProvingRingUji,
  rujukanTm: 'TM-4',
);

class RiwayatSesiDitahan extends MockHistoryService {
  RiwayatSesiDitahan(this.bacaDitahan);

  final PenerbitanDitahan Function() bacaDitahan;
  int panggilDetail = 0;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    panggilDetail++;
    final p = bacaDitahan();
    return CalibrationDetail.fromJson({
      'id': id,
      'status': 'menunggu_approval',
      'equipment': {'id': 12, 'nama_alat': 'Proving Ring'},
      'teknisi': {'nama': 'Teknisi Sidik'},
      'nomor_sesi': 'KAL/2026/11/0030',
      'nomor_order': 'ORD/KT/proving_ring',
      'penerbitan_ditahan': {
        'ditahan': p.ditahan,
        'alasan': p.alasan,
        'rujukan_tm': p.rujukanTm,
      },
    });
  }
}

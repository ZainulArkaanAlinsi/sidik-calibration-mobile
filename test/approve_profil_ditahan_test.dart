import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/kode_galat.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';

/// `POST /calibrations/{id}/approve` untuk jenis alat yang penerbitannya
/// ditahan (PR #280). Badan 422 di bawah disalin dari API NYATA: uji kontrak
/// app-API 19 Nov 2026, `kontrak/hasil/dart-ditahan.json` langkah
/// DT-P-proving_ring (Proving Ring, TM-4).
const _alasan =
    'Proving Ring: U95 tercetak 2,3 kgf (pita 0 sampai 500 kgf lampiran '
    'LK-285-IDN), sedangkan master 22,4 kgf (pita 10 sampai 88 kN), sekitar '
    '10 kali lebih besar daripada sertifikat yang sudah pernah terbit. Pita '
    'CMC mana yang benar (G14) belum diputuskan';

final _badan422 = <String, dynamic>{
  'kode': 'profil_ditahan',
  'message':
      'Penerbitan sertifikat jenis alat ini ditahan menunggu keputusan '
      'Technical Manager: $_alasan. Lembar tetap bisa diisi dan dihitung.',
  'profil': 'proving_ring',
  'varian': null,
  'rujukan_tm': 'TM-4',
  'alasan': _alasan,
  'penahan': [
    {
      'penyimpangan': 'profil_ditahan',
      'pesan': 'Ditahan menunggu keputusan Technical Manager (TM-4): ...',
    },
  ],
};

ApiPerhitunganService _layanan(Object badan, int status) =>
    ApiPerhitunganService(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(badan),
            status,
            headers: {'content-type': 'application/json'},
          ),
        ),
        baseUrl: 'http://10.0.2.2:8000/api',
      ),
    );

void main() {
  group('ApiPerhitunganService.setujui', () {
    test('422 profil_ditahan: kode, alasan, dan rujukan TM terbawa', () async {
      final hasil = await _layanan(
        _badan422,
        422,
      ).setujui('t', 30, nomorSertifikat: 'CAL/KT/H-proving_ring');

      expect(hasil.disetujui, isFalse);
      expect(hasil.butuhKonfirmasi, isFalse);
      expect(hasil.kode, KodeGalat.profilDitahan);

      final p = hasil.penahanan!;
      expect(p.ditahan, isTrue);
      expect(p.alasanTampil, _alasan);
      expect(p.rujukanTampil, 'TM-4');
      expect(p.varian, isEmpty);
    });

    test('kode lain di 422 tidak membawa penahanan', () async {
      final hasil = await _layanan({
        'kode': 'nomor_order_wajib',
        'message': 'Order Number belum diisi.',
      }, 422).setujui('t', 30);

      expect(hasil.kode, KodeGalat.nomorOrderWajib);
      expect(hasil.penahanan, isNull);
    });

    test(
      'status selain 422 tetap dilempar, bukan dianggap penahanan',
      () async {
        await expectLater(
          _layanan({'message': 'Server error'}, 500).setujui('t', 30),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}

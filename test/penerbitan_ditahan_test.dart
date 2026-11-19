import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/penerbitan_ditahan.dart';

/// Bentuk `penerbitan_ditahan` dari API NYATA (PR #280): uji kontrak app-API 19
/// Nov 2026 terhadap API lokal, `kontrak/hasil/dart-ditahan.json` langkah
/// DT-D-proving_ring (`GET /calibrations/30`), DT-P-proving_ring (`POST
/// /calibrations/30/approve` -> 422) dan DT-K-massa (`GET /categories/massa`).
/// Kontrak: `docs/perintah-frontend-tahan-profil.md` di repo API.
const _alasanProvingRing =
    'Proving Ring: U95 tercetak 2,3 kgf (pita 0 sampai 500 kgf lampiran '
    'LK-285-IDN), sedangkan master 22,4 kgf (pita 10 sampai 88 kN), sekitar '
    '10 kali lebih besar daripada sertifikat yang sudah pernah terbit. Pita '
    'CMC mana yang benar (G14) belum diputuskan';

Map<String, dynamic> _sesi(Object? penerbitanDitahan, {bool sertakan = true}) =>
    {
      'id': 30,
      'status': 'menunggu_approval',
      'equipment': {'id': 12, 'nama_alat': 'Proving Ring'},
      'teknisi': {'nama': 'Teknisi A Kontrak'},
      if (sertakan) 'penerbitan_ditahan': penerbitanDitahan,
    };

void main() {
  group('respons sesi (GET /calibrations/{id})', () {
    test('ditahan: alasan dan rujukan TM dibaca apa adanya dari server', () {
      final d = CalibrationDetail.fromJson(
        _sesi({
          'ditahan': true,
          'alasan': _alasanProvingRing,
          'rujukan_tm': 'TM-4',
        }),
      );

      expect(d.penerbitanDitahan.ditahan, isTrue);
      expect(d.penerbitanDitahan.alasanTampil, _alasanProvingRing);
      expect(d.penerbitanDitahan.rujukanTampil, 'TM-4');
      // Respons sesi tidak membawa `varian`.
      expect(d.penerbitanDitahan.varian, isEmpty);
    });

    test('tidak ditahan: ditahan false, alasan dan rujukan null', () {
      final d = CalibrationDetail.fromJson(
        _sesi({'ditahan': false, 'alasan': null, 'rujukan_tm': null}),
      );

      expect(d.penerbitanDitahan.ditahan, isFalse);
      expect(d.penerbitanDitahan.alasanTampil, isNull);
      expect(d.penerbitanDitahan.rujukanTampil, isNull);
    });

    test('server lama tanpa kunci = tidak ditahan (aturan 5 kontrak)', () {
      final d = CalibrationDetail.fromJson(_sesi(null, sertakan: false));

      expect(d.penerbitanDitahan.ditahan, isFalse);
      expect(identical(d.penerbitanDitahan, PenerbitanDitahan.tidak), isTrue);
    });

    test('bentuk aneh tidak menahan tombol dan tidak membuat crash', () {
      // Hanya `true` bool sungguhan yang menahan: tebakan app tidak boleh
      // menggantikan keputusan server.
      for (final aneh in <Object?>[
        'true',
        1,
        [true],
        {'ditahan': 'true'},
        {'ditahan': 1},
        {'ditahan': null},
        <String, dynamic>{},
      ]) {
        final d = CalibrationDetail.fromJson(_sesi(aneh));
        expect(d.penerbitanDitahan.ditahan, isFalse, reason: '$aneh');
      }
    });

    test('alasan spasi saja tidak dipajang', () {
      final d = CalibrationDetail.fromJson(
        _sesi({'ditahan': true, 'alasan': '   ', 'rujukan_tm': ''}),
      );

      expect(d.penerbitanDitahan.ditahan, isTrue);
      expect(d.penerbitanDitahan.alasanTampil, isNull);
      expect(d.penerbitanDitahan.rujukanTampil, isNull);
    });
  });

  group('baris kemampuan GET /categories/{kode}', () {
    test('Timbangan: hanya varian kg yang ditahan', () {
      final p = PenerbitanDitahan.fromJson({
        'ditahan': true,
        'alasan':
            'Timbangan kg: U95 bagian 7 (Weighing) tercetak 0,033 kg, '
            'sedangkan master 0,043 sampai 0,053 kg (sampai 37% lebih kecil '
            'dan tidak konservatif). Paraf TM untuk butir T2 belum ada.',
        'rujukan_tm': 'TM-1',
        'varian': ['kg'],
      });

      expect(p.ditahan, isTrue);
      expect(p.varian, ['kg']);
    });

    test('varian null = seluruh jenis alat (daftar kosong)', () {
      final p = PenerbitanDitahan.fromJson({
        'ditahan': true,
        'alasan': 'x',
        'rujukan_tm': 'TM-4',
        'varian': null,
      });

      expect(p.varian, isEmpty);
    });
  });

  group('badan 422 profil_ditahan', () {
    test('kuncinya datar dan penahanannya pasti true', () {
      final p = PenerbitanDitahan.dariBadan422({
        'kode': 'profil_ditahan',
        'message': 'Penerbitan sertifikat jenis alat ini ditahan ...',
        'profil': 'proving_ring',
        'varian': null,
        'rujukan_tm': 'TM-4',
        'alasan': _alasanProvingRing,
        'penahan': [
          {'penyimpangan': 'profil_ditahan', 'pesan': 'Ditahan ...'},
        ],
      });

      expect(p.ditahan, isTrue);
      expect(p.alasanTampil, _alasanProvingRing);
      expect(p.rujukanTampil, 'TM-4');
      expect(p.varian, isEmpty);
    });

    test('varian satu string (Timbangan) dibaca sebagai satu varian', () {
      final p = PenerbitanDitahan.dariBadan422({
        'kode': 'profil_ditahan',
        'varian': 'kg',
        'rujukan_tm': 'TM-1',
      });

      expect(p.varian, ['kg']);
    });

    test('badan tanpa alasan/rujukan tetap menahan dan tidak crash', () {
      final p = PenerbitanDitahan.dariBadan422({'kode': 'profil_ditahan'});

      expect(p.ditahan, isTrue);
      expect(p.alasanTampil, isNull);
      expect(p.rujukanTampil, isNull);
    });
  });
}

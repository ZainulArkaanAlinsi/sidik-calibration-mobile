import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/angka.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';

/// Conductivity Meter — satu-satunya alat yang **nyampur dua satuan dalam satu
/// lembar**, dan itu bikin tiga aturan yang nggak berlaku di empat alat lain.
///
/// Angka & bentuknya disalin dari respons API nyata
/// `GET /api/calibrations/lembar-kerja?profil=conductivity_meter`, bukan
/// dikarang — termasuk `satuan: null` di level lembar, yang justru itu inti
/// masalahnya.
void main() {
  /// Bentuk generik (tanpa `equipment_id`): 4 baris, titik tengah dikirim dalam
  /// DUA varian satuan buat dipilih.
  LembarKerja lembarGenerik() => LembarKerja.fromJson({
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
              {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'resolusi': 0.1, 'desimal': 1},
              {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm', 'resolusi': 1, 'desimal': 0, 'eksklusif_dengan': 1.412},
              {'titik_ukur': 1.412, 'label': '1,412', 'satuan': 'mS/cm', 'resolusi': 0.001, 'desimal': 3, 'eksklusif_dengan': 1412},
              {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'resolusi': 0.01, 'desimal': 2},
            ],
          },
        ],
      },
    ],
  });

  group('satuan mengikat per BARIS, bukan per lembar', () {
    test('lembar ngirim satuan kosong + penanda campuran', () {
      final lembar = lembarGenerik();

      expect(lembar.satuan, '');
      expect(lembar.satuanCampuran, isTrue);
    });

    /// Ini bug yang paling gampang kejadian: ngambil `lembar.satuan` bikin
    /// SELURUH kolom kelabel sama, dan titik 111 mS/cm kecetak sebagai µS/cm —
    /// beda seribu kali, di dokumen terakreditasi.
    test('tiap baris bawa satuannya sendiri', () {
      final lembar = lembarGenerik();
      final baris = lembar.bagian.first.tabel.first.baris;

      expect(baris.map(lembar.satuanUntuk).toList(), [
        'µS/cm',
        'µS/cm',
        'mS/cm',
        'mS/cm',
      ]);
    });

    /// Alat bersatuan seragam nggak boleh ikut berubah perilakunya.
    test('lembar TIDAK campur tetap pakai satuan lembar', () {
      final lembar = LembarKerja.fromJson({
        'satuan': 'NTU',
        'bagian': [
          {
            'kode': 'hasil',
            'tabel': [
              {
                'tahap': 'sesudah_adjustment',
                'baris': [
                  {'titik_ukur': 1, 'label': '1'},
                ],
                'kolom': [],
                'pengulangan': [1],
              },
            ],
          },
        ],
      });

      expect(lembar.satuanCampuran, isFalse);
      expect(lembar.satuanUntuk(lembar.bagian.first.tabel.first.baris.first), 'NTU');
    });
  });

  group('titik tengah saling meniadakan', () {
    test('dua varian nunjuk satu sama lain', () {
      final baris = lembarGenerik().bagian.first.tabel.first.baris;

      expect(baris[1].titikUkur, 1412);
      expect(baris[1].eksklusifDengan, 1.412);
      expect(baris[2].titikUkur, 1.412);
      expect(baris[2].eksklusifDengan, 1412);
    });

    /// Titik yang berdiri sendiri nggak boleh ikut kekunci.
    test('titik lain nggak punya pasangan', () {
      final baris = lembarGenerik().bagian.first.tabel.first.baris;

      expect(baris[0].eksklusifDengan, isNull);
      expect(baris[3].eksklusifDengan, isNull);
    });
  });

  group('suhu wajib', () {
    test('bendera datang dari API, bukan disimpulin dari nama alat', () {
      expect(lembarGenerik().suhuWajib, isTrue);

      // Alat lain: bendera nggak dikirim → default false, dan lembarnya tetap
      // bisa dikirim tanpa suhu seperti sebelumnya.
      expect(LembarKerja.fromJson({'satuan': 'NTU'}).suhuWajib, isFalse);
    });
  });

  /// Angka acuan QA dari `docs/handoff-frontend-conductivity.md` bagian 5,
  /// sesi `2405.32.A.NK`. Yang diuji di sini **formatnya**, bukan hitungannya —
  /// hitungannya punya backend dan udah dikunci `ConductivityBudgetTest`.
  ///
  /// Pembulatannya beda per titik (`0.0` / `0` / `0.00` di master), dan nol di
  /// belakang NGGAK boleh ilang: `25,0` tetap `25,0`, bukan `25`.
  group('format angka ngikut desimal per titik', () {
    test('tabel QA sesi 2405.32.A.NK', () {
      // titik 25 µS/cm — desimal 1
      expect(formatSertifikat(25.0, 1), '25,0');
      expect(formatSertifikat(25.04, 1), '25,0');
      expect(formatSertifikat(-0.04, 1), '-0,0');
      expect(formatSertifikat(0.49948652, 1), '0,5');

      // titik 1412 µS/cm — desimal 0
      expect(formatSertifikat(1412, 0), '1412');
      expect(formatSertifikat(1413, 0), '1413');
      expect(formatSertifikat(-1, 0), '-1');
      expect(formatSertifikat(8.10901195, 0), '8');

      // titik 111 mS/cm — desimal 2
      expect(formatSertifikat(111.193568, 2), '111,19');
      expect(formatSertifikat(110.674, 2), '110,67');
      expect(formatSertifikat(0.519568, 2), '0,52');
      expect(formatSertifikat(1.7, 2), '1,70');
    });

    /// Kolom Standard Value buang nol belakang di alat lain (Turbidimeter
    /// `1000`), TAPI di Conductivity `25,0` harus tetap `25,0` — nolnya itu
    /// resolusi alat, bukan hiasan.
    test('nol belakang dipertahankan di kolom hasil', () {
      expect(formatSertifikat(25.0, 1), isNot('25'));
      expect(formatSertifikat(1.7, 2), isNot('1,7'));
    });
  });
}

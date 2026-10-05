import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';

/// Draft dengan blok `spesifikasi_alat` BERSARANG dibuka ulang tanpa satu
/// angka pun berubah.
///
/// Laporan lapangan 5 Okt 2026: draft Anak Timbangan yang dibuka lagi
/// kehilangan kelas OIML, neraca, dan keenam ujung kondisi ruangan. Server
/// menyimpan blok itu bersarang (`{anak_timbangan: {suhu_awal: …}}`), sisi baca
/// HP menjadikannya satu teks `"{suhu_awal: …}"`, dan tidak ada kotak yang
/// cocok. Disimpan lagi, kekosongan itu yang terkirim.
void main() {
  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
    clientRequestId: 'uji-draft-bersarang',
  );

  const isianBlok = {
    'spesifikasi_alat.anak_timbangan.kelas_uut': 'M2',
    'spesifikasi_alat.anak_timbangan.kelas_standar': 'F1',
    'spesifikasi_alat.anak_timbangan.kapasitas_g': '2000',
    'spesifikasi_alat.anak_timbangan.suhu_awal': '23',
    'spesifikasi_alat.anak_timbangan.suhu_akhir': '22,1',
    'spesifikasi_alat.anak_timbangan.kelembaban_awal': '60,6',
    'spesifikasi_alat.anak_timbangan.kelembaban_akhir': '67,3',
    'spesifikasi_alat.anak_timbangan.tekanan_awal': '936,9',
    'spesifikasi_alat.anak_timbangan.tekanan_akhir': '937,0',
  };

  test('blok bersarang diratakan ke kunci bertitik, termasuk daftar', () {
    final datar = ratakanSpesifikasi({
      'rentang_ukur': '1 mg - 500 g',
      'kosong': null,
      'anak_timbangan': {
        'suhu_awal': 22.1,
        'kelas_uut': 'M2',
        'identitas': {'3': 'A*'},
      },
      'histeresis': {
        'baca1': [0.1, 0.2],
      },
    });

    expect(datar, {
      'rentang_ukur': '1 mg - 500 g',
      'anak_timbangan.suhu_awal': '22.1',
      'anak_timbangan.kelas_uut': 'M2',
      'anak_timbangan.identitas.3': 'A*',
      'histeresis.baca1.0': '0.1',
      'histeresis.baca1.1': '0.2',
    });
  });

  test('draft Anak Timbangan dibuka ulang: blok sesi utuh, payload sama', () {
    final asal = isianBaru();

    for (final e in isianBlok.entries) {
      final kotak = asal.teks[e.key];
      expect(kotak, isNotNull, reason: 'kotak ${e.key} tidak ada di lembar');
      kotak!.text = e.value;
    }

    final kirimAsal = asal.spesifikasiAlat;
    expect(
      (kirimAsal['anak_timbangan'] as Map)['suhu_akhir'],
      '22,1',
      reason: 'payload asal tidak membawa blok bersarang',
    );

    // Server memulangkan `spesifikasi_alat` apa adanya (kolom JSON).
    final dariServer = IsianTeknisi.fromJson({'spesifikasi_alat': kirimAsal});

    final pulih = isianBaru()..muatDariSesi(dariServer);

    for (final e in isianBlok.entries) {
      expect(
        pulih.teks[e.key]!.text,
        e.value,
        reason: '${e.key} berubah waktu draft dibuka ulang',
      );
    }

    expect(
      pulih.spesifikasiAlat,
      kirimAsal,
      reason: 'draft yang dibuka ulang mengirim spesifikasi yang beda',
    );
  });
}

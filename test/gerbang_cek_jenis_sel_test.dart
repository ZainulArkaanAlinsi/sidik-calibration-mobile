import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/cek_bacaan_kamera.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart'
    show contohBentukLembarKerja;
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Gerbang "wajib dicek" untuk tiga jenis sel selain tabel biasa: matriks
/// (Autoklaf), grid sensor (Enclosure), dan kolom isian (header / kondisi
/// ruang). Aturannya sama dengan `gerbang_cek_bacaan_test.dart`: perlu dicek
/// sampai dikonfirmasi pada sel itu atau nilainya diubah, satu sel per
/// konfirmasi, tahan muat ulang.
void main() {
  // ----------------------------------------------------------------- matriks

  group('matriks (Autoklaf)', () {
    MatriksHasil matriks() => MatriksHasil.fromJson({
      'judul_kolom': 'Pengukuran Berulang UUT',
      'titik_waktu': [1, 2, 3],
      'baris_waktu': {
        'kode': 'waktu',
        'label': 'Time',
        'tipe': 'jam',
        'format': 'HH:mm:ss',
        'kode_data': 'waktu',
      },
      'baris': [
        {'kode': 'disk_1', 'label': 'Temp. Disk 1', 'kode_data': 'suhu.disk.0'},
        {'kode': 'disk_2', 'label': 'Temp. Disk 2', 'kode_data': 'suhu.disk.1'},
      ],
    })!;

    LembarKerjaState state() => LembarKerjaState(
      bentuk: LembarKerja.fromJson({
        'judul': 'Uji matriks',
        'jumlah_pengulangan': 3,
        'satuan': null,
        'bagian': [
          {
            'kode': 'hasil_pengukuran',
            'halaman': 1,
            'judul': 'Calibration Result',
            'field': [
              {'kode': 'set_point', 'label': 'Set Point', 'tipe': 'angka'},
            ],
          },
        ],
      }),
      clientRequestId: 'uji-cek-matriks',
    );

    SelTabelFoto sel(MatriksHasil m, String kodeData, int waktu, String teks) {
      final i = m.semuaBaris.indexWhere((b) => b.kodeData == kodeData);

      return (
        titikUkur: MatriksHasil.kunciBarisFoto(i),
        repeatNo: waktu,
        fieldId: 'pembacaan',
        teks: teks,
        keyakinan: 0.97,
      );
    }

    LembarKerjaState dariFoto() {
      final m = matriks();
      final s = state();
      final terisi = s.terapkanHasilFotoMatriks(m, [
        sel(m, 'suhu.disk.0', 1, '121,4'),
        sel(m, 'suhu.disk.0', 2, '121,6'),
        sel(m, 'suhu.disk.1', 1, '120,9'),
      ]);
      expect(terisi, 3, reason: 'prasyarat');

      return s;
    }

    test('sel foto matriks = perlu dicek; konfirmasi hanya satu sel', () {
      final s = dariFoto();

      expect(s.jumlahPerluCek, 3);
      expect(s.daftarSelCek().map((x) => x.jenis).toSet(), {
        JenisSelCek.matriks,
      });

      expect(s.konfirmasiSelCek('matriks|suhu.disk.0#2'), isTrue);

      final status = {for (final x in s.daftarSelCek()) x.kunci: x.status};
      expect(status['matriks|suhu.disk.0#2'], StatusCekSel.sudahDicek);
      expect(status['matriks|suhu.disk.0#1'], StatusCekSel.perluCek);
      expect(status['matriks|suhu.disk.1#1'], StatusCekSel.perluCek);
    });

    test('mengubah angka = dicek; mengosongkan = tidak dihitung', () {
      final s = dariFoto();

      s.kotakMatriks('suhu.disk.0', 1).text = '121,9';
      expect(s.jumlahPerluCek, 2);

      s.kotakMatriks('suhu.disk.1', 1).text = '';
      expect(s.jumlahPerluCek, 1);
    });

    test('tahan muat ulang', () {
      final s = dariFoto()..konfirmasiSelCek('matriks|suhu.disk.0#2');
      final baru = state()..pulihkanSalinanLokal(s.salinanLokal());

      expect(baru.jumlahPerluCek, 2);
      expect(
        baru.daftarSelCek().map((x) => x.status),
        contains(StatusCekSel.sudahDicek),
      );
    });

    test('pemantau reaktif hanya untuk sel foto', () {
      final s = dariFoto();

      expect(s.pemantauCekMatriks('suhu.disk.0', 1), isNotNull);
      expect(s.pemantauCekMatriks('suhu.disk.1', 3), isNull);
    });
  });

  // -------------------------------------------------------------------- grid

  group('grid sensor (Enclosure)', () {
    LembarKerjaState state() => LembarKerjaState(
      bentuk: LembarKerja.fromJson({
        'judul': 'Uji grid',
        'jumlah_pengulangan': 3,
        'satuan': null,
        'bagian': [
          {
            'kode': 'identitas',
            'halaman': 1,
            'judul': 'Identitas',
            'field': [
              {'kode': 'catatan_teknisi', 'label': 'Catatan', 'tipe': 'teks'},
            ],
          },
        ],
        'grid_sensor': {
          'pengulangan': [1, 2, 3],
          'jumlah_sensor_saran': 2,
          'baris_indikator': true,
          'baris_suhu_ruang': false,
        },
      }),
      clientRequestId: 'uji-cek-grid',
    );

    LembarKerjaState dariFoto() {
      final s = state();
      final sp = s.grid!.setPoint.first;
      final terisi = sp.terapkanHasilFotoPosisi([
        (barisKe: 1, repeatNo: 1, teks: '100,2', keyakinan: 0.95),
        (barisKe: 1, repeatNo: 2, teks: '100,4', keyakinan: 0.95),
        (barisKe: 3, repeatNo: 1, teks: '99,9', keyakinan: 0.95),
      ]);
      expect(terisi, 3, reason: 'prasyarat: dua termokopel + indikator');

      return s;
    }

    test('sel foto grid = perlu dicek; konfirmasi hanya satu sel', () {
      final s = dariFoto();

      expect(s.jumlahPerluCek, 3);
      expect(s.daftarSelCek().map((x) => x.jenis).toSet(), {JenisSelCek.grid});

      final pertama = s.selCekBerikutnya()!;
      expect(s.konfirmasiSelCek(pertama.kunci), isTrue);

      expect(s.jumlahPerluCek, 2);
    });

    test('mengubah angka di sel grid = dicek', () {
      final s = dariFoto();
      final sp = s.grid!.setPoint.first;

      sp.sensor.first.pembacaanCtl[0].text = '100,9';

      expect(s.jumlahPerluCek, 2);
    });

    test('nomor termokopel dari foto ikut digerbang', () {
      final s = state();
      final sp = s.grid!.setPoint.first;
      sp.sensor.first.noCtl.text = '3';
      sp.sensor.first.noDariFoto = true;
      sp.sensor.first.cek.tandai('no', '3');

      expect(s.jumlahPerluCek, 1);
      expect(s.daftarSelCek().single.peranGrid, PeranSelGrid.nomorTermokopel);

      sp.sensor.first.noCtl.text = '5';
      expect(s.jumlahPerluCek, 0);
    });

    test('tahan muat ulang, termasuk sel yang sudah dicek', () {
      final s = dariFoto();
      s.konfirmasiSelCek(s.selCekBerikutnya()!.kunci);

      final baru = state()..pulihkanSalinanLokal(s.salinanLokal());

      expect(baru.jumlahPerluCek, 2);
      expect(
        baru.daftarSelCek().map((x) => x.status),
        contains(StatusCekSel.sudahDicek),
      );
    });

    test('foto grid per set point: lembar tercatat berisi bacaan kamera', () {
      final s = dariFoto();

      expect(
        s.adaIsianDariFoto,
        isFalse,
        reason: 'jalur foto grid tidak menyalakan bendera lama',
      );
      expect(s.adaBacaanKamera, isTrue);
    });

    test('sasaran lompat sel grid sama dengan kode yang dipasang widget', () {
      final s = dariFoto();
      final sel = s.daftarSelCek().first;

      expect(
        sel.sasaranLompat,
        LembarKerjaState.kodeLompatGrid(0, 't', 0, 0),
        reason: 'set point 1, termokopel 1, repeat index 0',
      );
    });
  });

  // ------------------------------------------------------------------ isian

  group('kolom isian dari foto', () {
    LembarKerjaState state() => LembarKerjaState(
      bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
      clientRequestId: 'uji-cek-isian',
    );

    test('angka header dari foto = perlu dicek (dulu masuk tanpa tanda)', () {
      final s = state();

      final terisi = s.terapkanIsianFotoAsli({'suhu_awal': '25,1'});
      expect(terisi, 1, reason: 'prasyarat: pH punya kolom suhu_awal');

      expect(s.isianDariFoto, {'suhu_awal'});
      expect(s.jumlahPerluCek, 1);
      expect(s.daftarSelCek().single.jenis, JenisSelCek.isian);
      expect(s.pemantauCekIsian('suhu_awal'), isNotNull);
      expect(s.pemantauCekIsian('suhu_akhir'), isNull);
    });

    test('konfirmasi atau ubah angka melepas gerbang; salinan tahan', () {
      final s = state()..terapkanIsianFotoAsli({'suhu_awal': '25,1'});

      final baru = state()..pulihkanSalinanLokal(s.salinanLokal());
      expect(baru.jumlahPerluCek, 1, reason: 'tahan muat ulang');

      expect(baru.konfirmasiSelCek('isian|suhu_awal'), isTrue);
      expect(baru.jumlahPerluCek, 0);

      s.teks['suhu_awal']!.text = '25,4';
      expect(s.jumlahPerluCek, 0);
    });

    test('kolom yang sudah berisi tidak ditimpa dan tidak ditandai', () {
      final s = state();
      s.teks['suhu_awal']!.text = '22,0';

      expect(s.terapkanIsianFotoAsli({'suhu_awal': '25,1'}), 0);
      expect(s.isianDariFoto, isEmpty);
      expect(s.jumlahPerluCek, 0);
    });
  });
}

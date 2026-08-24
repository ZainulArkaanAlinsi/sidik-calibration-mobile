import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';

/// Grid termokopel Enclosure mendarat di bentuk payload yang benar.
///
/// Bentuk acuannya disalin apa adanya dari `docs/perintah-frontend-enclosure.md`
/// §4 di repo API — bukan dikarang ulang di sini. Yang diuji bukan "kodenya
/// jalan", tapi tiga hal yang kalau meleset TIDAK menghasilkan error apa pun
/// dan tetap sampai ke sertifikat:
///
///  1. **Sel kosong tetap `null` di posisinya.** Kalau Repeat 2 kosong lalu
///     dibuang, Repeat 3 naik jadi Repeat 2 dan seluruh nomor pengulangan
///     geser satu.
///  2. **Sensor Acuan = nomor TERKECIL, bukan baris pertama.** Keseragaman
///     diukur relatif ke sensor itu; salah acuan menggeser seluruh kolom
///     Keseragaman yang tercetak. Pada grid contoh selisihnya bisa 2×.
///  3. **Baris Suhu Ruang ikut dikirim, dan nggak ikut ngitung.** Dulu dibuang
///     di sini karena backend belum punya tempat menampungnya. Sekarang
///     tempatnya ada (`peran_sensor = 'suhu_ruang'`), jadi yang dijaga
///     berubah: angkanya harus SAMPAI, dan set point yang cuma punya baris itu
///     nggak boleh dianggap kosong lalu kebuang diam-diam.
void main() {
  GridSensorBentuk bentuk({String? butuhChannel = 'recorder'}) =>
      GridSensorBentuk.fromJson({
        'jumlah_sensor_saran': 9,
        'pengulangan': [1, 2, 3, 4, 5],
        'butuh_channel_untuk': butuhChannel,
        'baris_indikator': true,
        'baris_suhu_ruang': true,
        'catatan_sensor_acuan':
            'Sensor Acuan = termokopel bernomor TERKECIL yang terisi.',
      })!;

  /// Isi satu baris sensor: nomor, kanal (opsional), lalu pembacaannya.
  void isi(
    BarisSensorState s, {
    required int no,
    int? channel,
    required List<String> baca,
  }) {
    s.noCtl.text = '$no';
    if (channel != null) s.channelCtl.text = '$channel';
    for (var i = 0; i < baca.length && i < s.pembacaanCtl.length; i++) {
      s.pembacaanCtl[i].text = baca[i];
    }
  }

  void isiDeret(BarisDeretState b, List<String> nilai) {
    for (var i = 0; i < nilai.length && i < b.ctl.length; i++) {
      b.ctl[i].text = nilai[i];
    }
  }

  group('bentuk grid_sensor dari backend', () {
    test('terbaca lengkap', () {
      final g = bentuk();

      expect(g.jumlahSensorSaran, 9);
      expect(g.pengulangan, [1, 2, 3, 4, 5]);
      expect(g.barisIndikator, isTrue);
      expect(g.barisSuhuRuang, isTrue);
      expect(g.catatanSensorAcuan, contains('TERKECIL'));
    });

    test('butuhChannel cocok lewat isi nama merk, bukan sama persis', () {
      final g = bentuk();

      // `standards.merk` di lapangan berbunyi "Graphtech Temperature Recorder",
      // bukan persis "recorder".
      expect(g.butuhChannel('Graphtech Temperature Recorder'), isTrue);
      expect(g.butuhChannel('RECORDER'), isTrue);
      expect(g.butuhChannel('Constant'), isFalse);
      expect(g.butuhChannel('Yokogawa'), isFalse);

      // Belum milih standar bukan berarti "nggak butuh kanal" — tapi kolomnya
      // memang belum bisa digambar sebelum merk-nya ketahuan.
      expect(g.butuhChannel(null), isFalse);
      expect(g.butuhChannel('  '), isFalse);
    });

    test('pengulangan kosong bikin bentuknya ditolak, bukan grid nol kolom', () {
      expect(
        GridSensorBentuk.fromJson({'pengulangan': <dynamic>[]}),
        isNull,
      );
    });
  });

  group('payload', () {
    test('bentuknya persis kontrak backend', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';

      isi(
        sp.sensor[0],
        no: 3,
        baca: ['15.0', '15.1', '15.1', '15.1', '15.1'],
      );
      isi(
        sp.sensor[1],
        no: 4,
        baca: ['15.2', '15.3', '15.2', '15.3', '15.2'],
      );
      isiDeret(sp.indikator, ['15.0', '15.0', '15.0', '15.0', '15.0']);

      state.bacaUlang();
      final payload = state.payload(satuan: '°C', pakaiChannel: false);

      expect(payload, hasLength(1));
      expect(payload.first['titik_ukur'], 15.0);
      expect(payload.first['satuan'], '°C');
      expect(payload.first['indikator'], [15.0, 15.0, 15.0, 15.0, 15.0]);

      final grid = payload.first['sensor_grid'] as List<dynamic>;
      expect(grid, hasLength(2));
      expect(grid[0], {
        'no': 3,
        'pembacaan': [15.0, 15.1, 15.1, 15.1, 15.1],
      });
      expect(grid[1], {
        'no': 4,
        'pembacaan': [15.2, 15.3, 15.2, 15.3, 15.2],
      });
    });

    test('channel ikut cuma kalau kalibratornya berkanal', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '66.8';
      isi(
        sp.sensor[0],
        no: 1,
        channel: 1,
        baca: ['66.8', '66.81', '66.82', '66.81', '66.8'],
      );
      isiDeret(sp.indikator, ['66.8', '66.8', '66.8', '66.8', '66.8']);
      state.bacaUlang();

      final dengan = state.payload(satuan: '°C', pakaiChannel: true);
      expect((dengan.first['sensor_grid'] as List).first, {
        'no': 1,
        'channel': 1,
        'pembacaan': [66.8, 66.81, 66.82, 66.81, 66.8],
      });

      final tanpa = state.payload(satuan: '°C', pakaiChannel: false);
      expect(
        (tanpa.first['sensor_grid'] as List).first,
        isNot(contains('channel')),
      );
    });

    test('sel kosong tetap null di posisinya — nomor pengulangan nggak geser', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '100';
      // Repeat 2 sengaja dikosongkan.
      isi(sp.sensor[0], no: 3, baca: ['15.0', '', '15.1', '15.2', '15.3']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      final grid =
          state.payload(satuan: '°C', pakaiChannel: false).first['sensor_grid']
              as List<dynamic>;

      expect((grid.first as Map)['pembacaan'], [15.0, null, 15.1, 15.2, 15.3]);
    });

    test('koma dibaca sebagai desimal — papan tombol HP mengetik koma', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15,5';
      isi(sp.sensor[0], no: 3, baca: ['15,1', '15,2', '15,3', '15,4']);
      isiDeret(sp.indikator, ['15,0']);
      state.bacaUlang();

      final entri = state.payload(satuan: '°C', pakaiChannel: false).first;
      expect(entri['titik_ukur'], 15.5);
      expect((entri['sensor_grid'] as List).first, {
        'no': 3,
        'pembacaan': [15.1, 15.2, 15.3, 15.4, null],
      });
    });

    test('baris Suhu Ruang ikut dikirim, sejajar per pengulangan', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isiDeret(sp.indikator, ['15.0', '15.0', '15.0', '15.0']);
      isiDeret(sp.suhuRuang, ['24.5', '24.5', '24.6', '24.6']);
      state.bacaUlang();

      final entri = state.payload(satuan: '°C', pakaiChannel: false).first;
      expect(entri['suhu_ruang'], [24.5, 24.5, 24.6, 24.6, null]);
      expect(entri.keys, unorderedEquals([
        'titik_ukur',
        'satuan',
        'sensor_grid',
        'indikator',
        'suhu_ruang',
      ]));
    });

    test('Suhu Ruang kosong nggak bikin kunci kosong ikut kekirim', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isiDeret(sp.indikator, ['15.0', '15.0', '15.0', '15.0']);
      state.bacaUlang();

      expect(
        state.payload(satuan: '°C', pakaiChannel: false).first.keys,
        isNot(contains('suhu_ruang')),
      );
    });

    /// Set point yang BARU keisi baris Suhu Ruang nggak boleh dianggap kosong.
    ///
    /// Ini pengulangan bug yang dulu kena baris Indikator. Bahayanya bukan
    /// "nggak kekirim": `store()` di backend menghapus pembacaan lama SEBELUM
    /// menyusun yang baru, jadi set point yang kesaring di sini bikin angka
    /// lama ikut hilang permanen.
    test('set point yang cuma punya Suhu Ruang tetap dikirim', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isiDeret(sp.suhuRuang, ['24.5', '24.6']);
      state.bacaUlang();

      final hasil = state.payload(satuan: '°C', pakaiChannel: false);
      expect(hasil, hasLength(1));
      expect(hasil.first['suhu_ruang'], [24.5, 24.6, null, null, null]);
    });

    test('set point yang belum disentuh nggak dikirim', () {
      final state = GridSensorState(bentuk: bentuk());
      state.tambahSetPoint();

      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(state.setPoint, hasLength(2));
      expect(state.payload(satuan: '°C', pakaiChannel: false), hasLength(1));
    });

    test('sensor tanpa nomor nggak ikut — koreksinya nggak bisa dicari', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      // Baris kedua diisi angka tapi nomornya lupa.
      for (var i = 0; i < 4; i++) {
        sp.sensor[1].pembacaanCtl[i].text = '15.5';
      }
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      final grid =
          state.payload(satuan: '°C', pakaiChannel: false).first['sensor_grid']
              as List<dynamic>;
      expect(grid, hasLength(1));
      expect((grid.first as Map)['no'], 3);
    });
  });

  group('Sensor Acuan', () {
    test('nomor TERKECIL, bukan baris pertama', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;

      // Sengaja diisi TIDAK urut: baris pertama nomor 11, baris ketiga nomor 3.
      isi(sp.sensor[0], no: 11, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 7, baca: ['15.2', '15.2', '15.3', '15.3']);
      isi(sp.sensor[2], no: 3, baca: ['15.4', '15.4', '15.5', '15.5']);
      state.bacaUlang();

      expect(sp.nomorAcuan, 3);
    });

    test('pindah ke nomor berikutnya kalau yang terkecil dikosongkan', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 4, baca: ['15.2', '15.2', '15.3', '15.3']);
      state.bacaUlang();
      expect(sp.nomorAcuan, 3);

      for (final c in sp.sensor[0].pembacaanCtl) {
        c.text = '';
      }
      state.bacaUlang();
      expect(sp.nomorAcuan, 4);
    });

    test('null kalau belum ada sensor terisi', () {
      final state = GridSensorState(bentuk: bentuk());
      expect(state.setPoint.first.nomorAcuan, isNull);
    });
  });

  group('peringatan pra-kirim', () {
    test('pembacaan kurang dari 4 ditandai sebelum dikirim', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 4, baca: ['15.2', '15.2']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(sp.sensor[1].pembacaanKurang, isTrue);
      expect(sp.sensor[0].pembacaanKurang, isFalse);
      expect(
        state.peringatan('Constant').join(' '),
        allOf(contains('kurang dari 4'), contains('no. 4')),
      );
    });

    test('satu termokopel saja diperingatkan — Keseragaman keluar 0,0', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(state.peringatan('Constant').join(' '), contains('Minimal 2'));
    });

    test('nomor kembar dalam satu set point diperingatkan', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 3, baca: ['15.2', '15.2', '15.3', '15.3']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(sp.nomorKembar, [3]);
      expect(state.peringatan('Constant').join(' '), contains('kembar'));
    });

    test('nomor yang sama di set point LAIN normal, bukan kembar', () {
      final state = GridSensorState(bentuk: bentuk());
      state.tambahSetPoint();

      for (final sp in state.setPoint) {
        isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
        isi(sp.sensor[1], no: 4, baca: ['15.2', '15.2', '15.3', '15.3']);
        isiDeret(sp.indikator, ['15.0']);
      }
      state.bacaUlang();

      expect(state.setPoint[0].nomorKembar, isEmpty);
      expect(state.setPoint[1].nomorKembar, isEmpty);
      expect(state.peringatan('Constant'), isEmpty);
    });

    test('Recorder tanpa channel diperingatkan; Constant tidak', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 1, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 2, baca: ['15.2', '15.2', '15.3', '15.3']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(
        state.peringatan('Graphtech Temperature Recorder').join(' '),
        contains('Channel wajib'),
      );
      expect(state.peringatan('Constant'), isEmpty);
    });

    test('Indikator kosong diperingatkan — nggak ada bahan buat budget', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 4, baca: ['15.2', '15.2', '15.3', '15.3']);
      state.bacaUlang();

      expect(
        state.peringatan('Constant').join(' '),
        contains('Indikator masih kosong'),
      );
    });

    test('set point kosong nggak ikut diperingatkan', () {
      final state = GridSensorState(bentuk: bentuk());
      state.tambahSetPoint();

      final sp = state.setPoint.first;
      sp.titikCtl.text = '15';
      isi(sp.sensor[0], no: 3, baca: ['15.0', '15.1', '15.1', '15.1']);
      isi(sp.sensor[1], no: 4, baca: ['15.2', '15.2', '15.3', '15.3']);
      isiDeret(sp.indikator, ['15.0']);
      state.bacaUlang();

      expect(state.peringatan('Constant'), isEmpty);
    });
  });

  group('tambah & hapus baris', () {
    test('jumlah sensor awal ikut saran backend', () {
      final state = GridSensorState(bentuk: bentuk());
      expect(state.setPoint.first.sensor, hasLength(9));
    });

    test('tambah & hapus termokopel', () {
      final state = GridSensorState(bentuk: bentuk());
      final sp = state.setPoint.first;

      sp.tambahSensor();
      expect(sp.sensor, hasLength(10));

      sp.hapusSensor(0);
      expect(sp.sensor, hasLength(9));

      // Indeks di luar jangkauan nggak boleh melempar — tombol hapus bisa
      // kepencet dua kali sebelum layar sempat digambar ulang.
      sp.hapusSensor(99);
      sp.hapusSensor(-1);
      expect(sp.sensor, hasLength(9));
    });

    test('hapus set point terakhir nggak menyisakan daftar kosong di layar', () {
      final state = GridSensorState(bentuk: bentuk());
      state.tambahSetPoint();
      expect(state.setPoint, hasLength(2));

      state.hapusSetPoint(1);
      expect(state.setPoint, hasLength(1));

      state.hapusSetPoint(5);
      expect(state.setPoint, hasLength(1));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Sesi Enclosure yang dikembalikan admin balik dengan GRID-nya utuh.
///
/// ## Kegagalan yang ditutup berkas ini
///
/// Sepuluh lembar bertabel datar pulih lewat `terapkanPembacaan()` sejak lama:
/// dicocokin per titik ukur, angkanya masuk ke kolom `pembacaan`/`suhu`.
///
/// Lembar Enclosure nggak punya kolom itu. Angkanya duduk di sel
/// (set point, sensor ke-N, repeat ke-M) di dalam grid termokopel — dan sampai
/// 26 Agt 2026 nggak ada satu baris pun kode yang naruhnya ke sana. Jadi
/// teknisi yang lembarnya dikembalikan dapat grid KOSONG dan ngetik ulang
/// 9 termokopel x 5 repeat x tiap set point: 180 sel buat sesi Inkubator
/// 4 set point, termasuk angka yang udah bener.
///
/// Bahayanya bukan capeknya. Yang kekirim balik ke admin cuma sisa yang sempat
/// diketik ulang, dan sel yang kelewat nggak ninggalin jejak apa pun.
///
/// ## Yang paling mahal kalau meleset
///
/// Grid Enclosure nggak cuma termokopel — baris **Suhu Ruang** duduk di tabel
/// yang sama dengan peran yang beda, dan angkanya sepantaran (25 °C di sebelah
/// setpoint 30 °C). Menaruhnya di kotak termokopel bikin dia mendarat di sel
/// yang salah: bentuknya wajar, tempatnya salah, dan **nol** yang bakal teriak.
/// Makanya perannya diuji satu-satu di bawah, bukan cuma "gridnya keisi".
void main() {
  /// Bentuk lembar Enclosure — disalin dari `EnclosureProfileBase` di repo API.
  /// Sengaja tanpa `tabel`: lembar ini emang cuma ngirim kolom identitas plus
  /// `grid_sensor`.
  LembarKerja lembarEnclosure() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-IK-CAL-0512_Rev.2',
    'judul': 'Calibration Worksheet - Enclosure (Inkubator)',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': '°C',
    'satuan_suhu': '°C',
    'grid_sensor': {
      'jumlah_sensor_saran': 9,
      'pengulangan': [1, 2, 3, 4, 5],
      'butuh_channel_untuk': 'recorder',
      'baris_indikator': true,
      'baris_suhu_ruang': true,
      'catatan_sensor_acuan':
          'Sensor Acuan = termokopel bernomor TERKECIL yang terisi.',
    },
    'bagian': [
      {
        'kode': 'identitas_alat',
        'judul': 'Identitas Alat',
        'field': [
          {'kode': 'alat_model', 'label': 'Model', 'tipe': 'teks'},
        ],
      },
    ],
  });

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: lembarEnclosure(),
    clientRequestId: 'tes-pulih-grid',
  );

  var nomorBaris = 0;

  /// Satu baris `pembacaan_mentah` ber-grid, seperti yang dikirim
  /// `GET /api/calibrations/{id}` sesudah `CalibrationResource` mulangin
  /// `sensor_ke`/`peran_sensor`/`channel`.
  RawMeasurement grid({
    required double titikUkur,
    required String peran,
    required int pembacaanKe,
    required double pembacaan,
    int? sensorKe,
    int? channel,
  }) => RawMeasurement(
    id: ++nomorBaris,
    titikKe: 1,
    titikUkur: titikUkur,
    pembacaanKe: pembacaanKe,
    pembacaan: pembacaan,
    sensorKe: sensorKe,
    peranSensor: peran,
    channel: channel,
    inputSource: 'manual',
    isVerified: true,
  );

  /// Baris termokopel bernomor [no] di set point [sp] — dicari lewat NOMOR,
  /// bukan posisi, persis seperti kode produksinya.
  BarisSensorState sensor(SetPointGridState sp, int no) =>
      sp.sensor.firstWhere((s) => s.no == no);

  List<String> baca(BarisSensorState s) =>
      s.pembacaanCtl.map((c) => c.text).toList();

  List<String> bacaDeret(BarisDeretState b) => b.ctl.map((c) => c.text).toList();

  /// Sesi Inkubator dua set point: dua termokopel + Indikator + Suhu Ruang.
  List<RawMeasurement> sesiDuaSetPoint() => [
    // Set point 30 °C
    grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 1, pembacaan: 30.1),
    grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 2, pembacaan: 30.2),
    grid(titikUkur: 30, peran: 'termokopel', sensorKe: 4, pembacaanKe: 1, pembacaan: 29.9),
    grid(titikUkur: 30, peran: 'indikator', pembacaanKe: 1, pembacaan: 30.0),
    grid(titikUkur: 30, peran: 'suhu_ruang', pembacaanKe: 1, pembacaan: 25.4),
    // Set point 45 °C
    grid(titikUkur: 45, peran: 'termokopel', sensorKe: 3, pembacaanKe: 1, pembacaan: 45.3),
    grid(titikUkur: 45, peran: 'indikator', pembacaanKe: 1, pembacaan: 45.1),
  ];

  group('grid Enclosure pulih', () {
    test('angka mendarat di sel (set point, sensor, repeat) yang benar', () {
      final isian = isianBaru();

      final kebuang = isian.terapkanPembacaan(sesiDuaSetPoint());

      expect(kebuang, 0, reason: 'Nggak ada baris yang boleh kebuang.');

      final g = isian.grid!;
      expect(g.setPoint.length, 2, reason: 'Dua set point, bukan satu ditimpa.');

      final sp30 = g.setPoint.firstWhere((sp) => sp.titikUkur == 30);
      final sp45 = g.setPoint.firstWhere((sp) => sp.titikUkur == 45);

      expect(baca(sensor(sp30, 3)), ['30.1', '30.2', '', '', '']);
      expect(baca(sensor(sp30, 4)), ['29.9', '', '', '', '']);
      expect(baca(sensor(sp45, 3)), ['45.3', '', '', '', '']);
    });

    test('Suhu Ruang mendarat di barisnya sendiri, BUKAN di kotak termokopel', () {
      final isian = isianBaru();

      isian.terapkanPembacaan(sesiDuaSetPoint());

      final sp30 = isian.grid!.setPoint.firstWhere((sp) => sp.titikUkur == 30);

      expect(bacaDeret(sp30.suhuRuang), ['25.4', '', '', '', '']);
      expect(bacaDeret(sp30.indikator), ['30', '', '', '', '']);

      // Dan yang paling penting: nggak nyasar ke mana-mana. 25,4 di kotak
      // termokopel set point 30 °C kelihatan wajar dan bikin Keseragaman
      // meleset 4,6 °C tanpa satu pun peringatan.
      for (final s in sp30.sensor) {
        expect(baca(s), isNot(contains('25.4')));
      }
    });

    test('nomor kanal recorder ikut pulih', () {
      final isian = isianBaru();

      isian.terapkanPembacaan([
        grid(titikUkur: 70, peran: 'termokopel', sensorKe: 1, channel: 1, pembacaanKe: 1, pembacaan: 66.8),
        grid(titikUkur: 70, peran: 'termokopel', sensorKe: 2, channel: 2, pembacaanKe: 1, pembacaan: 67.85),
      ]);

      final sp = isian.grid!.setPoint.first;

      expect(sensor(sp, 1).channelCtl.text, '1');
      expect(sensor(sp, 2).channelCtl.text, '2');
    });

    test('barisnya kebaca SEKARANG, bukan sesudah teknisi ngetuk satu sel', () {
      final isian = isianBaru();

      isian.terapkanPembacaan(sesiDuaSetPoint());

      final sp30 = isian.grid!.setPoint.firstWhere((sp) => sp.titikUkur == 30);

      // `sensorTerisi`, lencana Sensor Acuan, dan daftar peringatan semuanya
      // baca `pembacaan` hasil parse — bukan teks kotaknya. Tanpa `bacaUlang()`
      // teknisi ngeliat grid penuh angka sambil diomongin "belum ada termokopel
      // yang diisi".
      expect(sp30.sensorTerisi.length, 2);
      expect(sp30.nomorAcuan, 3);
      expect(sp30.kosongSemua, isFalse);
      expect(isian.grid!.setPointTerisi.length, 2);
    });

    test('sel yang udah diketik teknisi nggak ditimpa', () {
      final isian = isianBaru();

      final sp = isian.grid!.setPoint.first;
      sp.titikCtl.text = '30';
      sp.sensor.first.noCtl.text = '3';
      sp.sensor.first.pembacaanCtl[0].text = '31.9';

      isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 1, pembacaan: 30.1),
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 2, pembacaan: 30.2),
      ]);

      // Yang barusan diketik menang; yang kosong keisi dari server.
      expect(baca(sensor(sp, 3)), ['31.9', '30.2', '', '', '']);
      expect(isian.grid!.setPoint.length, 1, reason: 'Set point 30 dipakai ulang.');
    });

    test('peran yang belum dikenal dibuang, bukan ditaruh di kotak terdekat', () {
      final isian = isianBaru();

      final kebuang = isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 1, pembacaan: 30.1),
        grid(titikUkur: 30, peran: 'kelembapan_chamber', pembacaanKe: 1, pembacaan: 61.2),
      ]);

      expect(kebuang, 1);

      final sp = isian.grid!.setPoint.first;

      for (final s in sp.sensor) {
        expect(baca(s), isNot(contains('61.2')));
      }
      expect(bacaDeret(sp.indikator), isNot(contains('61.2')));
      expect(bacaDeret(sp.suhuRuang), isNot(contains('61.2')));
    });

    test('termokopel tanpa nomor dibuang — nomornya yang nentuin koreksi', () {
      final isian = isianBaru();

      final kebuang = isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', pembacaanKe: 1, pembacaan: 30.1),
      ]);

      expect(kebuang, 1);
      expect(isian.grid!.setPointTerisi, isEmpty);
    });

    test('repeat di luar jumlah kolom dibuang, bukan digeser', () {
      final isian = isianBaru();

      final kebuang = isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 9, pembacaan: 30.9),
      ]);

      expect(kebuang, 1);
    });

    test('pulih lalu dikirim ulang = payload yang sama', () {
      final isian = isianBaru();

      isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, channel: 3, pembacaanKe: 1, pembacaan: 30.1),
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, channel: 3, pembacaanKe: 2, pembacaan: 30.2),
        grid(titikUkur: 30, peran: 'indikator', pembacaanKe: 1, pembacaan: 30.0),
        grid(titikUkur: 30, peran: 'suhu_ruang', pembacaanKe: 1, pembacaan: 25.4),
      ]);

      final payload = isian.grid!.payload(satuan: '°C', pakaiChannel: true);

      expect(payload, [
        {
          'titik_ukur': 30.0,
          'satuan': '°C',
          'sensor_grid': [
            {
              'no': 3,
              'channel': 3,
              'pembacaan': [30.1, 30.2, null, null, null],
            },
          ],
          'indikator': [30.0, null, null, null, null],
          'suhu_ruang': [25.4, null, null, null, null],
        },
      ]);
    });

    test('lembar TANPA grid: baris ber-peran dihitung kebuang, nggak dipaksa masuk', () {
      // Layar kebuka dengan profil yang beda dari sesinya. Seluruh lembarnya
      // emang salah — jadi diam bukan pilihan, teknisinya wajib diomongin.
      final isian = LembarKerjaState(
        bentuk: LembarKerja.fromJson({
          'kode_dokumen': 'SIDIK-IK-CAL-0501_Rev.8',
          'judul': 'Calibration Worksheet - pH Meter',
          'untuk': 'teknisi',
          'jumlah_pengulangan': 5,
          'bagian': <dynamic>[],
        }),
        clientRequestId: 'tes-tanpa-grid',
      );

      expect(isian.grid, isNull);

      final kebuang = isian.terapkanPembacaan([
        grid(titikUkur: 30, peran: 'termokopel', sensorKe: 3, pembacaanKe: 1, pembacaan: 30.1),
        grid(titikUkur: 30, peran: 'indikator', pembacaanKe: 1, pembacaan: 30.0),
      ]);

      expect(kebuang, 2);
    });
  });
}

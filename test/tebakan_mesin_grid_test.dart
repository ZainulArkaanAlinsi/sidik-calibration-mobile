import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tebakan mesin di lembar GRID (kelima Enclosure) selamat sampai payload.
///
/// ## Kenapa grid butuh berkasnya sendiri
///
/// Sepuluh alat lain mengirim satu deret `pembacaan` datar dan tebakannya
/// nempel di `measurements[].ocr`. Grid nggak punya bentuk itu: tiap set point
/// berisi banyak baris termokopel, plus baris Indikator dan Suhu Ruang yang di
/// payload berbentuk DERET ANGKA POLOS — bukan objek — jadi tebakannya harus
/// jadi kunci sebelah (`indikator_ocr`, `suhu_ruang_ocr`).
///
/// Yang dijaga di sini sama dengan jalur tabel, dan alasannya juga sama: sel
/// yang teknisi ketik ulang itu justru bukti paling berharga bahwa mesinnya
/// salah. Kalau tebakannya ikut tertimpa, akurasi kamera nggak bisa dihitung
/// sama sekali — termasuk hijau palsu.
void main() {
  GridSensorBentuk bentuk() => GridSensorBentuk.fromJson({
    'jumlah_sensor_saran': 9,
    'pengulangan': [1, 2, 3],
    'baris_indikator': true,
    'baris_suhu_ruang': true,
  })!;

  SelTabelFoto sel(double penanda, int repeatNo, String teks, {double? skor}) =>
      (
        titikUkur: penanda,
        repeatNo: repeatNo,
        fieldId: 'pembacaan',
        teks: teks,
        keyakinan: skor,
      );

  /// Baris `sensor_grid` pertama dari payload set point pertama.
  Map<String, dynamic> barisSensor(GridSensorState s) {
    s.bacaUlang();

    final sp = s.payload(satuan: '°C', pakaiChannel: false).first;

    return (sp['sensor_grid'] as List<dynamic>).first as Map<String, dynamic>;
  }

  test('sel yang DIKETIK ULANG teknisi tetap membawa tebakan aslinya', () {
    final s = GridSensorState(bentuk: bentuk());

    s.setPoint.first.terapkanHasilFoto([sel(3, 1, '1S,1', skor: 0.88)]);

    // Teknisi melihat angkanya salah dan membetulkannya di kotak yang sama.
    s.setPoint.first.sensor.first.pembacaanCtl[0].text = '15,1';

    final baris = barisSensor(s);

    expect((baris['pembacaan'] as List<dynamic>)[0], 15.1);

    final ocr = (baris['ocr'] as List<dynamic>)[0] as Map<String, dynamic>;
    expect(
      ocr['raw_text'],
      '1S,1',
      reason:
          'Tanpa baris ini, tebakan yang KETAHUAN salah justru yang hilang.',
    );
    expect(ocr['confidence'], 0.88);
  });

  test('deret `ocr` sejajar indeks dengan `pembacaan`, bukan dirapatkan', () {
    final s = GridSensorState(bentuk: bentuk());

    // Cuma Repeat 3 yang dari kamera.
    s.setPoint.first.terapkanHasilFoto([sel(3, 3, '15,3')]);
    s.setPoint.first.sensor.first.pembacaanCtl[0].text = '15,1';

    final baris = barisSensor(s);
    final ocr = baris['ocr'] as List<dynamic>;

    expect(ocr.length, (baris['pembacaan'] as List<dynamic>).length);
    expect(
      ocr[0],
      isNull,
      reason: 'Repeat 1 diketik tangan — dia nggak boleh mengaku dari kamera.',
    );
    expect((ocr[2] as Map<String, dynamic>)['raw_text'], '15,3');
  });

  test('baris Indikator & Suhu Ruang pakai kunci sebelah', () {
    final s = GridSensorState(bentuk: bentuk());

    s.setPoint.first.terapkanHasilFoto([
      sel(SetPointGridState.kunciIndikator, 1, '15,0', skor: 0.9),
      sel(SetPointGridState.kunciSuhuRuang, 2, '24,6'),
    ]);
    s.bacaUlang();

    final sp = s.payload(satuan: '°C', pakaiChannel: false).first;

    expect(
      ((sp['indikator_ocr'] as List<dynamic>)[0] as Map<String, dynamic>)['raw_text'],
      '15,0',
    );
    expect(
      ((sp['suhu_ruang_ocr'] as List<dynamic>)[1] as Map<String, dynamic>)['raw_text'],
      '24,6',
    );
    expect(
      (sp['suhu_ruang_ocr'] as List<dynamic>)[0],
      isNull,
      reason: 'Repeat 1 Suhu Ruang nggak difoto.',
    );
  });

  test('grid yang seluruhnya diketik tangan nggak mengirim kunci ocr', () {
    final s = GridSensorState(bentuk: bentuk());
    final sensor = s.setPoint.first.sensor.first;

    sensor.noCtl.text = '3';
    sensor.pembacaanCtl[0].text = '15,1';
    s.setPoint.first.titikCtl.text = '15';

    s.bacaUlang();
    final sp = s.payload(satuan: '°C', pakaiChannel: false).first;

    expect(
      ((sp['sensor_grid'] as List<dynamic>).first as Map<String, dynamic>)
          .containsKey('ocr'),
      isFalse,
      reason:
          'Satu set point bisa punya 40 baris; deret null di tiap baris itu '
          'beban yang nggak dibayar apa pun.',
    );
    expect(sp.containsKey('indikator_ocr'), isFalse);
  });

  test('keyakinan yang nggak diketahui dikirim TANPA `confidence`', () {
    final s = GridSensorState(bentuk: bentuk());

    s.setPoint.first.terapkanHasilFoto([sel(3, 1, '15,1')]);

    final ocr =
        (barisSensor(s)['ocr'] as List<dynamic>)[0] as Map<String, dynamic>;

    expect(ocr['raw_text'], '15,1');
    expect(
      ocr.containsKey('confidence'),
      isFalse,
      reason: 'Skor karangan persis yang bikin sel salah divonis hijau.',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/autoclave_hasil.dart';

/// Parsing respons `POST /calibrations/autoclave/preview`. Angka acuan = keluaran
/// backend `AutoclaveCalculator` untuk sesi master 0281-CAL-624 (diadu ke
/// `Master Olah Data_Autoclave.xlsm`). Mobile nggak ngitung — cuma mastiin
/// angka backend kebaca utuh & mendarat di field yang benar.
void main() {
  final json = {
    'data': {
      'set_point': 121.0,
      'suhu': {
        'indikator_rata': 121.0,
        'stdev_indikator': 0.0,
        'sensor': [
          {
            'no': 1,
            'rata': 121.266,
            'koreksi_standar': 0.13,
            'standar_terkoreksi': 121.396,
            'koreksi': 0.396,
            'delta_t': 0.02,
          },
          {
            'no': 2,
            'rata': 121.264,
            'koreksi_standar': 0.20,
            'standar_terkoreksi': 121.464,
            'koreksi': 0.464,
            'delta_t': 0.05,
          },
          {
            'no': 3,
            'rata': 121.286,
            'koreksi_standar': 0.15,
            'standar_terkoreksi': 121.436,
            'koreksi': 0.436,
            'delta_t': 0.09,
          },
        ],
        'kestabilan': 0.045,
        'keseragaman': 0.464,
        'variasi': 0.10,
        'uc': 0.2241822142971117,
        'k': 1.9713602363081708,
        'u_bentangan': 0.4419439029528431,
        'cmc': 0.34,
        'u95': 0.4419439029528431,
      },
      'tekanan': {
        'satuan': 'MPa',
        'uut_setting': 0.112,
        'standar_terkoreksi': 0.1231,
        'koreksi': 0.0111,
        'u95': 0.0059,
        'k': 2.085963447265865,
        'uc': 0.004428378183187759,
        'cmc_bar': 0.059,
        'u95_bar': 0.059,
      },
    },
  };

  test('parse hasil suhu + kinerja + budget', () {
    final h = AutoclaveHasil.fromJson(json);

    expect(h.setPoint, 121.0);
    expect(h.suhu, isNotNull);
    expect(h.suhu!.sensor, hasLength(3));
    expect(h.suhu!.sensor[1].standarTerkoreksi, 121.464);
    expect(h.suhu!.sensor[1].koreksi, 0.464);
    expect(h.suhu!.keseragaman, 0.464);
    expect(h.suhu!.kestabilan, 0.045);
    expect(h.suhu!.variasi, 0.10);
    expect(h.suhu!.u95, closeTo(0.4419439, 1e-6));
    expect(h.suhu!.k, closeTo(1.9713602, 1e-6));
  });

  test('parse hasil tekanan pakai satuan display', () {
    final h = AutoclaveHasil.fromJson(json);

    expect(h.tekanan, isNotNull);
    expect(h.tekanan!.satuan, 'MPa');
    expect(h.tekanan!.uutSetting, 0.112);
    expect(h.tekanan!.standarTerkoreksi, 0.1231);
    expect(h.tekanan!.koreksi, 0.0111);
    expect(h.tekanan!.u95, 0.0059);
    expect(h.tekanan!.k, closeTo(2.0859634, 1e-6));
  });

  test('blok kosong jadi null, bukan objek kosong', () {
    final h = AutoclaveHasil.fromJson({
      'data': {'set_point': 121.0, 'suhu': {}, 'tekanan': {}},
    });
    expect(h.suhu, isNull);
    expect(h.tekanan, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Angka dari tabel matriks mendarat di jalur payload yang benar.
///
/// Ini titik paling rawan di seluruh pemindahan Autoklaf ke lembar kerja
/// generik: `Indikator Pressure` dan `Indikator Suhu` bersebelahan di kertas,
/// dan kalau salah satunya kegeser satu jalur, bacaan manometer masuk ke blok
/// suhu — persis kegagalan yang bikin layar khusus Autoklaf dibikin 20 Agu
/// 2026, dan angkanya jalan terus sampai sertifikat tanpa satu pun error.
///
/// Bentuk payload acuannya disalin dari `AutoclaveInputScreen._payload()`,
/// yang sudah dipakai kirim beneran.
void main() {
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
      {'kode': 'disk_3', 'label': 'Temp. Disk 3', 'kode_data': 'suhu.disk.2'},
      {
        'kode': 'indikator_suhu',
        'label': 'Indikator Suhu',
        'kode_data': 'suhu.indikator',
      },
      {
        'kode': 'indikator_pressure',
        'label': 'Indikator Pressure',
        'kode_data': 'tekanan.indikator_pressure',
      },
      {
        'kode': 'tekanan_atm_awal',
        'label': 'Tekanan atm awal',
        'kode_data': 'tekanan.tekanan_atm_awal',
      },
      {
        'kode': 'suhu_ruang',
        'label': 'Suhu Ruang',
        'kode_data': 'suhu.suhu_ruang',
      },
    ],
  })!;

  TabelSatuBaris tabelTekanan() => TabelSatuBaris.fromJson({
    'label': 'Pressure Disk Logger',
    'di_luar_kertas': true,
    'kolom': {
      'kode': 'tekanan.pembacaan_standar',
      'label': 'Standar Reading',
      'satuan': 'Bar',
    },
    'pengulangan': [1, 2, 3],
  })!;

  LembarKerja bentuk() => LembarKerja.fromJson({
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
          {'kode': 'satuan_tekanan', 'label': 'Pressure Unit', 'tipe': 'teks'},
          {
            'kode': 'display_tekanan',
            'label': 'Pressure Display Type',
            'tipe': 'teks',
          },
        ],
      },
    ],
  });

  LembarKerjaState state() =>
      LembarKerjaState(bentuk: bentuk(), clientRequestId: 'uji-matriks');

  void isi(
    LembarKerjaState s,
    String kodeData,
    List<String> nilai, {
    List<int> titik = const [1, 2, 3],
  }) {
    for (var i = 0; i < titik.length; i++) {
      s.kotakMatriks(kodeData, titik[i]).text = nilai[i];
    }
  }

  test('tiap baris mendarat di jalur payload-nya sendiri', () {
    final s = state();
    final m = matriks();

    isi(s, 'waktu', ['02:00:00', '04:00:00', '06:00:00']);
    isi(s, 'suhu.disk.0', ['121,10', '121,20', '121,30']);
    isi(s, 'suhu.disk.1', ['121,40', '121,50', '121,60']);
    isi(s, 'suhu.disk.2', ['121,70', '121,80', '121,90']);
    isi(s, 'suhu.indikator', ['121,00', '121,00', '121,00']);
    isi(s, 'tekanan.indikator_pressure', ['1,100', '1,100', '1,100']);
    isi(s, 'tekanan.tekanan_atm_awal', ['0,000', '0,000', '0,000']);
    isi(s, 'suhu.suhu_ruang', ['25,0', '25,1', '25,2']);
    isi(s, 'tekanan.pembacaan_standar', ['1,105', '1,106', '1,107']);

    s.teks['set_point']!.text = '121';
    s.teks['satuan_tekanan']!.text = 'Bar';
    s.teks['display_tekanan']!.text = 'Digital';

    final p = s.payloadMatriks(m, tabelTekanan());

    expect(p['set_point'], 121);
    expect(p['waktu'], ['02:00:00', '04:00:00', '06:00:00']);

    final suhu = p['suhu'] as Map<String, dynamic>;
    expect(suhu['disk'], [
      [121.1, 121.2, 121.3],
      [121.4, 121.5, 121.6],
      [121.7, 121.8, 121.9],
    ], reason: 'disk jadi daftar-di-dalam-daftar, urut nomor diskny');
    expect(suhu['indikator'], [121.0, 121.0, 121.0]);
    expect(suhu['suhu_ruang'], [25.0, 25.1, 25.2]);

    final tekanan = p['tekanan'] as Map<String, dynamic>;
    expect(tekanan['indikator_pressure'], [1.1, 1.1, 1.1]);
    expect(tekanan['tekanan_atm_awal'], [0.0, 0.0, 0.0]);
    expect(tekanan['pembacaan_standar'], [1.105, 1.106, 1.107]);
    expect(tekanan['satuan'], 'Bar');
    expect(tekanan['display'], 'Digital');

    // Yang paling penting: bacaan manometer TIDAK bocor ke blok suhu.
    expect(suhu.containsKey('indikator_pressure'), isFalse);
    expect(suhu['indikator'], isNot(contains(1.1)));

    // Backend yang mutusin UUT Reading dari kelima kolom — layar nggak nebak.
    expect(tekanan.containsKey('uut_setting'), isFalse);

    s.dispose();
  });

  test('blok yang kosong sama sekali nggak ikut dikirim', () {
    final s = state();
    isi(s, 'suhu.disk.0', ['121,10', '121,20', '121,30']);
    s.teks['set_point']!.text = '121';

    final p = s.payloadMatriks(matriks(), tabelTekanan());

    expect(p.containsKey('tekanan'), isFalse,
        reason: 'blok kosong yang tetap dikirim bikin backend '
            'ngerata-rata daftar null');
    expect((p['suhu'] as Map<String, dynamic>).containsKey('indikator'), isFalse);
    expect(p.containsKey('waktu'), isFalse);

    s.dispose();
  });

  test('satuan tekanan nggak nempel kalau blok tekanannya nggak ada', () {
    final s = state();
    isi(s, 'suhu.indikator', ['121,00', '121,00', '121,00']);
    s.teks['satuan_tekanan']!.text = 'Psi';

    final p = s.payloadMatriks(matriks(), null);

    expect(p.containsKey('tekanan'), isFalse);

    s.dispose();
  });
}

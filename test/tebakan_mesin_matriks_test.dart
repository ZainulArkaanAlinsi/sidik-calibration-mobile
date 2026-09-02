import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tebakan mesin di lembar MATRIKS (Autoklaf) selamat sampai payload.
///
/// ## Kenapa Autoklaf butuh berkasnya sendiri
///
/// Dua puluh alat lain menyimpan angka ukurnya di `raw_measurements`, dan di
/// situ kolom tebakan mesinnya sudah lama menunggu. **Autoklaf nggak pernah
/// menulis satu baris pun ke tabel itu** — hasil ukurnya snapshot JSON.
///
/// Jadi blok tebakannya dikirim TERPISAH, bercermin ke jalur nilainya dengan
/// awalan `ocr.`: `suhu.disk.0` nilainya, `ocr.suhu.disk.0` tebakannya, sejajar
/// indeks. Bentuk kedua yang harus diurai ulang cuma nambah tempat buat salah
/// alamat — dan di data latih, salah alamat nggak pernah kelihatan.
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
      {
        'kode': 'indikator_pressure',
        'label': 'Indikator Pressure',
        'kode_data': 'tekanan.indikator_pressure',
      },
    ],
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
        ],
      },
    ],
  });

  LembarKerjaState state() =>
      LembarKerjaState(bentuk: bentuk(), clientRequestId: 'uji-tebakan-matriks');

  /// Penanda foto buat baris ber-[kodeData] — dicari lewat posisinya di
  /// `semuaBaris`, bukan diketik, supaya test-nya nggak ikut basi kalau baris
  /// waktu bergeser.
  double penanda(MatriksHasil m, String kodeData) {
    final i = m.semuaBaris.indexWhere((b) => b.kodeData == kodeData);

    return MatriksHasil.kunciBarisFoto(i);
  }

  SelTabelFoto sel(double p, int titikWaktu, String teks, {double? skor}) => (
    titikUkur: p,
    repeatNo: titikWaktu,
    fieldId: 'pembacaan',
    teks: teks,
    keyakinan: skor,
  );

  test('sel yang DIKETIK ULANG teknisi tetap membawa tebakan aslinya', () {
    final s = state();
    addTearDown(s.dispose);
    final m = matriks();

    s.terapkanHasilFotoMatriks(m, [
      sel(penanda(m, 'suhu.disk.0'), 1, '12I,10', skor: 0.81),
    ]);

    // Teknisi membetulkannya di kotak yang sama — jalur yang dulu menghapus
    // buktinya.
    s.kotakMatriks('suhu.disk.0', 1).text = '121,10';

    final p = s.payloadMatriks(m, null);

    expect((p['suhu']['disk']['0'] as List<dynamic>)[0], 121.10);

    final ocr = p['ocr']['suhu']['disk']['0'] as List<dynamic>;
    expect(
      (ocr[0] as Map<String, dynamic>)['raw_text'],
      '12I,10',
      reason: 'Tebakan yang KETAHUAN salah justru yang paling berharga.',
    );
    expect((ocr[0] as Map<String, dynamic>)['confidence'], 0.81);
  });

  test('blok ocr bercermin ke jalur nilainya, sejajar indeks', () {
    final s = state();
    addTearDown(s.dispose);
    final m = matriks();

    // Cuma titik waktu 3 yang dari kamera; titik 1 diketik tangan.
    s.terapkanHasilFotoMatriks(m, [
      sel(penanda(m, 'tekanan.indikator_pressure'), 3, '1,103'),
    ]);
    s.kotakMatriks('tekanan.indikator_pressure', 1).text = '1,101';

    final p = s.payloadMatriks(m, null);
    final ocr = p['ocr']['tekanan']['indikator_pressure'] as List<dynamic>;

    expect(ocr.length, 3, reason: 'Sepanjang deret nilainya, bukan dirapatkan.');
    expect(ocr[0], isNull, reason: 'Titik waktu 1 diketik tangan.');
    expect((ocr[2] as Map<String, dynamic>)['raw_text'], '1,103');

    expect(
      (p['ocr']['suhu'] as Map<String, dynamic>?),
      isNull,
      reason: 'Baris yang nggak difoto nggak menitip kunci kosong.',
    );
  });

  test('lembar yang seluruhnya diketik tangan nggak mengirim blok ocr', () {
    final s = state();
    addTearDown(s.dispose);
    final m = matriks();

    s.kotakMatriks('suhu.disk.0', 1).text = '121,10';

    expect(s.payloadMatriks(m, null).containsKey('ocr'), isFalse);
  });

  test('keyakinan yang nggak diketahui dikirim TANPA `confidence`', () {
    final s = state();
    addTearDown(s.dispose);
    final m = matriks();

    s.terapkanHasilFotoMatriks(m, [
      sel(penanda(m, 'suhu.disk.0'), 2, '121,20'),
    ]);

    final ocr = s.payloadMatriks(m, null)['ocr']['suhu']['disk']['0'] as List<dynamic>;

    expect((ocr[1] as Map<String, dynamic>)['raw_text'], '121,20');
    expect(
      (ocr[1] as Map<String, dynamic>).containsKey('confidence'),
      isFalse,
      reason: 'Skor karangan persis yang bikin sel salah divonis hijau.',
    );
  });
}

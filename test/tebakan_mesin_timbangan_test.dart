import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tebakan mesin dari tabel yang disimpan ke `spesifikasi_alat` — blok
/// Repeatability lembar Timbangan — ikut terkirim.
///
/// ## Kenapa lembar ini beda dari dua puluh alat lain
///
/// Yang difoto di Timbangan blok Repeatability, dan blok itu besaran
/// tingkat-SESI: dia menyatakan `simpan_ke: spesifikasi_alat.keterulangan` dan
/// mendarat sebagai JSON di kolom itu — BUKAN di `raw_measurements`, tempat
/// tebakan alat lain menunggu.
///
/// Jadi kalau blok ini nggak ikut membawa tebakannya, seluruh lembar Timbangan
/// hilang dari pengukuran akurasi, dan diamnya kebaca sebagai "kameranya bagus
/// di Timbangan" — padahal artinya nol data.
void main() {
  LembarKerja bentuk() => LembarKerja.fromJson({
    'judul': 'Uji keterulangan',
    'jumlah_pengulangan': 3,
    'satuan': 'kg',
    'bagian': [
      {
        'kode': 'keterulangan',
        'halaman': 1,
        'judul': 'Repeatability',
        'tabel': [
          {
            'kode': 'keterulangan',
            'tahap': 'keterulangan',
            'simpan_ke': 'spesifikasi_alat.keterulangan',
            'pengulangan': [1, 2, 3],
            'kolom': [
              {'kode': 'zero', 'label': 'zi'},
              {'kode': 'pembacaan', 'label': 'mi'},
            ],
            'baris': [
              {'titik_ukur': 50},
              {'titik_ukur': 100},
            ],
          },
        ],
      },
    ],
  });

  LembarKerjaState state(LembarKerja b) =>
      LembarKerjaState(bentuk: b, clientRequestId: 'uji-timbangan')
        ..alat = const EquipmentLookup(
          id: 9,
          namaAlat: 'Timbangan',
          serialNumber: 'TB-1',
          kategori: 'massa',
          status: 'aktif',
          satuan: 'kg',
        );

  TabelHasil tabelDari(LembarKerja b) => b.bagian.first.tabel.first;

  SelTabelFoto sel(TabelHasil t, double titikUkur, int repeatNo, String teks, {double? skor}) => (
    titikUkur: titikUkur,
    repeatNo: repeatNo,
    fieldId: 'pembacaan',
    teks: teks,
    keyakinan: skor,
  );

  double titikBaris(LembarKerjaState s, TabelHasil t, int index) =>
      s.titik[s.kunciBaris(s.barisTabel(t), index, t)]!.titikUkur;

  /// Baris pertama blok `keterulangan` di payload `spesifikasi_alat`.
  Map<String, dynamic> barisPertama(LembarKerjaState s) =>
      ((s.spesifikasiAlat['keterulangan'] as Map<String, dynamic>)['baris']
              as List<dynamic>)
          .first as Map<String, dynamic>;

  test('sel yang DIKETIK ULANG teknisi tetap membawa tebakan aslinya', () {
    final b = bentuk();
    final s = state(b);
    addTearDown(s.dispose);

    final t = tabelDari(b);
    final titik = titikBaris(s, t, 0);

    expect(
      s.terapkanHasilFotoTabel([sel(t, titik, 1, '50,07', skor: 0.88)], tabel: t),
      1,
      reason: 'Prasyarat: selnya memang keisi dari foto.',
    );

    // Teknisi membetulkannya di kotak yang sama.
    s.titik[s.kunciBaris(s.barisTabel(t), 0, t)]!
        .kotak(t.kunciTabel, 'pembacaan', 0)
        .text = '50,02';

    final baris = barisPertama(s);

    expect((baris['pembacaan'] as List<dynamic>)[0], 50.02);

    final ocr = (baris['pembacaan_ocr'] as List<dynamic>)[0] as Map<String, dynamic>;
    expect(ocr['raw_text'], '50,07');
    expect(ocr['confidence'], 0.88);
  });

  test('deret ocr sejajar indeks, dan kolom lain nggak ikut kebawa', () {
    final b = bentuk();
    final s = state(b);
    addTearDown(s.dispose);

    final t = tabelDari(b);

    // Cuma ulangan KETIGA yang dari kamera.
    s.terapkanHasilFotoTabel(
      [sel(t, titikBaris(s, t, 0), 3, '50,03')],
      tabel: t,
    );

    final baris = barisPertama(s);
    final ocr = baris['pembacaan_ocr'] as List<dynamic>;

    expect(ocr.length, (baris['pembacaan'] as List<dynamic>).length);
    expect(ocr[0], isNull);
    expect((ocr[2] as Map<String, dynamic>)['raw_text'], '50,03');

    expect(
      baris.containsKey('zero_ocr'),
      isFalse,
      reason: 'Kolom `zero` nggak difoto — kunci kosong bikin pembacanya '
          'mengira ada jalur kamera di situ.',
    );
  });

  test('blok yang seluruhnya diketik tangan nggak mengirim kunci ocr', () {
    final b = bentuk();
    final s = state(b);
    addTearDown(s.dispose);

    final t = tabelDari(b);
    s.titik[s.kunciBaris(s.barisTabel(t), 0, t)]!
        .kotak(t.kunciTabel, 'pembacaan', 0)
        .text = '50,02';

    final baris = barisPertama(s);

    expect(baris.containsKey('pembacaan_ocr'), isFalse);
    expect(baris.containsKey('zero_ocr'), isFalse);
  });
}

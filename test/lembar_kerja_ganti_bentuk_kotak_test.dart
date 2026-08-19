import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';

/// Ganti bentuk lembar di tengah jalan harus ikut nyiapin KOTAK TEKS-nya.
///
/// `gantiBentuk` dipanggil tiap teknisi milih alat: backend mulangin bentuk
/// yang disusutin ke alat itu, dan `_FormState` sengaja MEMPERTAHANKAN state
/// yang lama (lihat `ValueKey` di `LembarKerjaScreen`) supaya isian yang udah
/// diketik nggak ilang. Tapi controller kotak teksnya dulu cuma dibikin sekali
/// di konstruktor — jadi kolom yang cuma ada di bentuk BARU nggak dapat
/// controller sama sekali, dan dua-duanya gagal tanpa suara:
///
///  - `TextField(controller: null)` nampung ketikan di dalam dirinya sendiri.
///    Waktu payload disusun, `spesifikasiAlat` baca `teks[kode]` → null → kolom
///    itu nggak pernah kekirim. Yang ilang bukan kolom sembarangan: kelima
///    `spesifikasi_alat.*` Spectrophotometer TERCETAK di sertifikat.
///  - `_BarisSpesifikasi` butuh `teks[kode]!` buat dropdown Model/Spindle
///    Viscometer — null di situ matiin layarnya, bukan cuma satu kotak.
void main() {
  /// Bentuk seadanya: satu bagian, field-nya bisa disetel per test.
  LembarKerja bentuk(List<Map<String, dynamic>> field) => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-FM-TES',
    'judul': 'Tes',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': 'cP',
    'satuan_suhu': '°C',
    'bagian': [
      {'kode': 'hasil', 'judul': 'Hasil', 'field': field},
    ],
  });

  Map<String, dynamic> field(String kode, String tipe) => {
    'kode': kode,
    'label': kode,
    'tipe': tipe,
  };

  test('kolom yang cuma ada di bentuk baru dapat controller', () {
    final isian = LembarKerjaState(
      bentuk: bentuk([field('alat_model', 'teks')]),
      clientRequestId: 'tes-ganti-bentuk',
    );

    expect(isian.teks.containsKey('spesifikasi_alat.resolusi_transmitan'), isFalse);

    isian.gantiBentuk(
      bentuk([
        field('alat_model', 'teks'),
        field('spesifikasi_alat.resolusi_transmitan', 'teks'),
        field('spesifikasi_alat.spindle_titik_1', 'pilihan'),
      ]),
    );

    // Yang bertipe pilihan ikut dapat kotak: dia digambar `_BarisSpesifikasi`
    // sebagai dropdown yang nulis ke controller, bukan `_PilihanTetap`.
    expect(isian.teks.containsKey('spesifikasi_alat.resolusi_transmitan'), isTrue);
    expect(isian.teks.containsKey('spesifikasi_alat.spindle_titik_1'), isTrue);
  });

  test('isian yang udah diketik nggak ikut kereset waktu bentuknya ganti', () {
    final isian = LembarKerjaState(
      bentuk: bentuk([field('alat_model', 'teks')]),
      clientRequestId: 'tes-ganti-bentuk',
    );

    isian.teks['alat_model']!.text = 'DV2THA';

    isian.gantiBentuk(
      bentuk([field('alat_model', 'teks'), field('alat_merk', 'teks')]),
    );

    expect(isian.teks['alat_model']!.text, 'DV2THA');
  });

  test('kolom yang udah nggak ada di bentuk baru dibuang', () {
    final isian = LembarKerjaState(
      bentuk: bentuk([
        field('alat_model', 'teks'),
        field('spesifikasi_alat.rentang_ukur_transmitan', 'teks'),
      ]),
      clientRequestId: 'tes-ganti-bentuk',
    );

    isian.gantiBentuk(bentuk([field('alat_model', 'teks')]));

    expect(
      isian.teks.containsKey('spesifikasi_alat.rentang_ukur_transmitan'),
      isFalse,
    );
  });

  test('spesifikasi yang diketik SESUDAH ganti bentuk ikut kekirim', () {
    final isian = LembarKerjaState(
      bentuk: bentuk([field('alat_model', 'teks')]),
      clientRequestId: 'tes-ganti-bentuk',
    );

    isian.gantiBentuk(
      bentuk([
        field('alat_model', 'teks'),
        field('spesifikasi_alat.spindle_titik_1', 'pilihan'),
      ]),
    );

    isian.teks['spesifikasi_alat.spindle_titik_1']!.text = 'HA1';

    expect(isian.spesifikasiAlat, containsPair('spindle_titik_1', 'HA1'));
  });
}

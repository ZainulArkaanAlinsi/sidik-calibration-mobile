import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';

/// Kolom **U95%** punya desimalnya sendiri, terpisah dari kolom hasil.
///
/// ## Cacat yang ditutup berkas ini
///
/// Backend mengirim `desimal_u95` per titik sejak alat ke-13 (Spectrophotometer
/// menulis `0,43 nm` sementara Standard/UUT/Correction di tabel yang sama cuma
/// satu desimal). Layar sertifikat sudah membacanya; `MeasurementResult`
/// **belum** — jadi tiga layar lain memukul rata U95 dengan desimal kolom
/// hasil:
///
///  - layar detail sesi,
///  - layar sertifikat di riwayat,
///  - pratinjau di lembar kerja.
///
/// Diukur dari respons server yang sebenarnya:
///
/// | Sesi | `desimal` | `desimal_u95` | U95 | Layar (dulu) | Sertifikat |
/// |---|---|---|---|---|---|
/// | Gas Detector `2602.03.A` | 0 | 1 | 5,054 | **`5`** | `5,1` |
/// | Timer `015-CAL-424` | 3 | 2 | 0,81 | `0,810` | `0,81` |
/// | Tachometer `0140-CAL-424` | 2 | 1 | 3,171 | `3,17` | `3,2` |
///
/// Yang paling tajam yang pertama: ketidakpastian terakreditasi tampil **tanpa
/// desimal sama sekali** di layar yang dipakai teknisi memeriksa hasilnya
/// sendiri sebelum minta approve — persis orang yang paling mungkin menyadari
/// bedanya, dan paling mungkin menyangka dirinya yang salah baca.
void main() {
  MeasurementResult titik({int? desimal, int? desimalU95}) =>
      MeasurementResult.fromJson({
        'titik_ke': 1,
        'titik_ukur': 60,
        'rata_rata': 60.137,
        'koreksi': -0.0406666,
        'ketidakpastian_diperluas': 0.81,
        'desimal': ?desimal,
        'desimal_u95': ?desimalU95,
      });

  test('desimal_u95 kebaca dari respons', () {
    expect(titik(desimal: 3, desimalU95: 2).desimalU95, 2);
  });

  test('U95 pakai desimalnya sendiri, bukan desimal kolom hasil', () {
    // Timer: hasil 3 desimal, U95 2.
    expect(titik(desimal: 3, desimalU95: 2).desimalU95Efektif(4), 2);

    // Gas Detector: hasil BILANGAN BULAT, U95 satu desimal. Ini yang bikin
    // `5,05` runtuh jadi `5` waktu dipukul rata.
    expect(titik(desimal: 0, desimalU95: 1).desimalU95Efektif(4), 1);

    // Dua alat rpm: hasil 2, U95 1.
    expect(titik(desimal: 2, desimalU95: 1).desimalU95Efektif(4), 1);
  });

  test('alat yang nggak menyebutnya tetap ikut kolom hasil', () {
    // Enam belas alat lain nggak mengirim `desimal_u95` sama sekali —
    // perilakunya nggak boleh bergeser sedikit pun.
    expect(titik(desimal: 2).desimalU95Efektif(4), 2);

    // Dan yang nggak menyebut dua-duanya jatuh ke desimal tingkat sesi.
    expect(titik().desimalU95Efektif(4), 4);
  });
}

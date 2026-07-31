import 'dart:math' as math;

/// Format ketidakpastian (U95) — dijamin kebaca **2 angka penting**.
///
/// Kolom hasil lain dicetak sebanyak desimal alatnya (resolusi 0,01 → 2
/// desimal), dan buat pembacaan itu bener: nulis lebih banyak dari yang bisa
/// dibaca alatnya itu ngaku-ngaku presisi.
///
/// Ketidakpastian beda aturannya. Dipaksa ikut desimal alat, dia rusak:
///
/// ```
/// U = 0,02658849   desimal alat 2  ->  "0.03"    (1 angka penting, meleset 13%)
/// U = 0,02343221   desimal alat 2  ->  "0.02"    (1 angka penting, meleset 15%)
/// ```
///
/// Di sertifikat terakreditasi, U yang salah baca langsung ngubah kesimpulan
/// PASS/FAIL waktu pelanggan ngebandingin sama toleransi alatnya.
///
/// [desimalAlat] dipakai sebagai **lantai**, bukan target — U yang udah besar
/// nggak berubah:
///
/// ```
/// 0,2199  desimal 2  ->  "0.22"     (nggak berubah)
/// 0,02658 desimal 2  ->  "0.027"
/// 0,00234 desimal 3  ->  "0.0023"
/// ```
///
/// Padanan `App\Support\Angka::ketidakpastian()` di backend — dua-duanya harus
/// keluar angka yang sama, karena layar ini dipakai buat nyocokin sama PDF-nya.
String formatKetidakpastian(double nilai, int desimalAlat) {
  final besar = nilai.abs();

  // `log10(0)` itu -Infinity; tanpa penjaga ini desimalnya jadi ngawur.
  if (besar == 0 || !besar.isFinite) {
    return nilai.toStringAsFixed(desimalAlat);
  }

  // Posisi angka penting pertama. `0,0265` -> eksponen -2, jadi butuh 3
  // desimal biar dua angka pentingnya (2 dan 7) kebaca.
  final eksponenPertama = (math.log(besar) / math.ln10).floor();
  final perluDesimal = -eksponenPertama + 1;

  // Dibatasi 8: kolomnya `decimal(20,8)` di backend, lebih dari itu nggak ada
  // isinya lagi.
  final desimal = math.min(math.max(desimalAlat, perluDesimal), 8);

  return nilai.toStringAsFixed(desimal);
}

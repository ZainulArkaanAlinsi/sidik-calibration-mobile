import 'dart:math' as math;

/// Format angka hasil/pembacaan buat DITAMPILKAN, dengan dua aturan lab yang
/// gampang ketuker:
///
/// 1. **Nggak ada pembulatan** — desimalnya ditampilkan apa adanya (dipotong di
///    [desimalMaks] = presisi kolom backend `decimal(20,8)`, bukan dibulatkan
///    ke desimal alat).
/// 2. **Nol di belakang NGGAK dibuang sampai batas [desimalMin]** — resolusi
///    titiknya. Pembacaan `4.6` di titik ber-resolusi 0,01 tampil `4.60`, bukan
///    `4.6`; `999` di titik ber-resolusi 1 tampil `999`. Nol yang mewakili
///    resolusi itu INFORMASI (seberapa teliti alatnya kebaca), bukan hiasan.
///
/// Separatornya **titik**, ngikutin konvensi tampilan angka yang udah dipakai
/// lembar perhitungan & yang dicocokin sama PDF sertifikat (lihat
/// [formatKetidakpastian]). Yang diminta lab itu nol belakangnya dipertahankan,
/// bukan ganti separator — dua hal beda, dan ganti separator di sini bakal
/// bikin angka layar beda dari PDF.
///
/// ```
/// formatNilai(4.6,   desimalMin: 2)  ->  "4.60"
/// formatNilai(999.0, desimalMin: 0)  ->  "999"
/// formatNilai(99.8,  desimalMin: 1)  ->  "99.8"
/// formatNilai(0.14363147, desimalMin: 0)  ->  "0.14363147"
/// ```
String formatNilai(double nilai, {int desimalMin = 0, int desimalMaks = 8}) {
  if (!nilai.isFinite) return '$nilai';

  final min = desimalMin.clamp(0, desimalMaks);

  // Basis presisi penuh (dipotong ke desimalMaks — ini yang nyerap derau float
  // kayak -0.20000000000000284 jadi -0.2, dan cocok sama presisi backend).
  var teks = nilai.toStringAsFixed(desimalMaks);

  if (teks.contains('.')) {
    // Buang nol belakang, TAPI sisain minimal `min` desimal.
    final titik = teks.indexOf('.');
    var akhir = teks.length;
    while (akhir > titik + 1 + min && teks[akhir - 1] == '0') {
      akhir--;
    }
    // Kalau semua desimal kebuang (min 0) dan cuma sisa titik, buang titiknya.
    if (akhir == titik + 1) akhir = titik;
    teks = teks.substring(0, akhir);
  }

  return teks;
}

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

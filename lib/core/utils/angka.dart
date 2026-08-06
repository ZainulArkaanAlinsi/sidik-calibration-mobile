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

/// Format angka **persis kayak yang dicetak di sertifikat**: desimal tetap,
/// koma sebagai pemisah desimal, titik sebagai pemisah ribuan.
///
/// Padanan `App\Support\Angka::id()` di backend, yang dipakai
/// `sertifikat/pdf.blade.php` buat SEMUA kolom tabel hasil — termasuk U95.
///
/// ```
/// formatSertifikat(1.758, 2)   ->  "1,76"
/// formatSertifikat(0.091, 2)   ->  "0,09"
/// formatSertifikat(-0.018, 2)  ->  "-0,02"
/// formatSertifikat(1234.5, 1)  ->  "1.234,5"
/// ```
///
/// **Jangan dipakai di luar layar sertifikat.** Lembar perhitungan pakai
/// [formatNilai] (separator titik, nol belakang dipertahankan) karena angkanya
/// masih dipakai buat ngitung dan diketik ulang, bukan buat dicetak.
String formatSertifikat(double nilai, int desimal) {
  if (!nilai.isFinite) return '$nilai';

  final d = desimal.clamp(0, 8);
  final teks = nilai.toStringAsFixed(d);
  final negatif = teks.startsWith('-');
  final tanpaTanda = negatif ? teks.substring(1) : teks;

  final titik = tanpaTanda.indexOf('.');
  final bulat = titik == -1 ? tanpaTanda : tanpaTanda.substring(0, titik);
  final pecahan = titik == -1 ? '' : tanpaTanda.substring(titik + 1);

  // Ribuan dikelompokin dari kanan: "1234567" -> "1.234.567".
  final buf = StringBuffer();
  for (var i = 0; i < bulat.length; i++) {
    if (i > 0 && (bulat.length - i) % 3 == 0) buf.write('.');
    buf.write(bulat[i]);
  }

  final hasil = pecahan.isEmpty ? buf.toString() : '${buf.toString()},$pecahan';

  // `-0,00` itu hasil pembulatan nilai negatif kecil. Ditulis apa adanya bikin
  // orang ngira ada koreksi negatif padahal nol — tandanya dibuang.
  if (negatif && double.parse(teks) == 0) return hasil;

  return negatif ? '-$hasil' : hasil;
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
/// ## BUKAN aturan yang dipakai sertifikat (per 6 Agt 2026)
///
/// Sertifikat lab ini nulis U95 sebanyak desimal alatnya, sama kayak kolom
/// lain — `0,091` dicetak `0,09`. Itu yang ada di sertifikat asli lab dan yang
/// sekarang dipakai PDF, Excel, sama pratinjau di app: [formatSertifikat].
///
/// Fungsi ini disimpan buat kalau lab balik ke aturan 2-angka-penting (yang
/// lazim di GUM), TAPI jangan dipakai di layar sertifikat: bikin angka layar
/// beda dari PDF, dan itu persis bug yang dilaporin 6 Agt.
///
/// Padanannya di backend `App\Support\Angka::ketidakpastian()`, sama-sama nggak
/// kepakai sekarang.
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

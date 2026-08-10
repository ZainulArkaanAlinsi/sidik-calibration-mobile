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

/// Berapa desimal yang mewakili [resolusi] alat: `0,01` → 2, `0,0001` → 4,
/// `1` → 0.
///
/// Dipakai buat alat yang resolusinya **seragam** di semua titik (pH, Chlorine,
/// Refractometer) — bentuk lembar kerjanya sengaja nggak ngirim `desimal` per
/// baris, dan yang bener dipakai ya resolusi alatnya. Cuma alat yang
/// resolusinya beda per titik (Turbidimeter: 0,01 / 0,1 / 1) yang ngirim
/// sendiri, dan angka itu yang menang.
///
/// **Jangan diganti angka tetap.** Sampai 6 Agt 2026 tiga alat pertama
/// resolusinya 0,01 semua, jadi "2" kelihatan aman — sampai Refractometer masuk
/// dengan 0,0001 dan `1,3362` berubah jadi `1,34` di layar tanpa ada yang
/// error.
///
/// `null`/nol/negatif → `null`: nggak ada yang bisa disimpulin, dan nebak 2 di
/// sini itu persis kesalahan yang bikin catatan di atas ditulis.
int? desimalDariResolusi(double? resolusi) {
  if (resolusi == null || !resolusi.isFinite || resolusi <= 0) return null;

  // Lewat teks, bukan log10: `log10(0.001)` balikin -2,9999999999999996 dan
  // pembulatannya gampang meleset satu desimal.
  final teks = resolusi.toStringAsFixed(8);
  final titik = teks.indexOf('.');
  if (titik == -1) return 0;

  var akhir = teks.length;
  while (akhir > titik + 1 && teks[akhir - 1] == '0') {
    akhir--;
  }

  return akhir - titik - 1;
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

  // Ribuan TIDAK dikelompokin. Master nulis `1000` & `1001`; `1.000` di dokumen
  // yang komanya dipakai buat desimal kebaca ambigu. Padanan
  // `Angka::hasil()` di backend.
  final hasil = tanpaTanda.replaceFirst('.', ',');

  // `-0,00` DITULIS apa adanya. Sempat tandanya dibuang di sini dengan alasan
  // "bikin orang ngira ada koreksi negatif padahal nol" — masuk akal, tapi
  // master Turbidimeter `0189-CAL-624` nulis `-0,00` & `-0,0`, dan tanda itu
  // yang bilang alatnya baca DI ATAS standar. Diadu langsung 10 Agt 2026.
  return negatif ? '-$hasil' : hasil;
}

/// Kolom **Standard Value** — [formatSertifikat] dengan nol di belakang dibuang.
///
/// Master nulis nilai NOMINAL standarnya: Turbidimeter `1` / `100` / `1000`
/// (bukan `1,00` / `100,0`), sementara Chlorine tetap `1,74` dan pH `4,01`.
/// Bedanya bukan aturan per alat — standar Turbidimeter emang angka bulat, jadi
/// desimalnya nggak bawa informasi apa pun.
///
/// Padanan `Angka::nilaiStandar()` di backend.
String formatNilaiStandar(double nilai, int desimal) {
  final teks = formatSertifikat(nilai, desimal);

  if (!teks.contains(',')) return teks;

  return teks.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r',$'), '');
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

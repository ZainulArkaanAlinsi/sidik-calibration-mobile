---
aliases: [Contoh Implementasi GUM, Contoh Kode Perhitungan Kalibrasi]
---

# Contoh Implementasi Rumus GUM + ILAC-G8 (dengan Keterangan)

🏠 [[Dashboard]] · Rujukan: [[Aturan Bisnis Inti]] · Lokasi eksekusi nyata: repo backend `sidik-calibration-api` (Laravel/PHP) — **bukan** di app Flutter ini, mobile cuma nampilin hasil.

> Dokumen ini contoh/latihan biar rumusnya kebayang jadi kode. Bukan file kode asli yang jalan di production.

---

## 1. Data Contoh yang Dipakai

| Data | Nilai | Keterangan |
|---|---|---|
| Alat | Jangka Sorong (Vernier Caliper) | Kategori: Panjang |
| Titik ukur (acuan/setpoint) | 50.000 mm | Nilai gauge block yang dipakai sebagai acuan |
| Pembacaan (3x pengulangan) | 50.02, 50.01, 50.03 mm | Yang kebaca di alat, dicatat manual/OCR |
| Standar Acuan | Gauge Block Set Grade 0 | `standard_id` wajib dipilih (lihat [[Aturan Bisnis Inti]]) |
| Ketidakpastian standar (U, sudah diperluas) | 0.0004 mm, k=2 | Dari `GET /api/standards` — nilai ini **sudah dikali k**, makanya nanti dibagi lagi waktu jadi u |
| Resolusi alat | 0.01 mm | Setengah resolusi (0.005 mm) dianggap sebaran rectangular |
| Toleransi alat | ± 0.05 mm | Batas keberterimaan, wajib diisi di data alat |

---

## 2. Langkah Manual (biar kelihatan asal-usul tiap angka)

**Langkah 1 — Rata-rata & Error**
```
rata_rata = (50.02 + 50.01 + 50.03) / 3 = 50.02 mm
error     = rata_rata - titik_ukur = 50.02 - 50.00 = +0.02 mm
```

**Langkah 2 — Type A (dari sebaran 3 pengulangan)**
```
deviasi tiap pembacaan dari rata-rata: 0, -0.01, +0.01
variansi = (0² + (-0.01)² + 0.01²) / (n-1) = 0.0002 / 2 = 0.0001
std_dev  = √0.0001 = 0.01
u_a      = std_dev / √n = 0.01 / √3 ≈ 0.00577 mm
```
*Keterangan*: Type A cuma bisa dihitung kalau ada minimal 2 pembacaan — inilah kenapa aturan bisnisnya "minimal 2 pembacaan per titik".

**Langkah 3 — Type B (komponen di luar pengulangan)**
```
Komponen "standar acuan" (distribusi normal):
  u1 = U_standar / faktor_cakupan = 0.0004 / 2 = 0.0002 mm

Komponen "resolusi alat" (distribusi rectangular, dibagi √3):
  u2 = (resolusi/2) / √3 = 0.005 / 1.732 ≈ 0.002887 mm

u_b = √(u1² + u2²) = √(0.0002² + 0.002887²) ≈ 0.002895 mm
```
*Keterangan*: divisor beda-beda tergantung bentuk sebarannya — `normal` dibagi faktor cakupan k, `rectangular` dibagi √3, `triangular` dibagi √6. Ini yang bikin Type B "kelihatan ribet": bukan satu rumus, tapi kumpulan komponen yang tiap sumbernya punya cara ubah sendiri jadi ketidakpastian standar.

**Langkah 4 — Gabungan & Diperluas**
```
u_c = √(u_a² + u_b²) = √(0.00577² + 0.002895²) ≈ 0.00646 mm
U   = k × u_c = 2 × 0.00646 ≈ 0.01291 mm
```

**Langkah 5 — Keputusan (guarded acceptance ILAC-G8)**
```
|error| + U = 0.02 + 0.01291 = 0.03291 mm
toleransi   = 0.05 mm

0.03291 ≤ 0.05  →  PASS
```

---

## 3. Versi Kode (PHP, gaya backend Laravel)

```php
<?php

/**
 * Type A — ketidakpastian dari sebaran pengulangan pembacaan.
 * Butuh minimal 2 pembacaan, karena standar deviasi nggak ada artinya dari 1 angka.
 */
function hitungTypeA(array $pembacaan): float
{
    $n = count($pembacaan);
    $rataRata = array_sum($pembacaan) / $n;

    $jumlahKuadratDeviasi = array_sum(
        array_map(fn($x) => ($x - $rataRata) ** 2, $pembacaan)
    );
    $variansi = $jumlahKuadratDeviasi / ($n - 1);
    $stdDev = sqrt($variansi);

    return $stdDev / sqrt($n); // u_a
}

/**
 * Type B — gabungan komponen ketidakpastian di luar pengulangan.
 * $komponen contoh:
 * [
 *   ['value' => 0.0004, 'distribution' => 'normal', 'faktor_cakupan' => 2], // standar acuan
 *   ['value' => 0.005,  'distribution' => 'rectangular'],                   // setengah resolusi
 * ]
 */
function hitungTypeB(array $komponen): float
{
    $jumlahKuadrat = 0;

    foreach ($komponen as $k) {
        $divisor = match ($k['distribution']) {
            'normal'      => $k['faktor_cakupan'] ?? 2,
            'rectangular' => sqrt(3),
            'triangular'  => sqrt(6),
            default       => 1,
        };
        $u_i = $k['value'] / $divisor;
        $jumlahKuadrat += $u_i ** 2;
    }

    return sqrt($jumlahKuadrat); // u_b gabungan
}

/**
 * Gabungin Type A + Type B jadi ketidakpastian diperluas.
 */
function hitungKetidakpastianDiperluas(float $u_a, float $u_b, float $k = 2): array
{
    $u_c = sqrt($u_a ** 2 + $u_b ** 2);
    $U = $k * $u_c;

    return ['u_c' => $u_c, 'U' => $U];
}

/**
 * Keputusan PASS/FAIL — guarded acceptance ILAC-G8.
 * BUKAN sekadar |error| <= toleransi; U ikut ditambahkan ke error.
 */
function keputusanIlacG8(float $error, float $U, float $toleransi): string
{
    return (abs($error) + $U <= $toleransi) ? 'PASS' : 'FAIL';
}

// ------------------------------------------------------------------
// Pemakaian, pakai data contoh dari bagian 1 & 2 di atas
// ------------------------------------------------------------------

$titikUkur = 50.0;
$pembacaan = [50.02, 50.01, 50.03];
$toleransi = 0.05;

$rataRata = array_sum($pembacaan) / count($pembacaan);
$error = $rataRata - $titikUkur;

$u_a = hitungTypeA($pembacaan);

$u_b = hitungTypeB([
    ['value' => 0.0004, 'distribution' => 'normal', 'faktor_cakupan' => 2], // U standar acuan
    ['value' => 0.005,  'distribution' => 'rectangular'],                   // setengah resolusi alat
]);

['u_c' => $u_c, 'U' => $U] = hitungKetidakpastianDiperluas($u_a, $u_b, k: 2);

$keputusan = keputusanIlacG8($error, $U, $toleransi);

echo "rata_rata = {$rataRata}\n";       // 50.02
echo "error     = {$error}\n";          // 0.02
echo "u_a       = {$u_a}\n";            // ~0.00577
echo "u_b       = {$u_b}\n";            // ~0.002895
echo "u_c       = {$u_c}\n";            // ~0.00646
echo "U         = {$U}\n";              // ~0.01291
echo "keputusan = {$keputusan}\n";      // PASS
```

*Keterangan struktur kode*: tiap langkah manual di bagian 2 sengaja dipecah jadi fungsi kecil sendiri (`hitungTypeA`, `hitungTypeB`, `hitungKetidakpastianDiperluas`, `keputusanIlacG8`) — bukan satu fungsi raksasa. Manfaatnya: tiap fungsi bisa dites sendiri-sendiri (unit test per komponen), dan kalau nanti ada kategori alat dengan komponen Type B beda (misal tambah "drift" atau "kondisi lingkungan"), tinggal tambah entri di array `$komponen`, nggak perlu ubah rumus intinya.

---

## 4. Yang Perlu Diingat

- Ini **contoh edukatif**, bukan kode yang benar-benar jalan di `sidik-calibration-api`. Struktur tabel di sana (lihat [[ERD Awal]]: `raw_measurements`, `uncertainty_calculations`) nyimpen tiap angka ini per baris, bukan cuma hasil akhirnya — biar bisa diaudit.
- Komponen Type B di atas cuma 2 (standar + resolusi) buat contoh. Di dunia nyata bisa nambah: drift standar, suhu/kelembapan ruang, dll — semuanya masuk `type_b_components` (JSON) sesuai [[ERD Awal]] poin desain #2.
- Kalau kamu pegang akses ke repo `sidik-calibration-api`, kode di atas bisa jadi starting point buat file service kalibrasi beneran di sana (misal `app/Services/UncertaintyCalculator.php`) — tinggal bilang kalau mau saya bantu adaptasi ke situ.

# Data Uji Viscometer — Lembar Pembanding

Sesi contoh yang sama persis dengan workbook master lab
(`Master_Olah_Data_Viscometer_CSV`). Isi lembar kerja teknisi di aplikasi
dengan angka di bawah, kirim, lalu adu hasilnya ke bagian 4.

Semua angka disalin dari `INPUT DATA.csv` dan `SERTIFIKAT.csv` — tidak ada satu
pun yang dikarang. Kalau hasil aplikasi berbeda dari bagian 4, yang salah
aplikasinya, bukan tabelnya.

---

## 1. Identitas alat & sesi

| Kolom di lembar kerja | Isi |
|---|---|
| Equipment / Nama Alat | Viscometer |
| Manufacturer (Merk) | Brookfield |
| Type | DV-11 |
| SN (No. Seri) | 8535682 |
| Range (Rentang Ukur) | 100-65000 cP |
| Resolution (Resolusi) | 0,1 cP |
| Received Date | 2026-07-31 |
| Calibration Date | 2026-07-31 |
| Location of Calibration | Insitu |
| Technician ID | JO |
| Methode | SIDIK-IK-CAL-0517_Rev.3 |
| Thermohygro used | TH-2 |

## 2. Kondisi lingkungan

| | Awal | Akhir |
|---|---|---|
| Suhu ruangan | 25,2 °C | 25,3 °C |
| Kelembaban | 57 %RH | 58 %RH |

Rata-rata master: 25,25 °C dan 57,5 %RH — tapi **jangan diketik**. Aplikasi yang
menghitungnya, dan yang tercetak di sertifikat nanti nilai terkoreksi
(25,02 °C / 56,5 %RH), bukan rata-rata mentah ini.

## 3. Model, Spindle & RPM

Bagian "Model Viscometer": pilih **DV2THA / HA** (TK = 2).

Per titik — dipilih dari daftar, bukan diketik:

| Titik | Spindle | SMC | RPM |
|---|---|---|---|
| 100 cP | HA1 | 1 | 63 |
| 1000 cP | HA2 | 4 | 62 |
| 60000 cP | HA7 | 400 | 62 |

Ketiganya berbeda dalam satu lembar. Itu bukan salah ketik master — memang
begitu sesi aslinya, dan itu sebabnya Spindle & RPM diisi per titik.

## 4. Tabel hasil

Tahap **Before** dan **After** isinya sama persis di master. Tiap sel pembacaan
berpasangan dengan sel suhu larutan.

### Titik 100 cP

| Repeat | cP | °C |
|---|---|---|
| 1 | 97,3 | 26,6 |
| 2 | 96,9 | 26,5 |
| 3 | 96,8 | 26,5 |
| 4 | 95,9 | 26,6 |
| 5 | 96,7 | 26,4 |

### Titik 1000 cP

| Repeat | cP | °C |
|---|---|---|
| 1 | 919,6 | 27,3 |
| 2 | 918,7 | 27,4 |
| 3 | 917,4 | 27,2 |
| 4 | 916,3 | 27,3 |
| 5 | 916,3 | 27,3 |

### Titik 60000 cP

| Repeat | cP | °C |
|---|---|---|
| 1 | 63181,3 | 24,6 |
| 2 | 63079,8 | 24,6 |
| 3 | 63172,1 | 24,6 |
| 4 | 63174,2 | 24,6 |
| 5 | **rusak di master** | 24,6 |

> **Sel Repeat 5 titik 60000 cP sengaja tidak diisi.** Di master isinya
> `631.74.2` — dua titik desimal, dan angka sebenarnya belum dijawab lab
> (`sidik-calibration-api/docs/pertanyaan-lab-viscometer.md` §1). Excel
> melewatkannya waktu `AVERAGE`, jadi rata-rata masternya memang rata-rata
> **empat** angka.
>
> Kalau lembar ini difoto, aplikasi menandai sel itu merah dan **tidak**
> menebaknya jadi `631,74` atau `63174,2`. Itu perilaku yang benar — biarkan
> kosong.

---

## 5. Hasil yang seharusnya keluar

Setelah lembar dikirim dan dihitung. Sumber: `SERTIFIKAT.csv` master, kecuali
dua baris yang ditandai.

### Kondisi lingkungan tercetak

| | Nilai | U95% |
|---|---|---|
| Suhu | 25,02 °C | ± 1,70293863659264 °C |
| Kelembaban | 56,5 % | ± 4,903060268852505 % |

### Calibration Report

| Titik | Standard Value | Unit Under Test | Correction | U95% |
|---|---|---|---|---|
| 100 cP | 93,87566510172147 | 96,72 | −2,8443348982785324 | 0,6336375481662154 ¹ |
| 1000 cP | 910,2887323943662 | 917,6600000000001 | −7,371267605633875 | 2,712003152654588 |
| 60000 cP | 61898,119999999995 | 63151,850000000006 | −1253,7300000000105 | 144,1619311 ² |

Yang tercetak di sertifikat dibulatkan ke **dua desimal** (`93,88` / `910,29` /
`61898,12`). Seluruh rantai hitungnya tetap presisi penuh — yang dibulatkan
hanya bentuk cetaknya.

**Standard Value bukan 100 / 1000 / 60000.** Itu label larutan di kertas. Yang
di sertifikat hasil interpolasi tabel sertifikat larutan pada suhu terukur titik
itu — dan suhu ketiga titik memang berbeda (26,52 / 27,3 / 24,6 °C).

### MPE & Fullscale

`Fullscale = TK × SMC × 10000 / RPM`, `MPE = 1 % × Fullscale + 1 % × rata-rata`

| Titik | Fullscale | MPE |
|---|---|---|
| 100 cP | 317,46031746031747 cP | 4,141803174603175 cP |
| 1000 cP | 1290,3225806451612 cP | 22,079825806451613 cP |
| 60000 cP | 129032,25806451612 cP | 1921,8410806451611 cP |

---

### ¹ ² Dua angka yang sengaja berbeda dari master

Keduanya sudah diputuskan dan tercatat di
`sidik-calibration-api/docs/pertanyaan-lab-viscometer.md`. Kalau hasil aplikasi
sama dengan master di dua baris ini, justru itu yang salah.

**¹ U95% titik 100 cP — aplikasi 0,6336, master 0,49299.** Derajat kebebasan
efektif titik itu 5,376; tabel t-student 95 % dua sisi memberi `k = 2,5706`,
sementara sel `k` di master berisi `2`. Master pH lab sendiri memakai t-student,
jadi yang menyimpang sel viscometer itu. Workbook-nya juga lembar percobaan —
`Certificate Number` dan `Order Number`-nya kosong, tidak ada sertifikat terbit
yang perlu direproduksi.

**² U95% titik 60000 cP — aplikasi 144,1619311, master 142,34.** Master memakai
lima pembacaan padahal sel kelimanya rusak; `AVERAGE`-nya sendiri sudah
menghitung empat. Aplikasi memakai empat secara konsisten (`n = 4`).

---

## 6. Cara memakai lembar ini

1. Buat sesi kalibrasi baru untuk alat Viscometer.
2. Isi bagian 1 – 3 di lembar kerja teknisi.
3. Isi tabel Before & After dengan angka bagian 4 — boleh diketik, boleh lewat
   **FOTO TABEL INI** kalau sudah dicetak di kertas.
4. Kirim, lalu buka lembar Perhitungan / pratinjau sertifikat.
5. Adu ke bagian 5. Yang boleh berbeda hanya dua baris bertanda ¹ dan ².

Kalau ada selisih di luar dua baris itu, catat titik & kolomnya sebelum
melaporkan — selisih pada satu titik dan selisih pada semuanya menunjuk ke
sebab yang berbeda.

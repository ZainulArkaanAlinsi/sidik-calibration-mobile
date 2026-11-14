# VISUAL ALAT — 48 alat, 48 gambar + cadangan untuk alat baru

Artboard E3 (48 alat) dan E5 (alat baru) di canvas Lab. Sumber SVG di
`aset/visual/` (nama berkas = kunci). Semua digambar sendiri, tanpa merek.

## 48 alat lampiran LK-285-IDN
Urutan dan rentang dari `docs/Rekap-Data-Kemampuan-Kalibrasi.md`.

| No | Kelompok | Alat | Rentang | Berkas |
|---|---|---|---|---|
| 01 | Suhu dan Kelembapan | Temperature Indicator tanpa Sensor | -20 ~ 1000 °C | `ti_tanpa_sensor` |
| 02 | Suhu dan Kelembapan | Temperatur Indikator dengan Sensor | -20 ~ 150 °C | `ti_sensor` |
| 03 | Suhu dan Kelembapan | Temperatur Transmitter | 0 ~ 150 °C | `transmitter` |
| 04 | Suhu dan Kelembapan | Termometer Gelas | 0 ~ 100 °C | `termometer_gelas` |
| 05 | Suhu dan Kelembapan | Thermocouple | -20 ~ 150 °C | `thermocouple` |
| 06 | Suhu dan Kelembapan | Oven | ambient ~ 300 °C | `oven` |
| 07 | Suhu dan Kelembapan | Bath | 0 ~ 100 °C | `bath` |
| 08 | Suhu dan Kelembapan | Inkubator | 15 ~ 100 °C | `inkubator` |
| 09 | Suhu dan Kelembapan | Furnace | 300 ~ 1000 °C | `furnace` |
| 10 | Suhu dan Kelembapan | Refrigerator | -20 ~ 10 °C | `refrigerator` |
| 11 | Suhu dan Kelembapan | Thermohygrometer | 15 ~ 50 °C | `thermohygro` |
| 12 | Massa | Timbangan (elektronik, mekanik) | 0 ~ 200 g | `timbangan` |
| 13 | Volume | Buret | 25 mL | `buret` |
| 14 | Volume | Buret Digital | 1 ~ 10 mL | `buret_digital` |
| 15 | Volume | Piston Pipette | 101 ~ 1000 µL | `piston_pipette` |
| 16 | Volume | Dispensett | 1 ~ 10 mL | `dispensett` |
| 17 | Volume | Gelas Ukur | 10 mL | `gelas_ukur` |
| 18 | Volume | Labu Ukur | 5 mL | `labu_ukur` |
| 19 | Volume | Pipet Ukur | 1 mL | `pipet_ukur` |
| 20 | Volume | Pipet Volume | 0.5 mL | `pipet_volume` |
| 21 | Volume | Picnometer | 25 mL | `picnometer` |
| 22 | Tekanan | Pressure Transmitter | 4 ~ 20 mA | `pressure_transmitter` |
| 23 | Tekanan | Pressure Gauge | 0 ~ 290 psi | `pressure_gauge` |
| 24 | Tekanan | Pressure Transducer, Recorder, Safety Valve, Manometer | 0 ~ 600 bar | `pressure_transducer` |
| 25 | Tekanan | Vacuum Gauge | -24.2 ~ 0 inHg | `vacuum_gauge` |
| 26 | Tekanan | Differential Pressure | -10 ~ 10 mbar | `differential_pressure` |
| 27 | Gaya | Mesin UTM | 0 ~ 500 kgf | `utm` |
| 28 | Gaya | Load Cell | 0 ~ 500 kgf | `load_cell` |
| 29 | Gaya | Proving Ring | 0 ~ 500 kgf | `proving_ring` |
| 30 | Aliran | Flow Meter Cairan (Totalizer) | 10 ~ 78 L | `totalizer` |
| 31 | Aliran | Flow Meter Cairan (Flowrate) | 75 ~ 191 Lpm | `flowrate` |
| 32 | Densitas | Hydrometer | 1.1 ~ 1.7 g/mL | `hidrometer` |
| 33 | Panjang | Sieve | 45 ~ 4000 µm | `sieve` |
| 34 | Panjang | Micrometer | 0 ~ 25 mm | `micrometer` |
| 35 | Panjang | Vernier Caliper | 0 ~ 300 mm | `vernier` |
| 36 | Panjang | Dial Indicator | 0 ~ 25 mm | `dial_indicator` |
| 37 | Waktu dan Frekuensi | Timer/Stopwatch | 5 ~ 3600 s | `stopwatch` |
| 38 | Waktu dan Frekuensi | Centrifuge | 60 ~ 200 rpm | `centrifuge` |
| 39 | Waktu dan Frekuensi | Infrared Tachometer | 60 ~ 7000 rpm | `tachometer` |
| 40 | Instrumen Analitik | Conductivitymeter | 25 µS | `conductivity` |
| 41 | Instrumen Analitik | pH Meter | 4 pH | `ph_meter` |
| 42 | Instrumen Analitik | Chlorin Meter | 1.74 mg/L | `chlorine` |
| 43 | Instrumen Analitik | Turbidimeter | 1 NTU | `turbidimeter` |
| 44 | Instrumen Analitik | Viscometer | 102 cP | `viscometer` |
| 45 | Instrumen Analitik | Refractometer | 1.3366 n20D | `refractometer` |
| 46 | Instrumen Analitik | DO Meter | 8.77 mg/L | `do_meter` |
| 47 | Instrumen Analitik | Spektrofotometer | 283 ~ 641 nm | `spektrofotometer` |
| 48 | Instrumen Analitik | Autoklaf | 105 ~ 121 °C | `autoklaf` |

## Alat baru yang belum digambar (termasuk kelompok baru, misalnya alat medis)
Aplikasi tidak menunggu gambar. `PetaVisualAlat.cari` mencari berurutan:
1. **Nama persis** di peta 48 alat (+ alat tambahan yang sudah digambar).
2. **Alias ejaan** ("jangka sorong" → Vernier Caliper).
3. **Kata kunci bentuk** di nama → salah satu 7 gambar bentuk:
   `bentuk_genggam` (meter, tester, detektor, oksimeter, termometer) ·
   `bentuk_meja` (analyzer, fotometer, pompa, monitor, EKG) ·
   `bentuk_lemari` (oven, chamber, freezer, kabinet, sterilisator) ·
   `bentuk_kaca` (labu, gelas, tabung, flask, kuvet) ·
   `bentuk_probe` (probe, sensor, elektroda, transmitter) ·
   `bentuk_putar` (centrifuge, shaker, stirrer, mixer) · `pressure_gauge` (gauge).
4. **Kelompok besaran** yang dikenal → gambar kelompok.
5. **`bentuk_umum`** → tidak pernah kosong.

Contoh yang sudah digambar di luar lampiran: `tensimeter`, `infus_pump`.

Penjaga: `test/visual_alat_cakupan_test.dart`
- GAGAL bila salah satu dari 48 nama Rekap CMC tidak mendapat gambar sendiri,
  atau bila berkas yang dirujuk peta tidak ada di assets.
- MENCETAK (tidak gagal) daftar nama alat dari data contoh/fixture yang jatuh ke
  langkah 3–5: itu daftar kerja gambar berikutnya.

Menambah gambar untuk alat baru = prompt **G1** di `PROMPT.md` (satu PR kecil:
SVG + PNG + satu baris di peta; layar tidak disentuh).

## Memasang di Flutter (tanpa paket baru)
1. Ekspor tiap SVG ke PNG transparan 240/480/720 px
   (`rsvg-convert -w 240 x.svg -o assets/images/visual/x.png`, `-w 480` ke `2.0x/`,
   `-w 720` ke `3.0x/`). JANGAN menambah flutter_svg.
2. Daftarkan `assets/images/visual/` di `pubspec.yaml`.
3. Pakai `VisualAlat(nama:, kelompok:, ukuran:)` dari `flutter/visual_alat.dart`.

## Ukuran pakai
188 hero · 176 ubin besar · 132–150 kartu identitas · 104–140 ubin grid/katalog ·
92 kartu draf · 48–56 ubin ikon baris · 44 baris padat.

## Menggambar alat baru (agar tetap satu gaya)
Kanvas 240 × 240, alat duduk di lantai (y ≈ 214), bayangan lantai elips navy 30 % → 0.
Cahaya kiri atas. Pakai `<defs>` yang sama dengan berkas mana pun di `aset/visual/`:
badan putih → #E7ECF1 → #C3CCD6 · logam #7F8A96 ↔ putih ↔ #6F7A86 · krom radial ·
kaca biru muda transparan + garis kilau putih · cairan #7CC4F6 → #2F86D6 ·
kuningan #F6DE9A → #9C7424 · badan navy #3A5A86 → #16304F · layar #0E1A2B dengan
angka mono #8FE3FF. Angka di layar = nilai wajar alat itu, satuan benar.
Tanpa merek, tanpa orang, tanpa latar, tanpa foto stok. SVG murni.
Cek hasilnya: render semua ke satu lembar kontak (`rsvg-convert` + `montage`)
dan bandingkan dengan gambar lain sebelum PR.

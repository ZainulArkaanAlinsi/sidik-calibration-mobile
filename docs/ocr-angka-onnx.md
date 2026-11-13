# OCR angka tulisan tangan: mesin PP-OCR (TFLite) di balik sakelar

Diperbarui 13 Nov 2026. Dasar: laporan rig `_agents_workspace/ocr-kamera-20261112/10-uji-mesin-angka.md`
(repo API, tidak di-commit; bagian 9 = konversi TFLite) dan rig `C:\Users\USER\sidik-ocr-eval\`.
Nama berkas ini masih `onnx` dari masa pemilihan runtime; banyak rujukan (`§10`) menunjuk ke sini, jadi
nama dan nomor bagian dipertahankan.

> **SEMUA ANGKA AKURASI DI DOKUMEN INI SINTETIS** (digit MNIST + font bergaya tulisan tangan di atas
> latar sel buatan). Bukan tulisan teknisi di kertas yang difoto. Tidak ada klaim akurasi lapangan.

**Keputusan runtime (13 Nov 2026): TFLite lewat `tflite_flutter` 0.12.1 (LiteRT 1.4.0), runtime yang SUDAH
ada di APK.** ONNX Runtime tidak dipakai (+29..57 MB). Model ONNX asli dikonversi ke `rec_en_f32.tflite`
(float32, 7,83 MB) dengan `onnx2tf` tanpa mengubah operator; di rig hasilnya IDENTIK dengan ONNX Runtime
pada seluruh 5.900 sel uji (teks, skor, keputusan; bagian 3.4). INT8 dan float16 tidak dipakai.

## 0. Status (apa yang ada, apa yang belum)

| bagian | status |
|---|---|
| Lapisan Dart murni `lib/services/ocr_angka/` (praproses, dekoder CTC, gerbang format, pagar tinta, status sel) | ADA, diuji di CI |
| Pemotong sel v2 `pemotong_sel.dart` (varian "luas" rig) + keadaan baru "bertinta tapi tak terbaca = `perluCek`" + pagar tinta `gelap` saja (bagian 12) | ADA, diuji di host (citra sintetis, uji mutasi, paritas Dart-vs-rig); **kecepatan dan akurasi di HP TIDAK TERBUKTI** |
| `PembacaSelOnnx` di balik sakelar `PAKAI_MESIN_ANGKA` (bawaan MATI; nama lama `PAKAI_MESIN_ANGKA_ONNX` tetap diterima), ML Kit sebagai cadangan | ADA, diuji dengan sesi tiruan |
| Layar diagnostik `Ukur OCR` (debug / `TAMPILKAN_UKUR_OCR`) | ADA, diuji (logika + layar); ML Kit bisa diukur SEKARANG, mesin angka bila dibangun dengan sakelar |
| UX isi cepat di layar review (urutan kertas, keypad di layar lega / papan ketik sistem di layar sempit, konfirmasi dan lanjut) | ADA, aktif untuk semua pembaca |
| Adaptor runtime `SesiInferensiTflite` (+ `PelariTfliteIsolate`, `InterpreterMentahTflite`) | ADA, diuji dengan pelari tiruan dan isolate sungguhan; **runtime native TIDAK diuji di host** |
| Model `assets/models/ocr_angka_en.tflite` (7,83 MB) + meta di APK | ADA di APK walau sakelar mati; DIMUAT hanya bila sakelar menyala dan sha256-nya cocok dengan yang dipatok |
| `integration_test/ocr_tflite_hp_test.dart` (model sungguhan di perangkat, 21 crop golden) | ADA, **belum pernah dijalankan** |
| Inferensi nyata di HP/tablet, XNNPACK Android, latensi, memori, akurasi pada foto nyata | **TIDAK TERBUKTI** |

Sakelar mati (bawaan rilis): `buatSesiOcrAngkaProvider` bernilai `null`, `pabrikPembacaPindaiProvider`
memberi ML Kit murni, model tidak dibuka. Sakelar menyala: model dimuat malas pada sel pertama; gagal
memuat runtime/model (atau galat saat membaca satu sel) → sisa lembar dibaca ML Kit, tanpa crash; sel
bertinta yang tak muat di kanvas model (lebar > 320 px) dibaca ML Kit satu per satu, mesin tetap aktif.
Pemuatan runtime yang gagal diingat per proses (paling banyak 2 percobaan, lalu aset tidak dibaca lagi).
Aturan keras tetap: OCR hanya di HP, hasil hanya usulan, sel kosong tetap kosong, tulisan tangan tidak pernah
hijau, `siap_pindai`/pintu server tidak disentuh, tidak ada perhitungan kalibrasi di HP.

## 1. Arsitektur

```
foto → (registrasi halaman, kode formulir)        ← tidak berubah
     → potong sel → PembacaSel
          ML Kit (bawaan)   |   PembacaSelOnnx (sakelar developer)
                                 │ aturan format sel dari templat? tidak ada → ML Kit
                                 ▼
                           MesinAngka.baca(crop, AturanFormatSel)
                             1. PagarTinta         tanpa tinta → kosong, model tidak dijalankan
                             2. PraprosesSel       BGR, tinggi 48, (x/255-0,5)/0,5, pad nol ke 320
                             3. SesiInferensiCtc   ← jahitan; implementasi: SesiInferensiTflite (LiteRT)
                             4. DekoderCtc         kolom whitelist, CTC greedy, skor jalur
                             5. putuskanSelAngka   ambang jalur + gerbang format
                                 ▼
          kosong → teks null | perluCek → keyakinan 0,0 (MERAH, kotak kosong)
          usulanKeyakinanTinggi → keyakinan = jalur (KUNING, wajib dicek)
     → FotoReviewScreen (urutan kertas, keypad, konfirmasi per sel)
```

`BacaanSel` tidak diubah; statusnya dipetakan ke aturan yang sudah ada (`NilaiVonisFoto`), jadi
`vonis_sel_foto.dart`, `siap_pindai`, dan penjaga kompresi tahap 1 (`foto_untuk_ocr.dart`) tidak disentuh.
`JalankanPindaiAsli` hanya menambah satu hal: bila pembacanya `PembacaSelBerformat`, tiap sel membawa
`AturanFormatSel.dari(sel.aturan)`.

## 2. Parameter

| parameter | nilai | sumber |
|---|---|---|
| model | `en_PP-OCRv5_mobile_rec` rev `3fafbc3b` dikonversi ke `rec_en_f32.tflite` (`onnx2tf` 2.6.9, operator tak diubah), **7.829.508 bita**, sha256 `e1121d54…43b7`, Apache-2.0 | rig; `assets/models/ocr_angka_en.meta.json`, dipatok di `muat_mesin_bawaan.dart` |
| masukan (praproses) | `PraprosesSel`: `[1,3,48,W]` float32 CHW BGR, `W = max(320, ceil(48·lebar/tinggi))`, pad nol di kanan | `MesinPaddle._praproses` rig |
| masukan (model) | `x` `[1,48,320,3]` float32 NHWC BGR, `(p/255−0,5)/0,5`, pad nol SETELAH normalisasi; `SesiInferensiTflite.chwKeNhwc` hanya menata ulang. Lebar TETAP 320: sel yang hasil resize-nya > 320 px ditahan (`ukuranTakWajar`) | `meta.json` rig |
| keluaran | **peluang softmax (bukan logit)** `[1,40,438]` float32; kolom whitelist = indeks kelas `[0,1..10,76,74,75]` (blank, 0–9, `.`, `,`, `-`); `KeluaranCtc.sudahPeluang = true` supaya tidak di-softmax ulang | `inference.yml`, `meta.json` rig |
| dekode | normalkan ulang ke 14 kolom, argmax per frame, buang blank, lebur kembar (blank memisahkan) | `dekode.py` rig |
| skor sel | `jalur` = rata-rata geometrik peluang maks SEMUA frame; 0 bila teks kosong | `dekode.py` rig |
| ambang awal | **0,990** pada `jalur` | rig, B-en |
| gerbang format | tepat `desimal` digit di belakang pemisah, `-` hanya bila boleh negatif, 1–8 digit bulat, ≤ 8 karakter | `lolos_format` rig |
| pagar tinta | tolak bila `gelap < 0,02` (margin 15%, tinta > 0,30). Cabang `kontras` DICABUT 13 Nov 2026 (kena tekstur kertas di foto nyata). Ambang SEMENTARA, dari 2 foto | bagian 12 (dulu: `gelap < 0,002` DAN `kontras < 0,02`, sintetis, bagian 3.3) |
| pemotong sel | `PemotongSel`: jendela meluber ±0,6 tinggi baris, garis tabel mendatar dihapus di tepi atas/bawah kotak, goresan yang melintas garis dijembatani, komponen milik baris, pangkas ke kotak tinta; ukuran relatif terhadap tinggi baris | rig `potong_luas` (varian D), bagian 12 |

Skor `jalur` **bukan persen** (ECE 0,44–0,57): layar review tidak menampilkannya sebagai persen saat
sakelar menyala (`FotoReviewScreen.tampilkanPersen: false` → "Usulan mesin: skor mentah, bukan persen").

## 3. Angka (SINTETIS)

### 3.1 Dari rig (uji tetap 5.900 crop: 4.400 berisi, 1.500 kosong)

| | B-en (dipilih) | B (16,5 MB) | A-INT8 (CRNN kita) |
|---|---:|---:|---:|
| ukuran model | 7,85 MB | 16,53 MB | 0,63 MB |
| latensi median/sel, laptop i7, 1 thread | 59,1 ms | 66,3 ms | 2,0 ms |
| ambang 0,990 (gerbang format): cakupan / akurasi terjawab | 21,9% / 94,3% | 13,0% / 95,3% | |
| kosong biasa / sulit terisi pada 0,990 | 0,1% / 1,7% | 0,0% / 0,7% | |
| tanpa gerbang format: kosong biasa terisi pada 0,98 | 15,3% | 11,3% | 0,0% |

Gerbang format adalah penentu. Risiko yang tetap ada: tanda minus hilang (B-en: 31% dari minus pada
bacaan mentah; di antara jawaban lolos gerbang 16% dari sel negatif), pemisah hilang (±27%), sisa tulisan
tetangga di tepi crop (1,3–8% sel kosong sulit terisi).

### 3.2 Paritas praproses Dart (diukur di sini, ad hoc, skrip tidak di-commit)

- Pengubah ukuran Dart vs `cv2.resize(INTER_LINEAR)` pada 3 crop uji: selisih maks 1 tingkat abu pada
  11–13% nilai (jalur SIMD OpenCV membulatkan lain). Dikunci di `test/ocr_angka_praproses_test.dart`.
- Ujung ke ujung: 600 crop uji (setiap 9), tensor dari **praproses Dart** dijalankan di ONNX Runtime
  Python lalu didekode dengan kode rig, dibanding prediksi rig (`pred_B_en_uji.csv`): teks identik
  **581/600 (96,8%)**; selisih skor `jalur` median 0,00025, p95 0,0032. Dari 130 sel yang skornya ≥ 0,99
  di salah satu jalur, teks identik 130/130, tetapi **keputusan menjawab/menahan berbeda pada 8 sel**
  (3 hanya Dart, 5 hanya rig) karena skor melintasi 0,990. Kesimpulan: tujuan ≥ 99% identik di laporan rig
  tidak tercapai pada sel berskor rendah (yang memang ditahan); ambang HARUS dihitung ulang di runtime final.
- Paritas dekoder: 18 contoh logits rig → teks identik, skor dalam 2e-4
  (`test/ocr_angka_dekoder_test.dart`, fixture `test/fixtures/ocr_angka/`, SINTETIS).

### 3.3 Pagar tinta dan aturan tepi (diukur di sini pada 5.900 crop sintetis)

Pagar yang menolak bila SALAH SATU ukuran rendah membuang 7,6–33,9% jawaban benar. Yang dipakai
(KEDUANYA rendah: `gelap < 0,002` dan `kontras < 0,02`): 0/4.400 sel berisi dan 0/908 jawaban benar
tertolak, tetapi hanya **12,8% sel kosong biasa** dan 5,3% sel kosong sulit tertolak. Hemat waktu jauh
di bawah perkiraan awal (25–30%). Garis tabel dan noise TIDAK disaring pagar ini; penahannya gerbang
format + ambang (kosong biasa terisi ≈ 0%).

Aturan geometri "tulisan menyentuh tepi crop → abstain" (dari posisi frame CTC) dicoba pada 1.200 sel
berisi + 300 sel tetangga (B-en, 0,990, format seperti rig): sel tetangga yang terisi 10/300 (3,3%).
Menolak bila karakter pertama/terakhir ≤ 0 frame dari tepi menjatuhkan 4 dari 248 jawaban benar dan
hanya menahan 1 dari 10 tetangga; ≤ 1 frame menjatuhkan 37/248 untuk menahan 4/10. **Tidak dipakai.**
Penahan sisa tetangga tetap teknisi yang memeriksa tiap usulan.

Tanpa jumlah desimal (gerbang umum), tetangga terisi 56/300 (19%) lawan 3,3% dengan desimal diketahui.
Karena itu mesin tidak dipakai untuk sel tanpa `desimal` (bagian 5).

> **Diganti 13 Nov 2026 (foto nyata):** angka pagar di atas (`gelap < 0,002` DAN `kontras < 0,02`) tidak
> berlaku lagi; sekarang hanya `gelap < 0,02` (bagian 12).

### 3.4 Paritas TFLite (SINTETIS)

**Di rig** (laporan bagian 9; `tf.lite.Interpreter` TF 2.21 dengan XNNPACK, Windows x86, 1 thread):
`rec_en_f32.tflite` lawan ONNX Runtime 1.31.1 pada 5.900 sel uji + 600 sampel tetap: teks identik 100%,
identik pada skor ≥ 0,99 (1.277 sel) 100%, keputusan jawab/tahan beda pada 0,990 = **0** (tanpa dan dengan
gerbang format), cakupan dan akurasi terjawab sama (selisih 0,00 poin). Selisih peluang maks 8,8e-4 (median
2e-10); selisih `jalur` median 6e-8, p95 9,5e-7. Silang-cek kernel referensi (`ai-edge-litert`, tanpa
XNNPACK): teks identik 100%, selisih maks 1,9e-4. Latensi laptop i7 (x86, 1 thread, praproses + inferensi +
dekode, bergantian dalam satu proses): TFLite 53,7 ms median lawan ONNX Runtime 66,2 ms; ini BUKAN
prediksi untuk HP (perkiraan kasar 2–5× lebih lambat, tidak diukur).

**Rantai Dart** (diukur SEKALI di sini, ad hoc; skripnya tidak di-commit): praproses Dart + `chwKeNhwc` Dart +
model `assets/models/ocr_angka_en.tflite` ASLI dijalankan lewat `ai-edge-litert` Python (1 thread, tanpa
XNNPACK) + `DekoderCtc` Dart, pada 295 crop uji (setiap ke-20), dibanding `pred_B_en_tflite_f32_uji.csv`:

- 7 sel ditahan pagar tinta (rig tidak menjawab satu pun dari itu); 288 dibaca model; 0 ditahan pagar lebar 320.
- teks identik **285/288 (98,96%)**; pada sel yang skor rig-nya ≥ 0,99: **58/58**. Tiga sel yang berbeda
  semuanya berskor rig < 0,96 (ditahan di kedua sisi, jadi tidak mengubah keputusan).
- selisih `jalur` (teks sama): median 2,3e-4, p95 2,4e-3, maks 1,0e-2 (sumber: bilinear Dart lawan OpenCV,
  bagian 3.2).
- keputusan jawab/tahan (0,990 + gerbang format) beda pada **1 dari 288** (skor 0,9903 di rig, 0,9892 di
  Dart: melintasi ambang); tanpa gerbang format 2.
- 21 crop yang dibundel (`integration_test/fixtures/ocr_tflite/`): 13/13 sel "yakin" teks identik, selisih
  skor maks 1,7e-3, keputusan 21/21 sama.

Ini membuktikan penataan NHWC, urutan kanal BGR, pad nol, dan dekoder peluang tidak menggeser hasil model
asli. Ini **TIDAK membuktikan** LiteRT 1.4.0 di Android (kernel ARM, XNNPACK Android, operator `BATCH_MATMUL`).

## 4. Keputusan runtime: TFLite (LiteRT yang sudah ada)

Batas pemilik: delta bersih ≤ ±12 MB per APK dua-ABI (`arm` + `arm64`, `--target-platform
android-arm,android-arm64`). APK rilis v1.0.791: 74.991.208 bita.

| opsi | delta APK dua-ABI | keputusan |
|---|---:|---|
| **LiteRT 1.4.0 lewat `tflite_flutter` 0.12.1 (sudah ada) + model `.tflite` float32** | **+7,83 MB** (model; runtime 0 MB) | **DIPAKAI** |
| `flutter_onnxruntime` 1.9.0 → ORT android 1.28.0 + model ONNX | +57,1 MB mentah (+28,3 MB bila .so dikompresi); +49,9 MB bila `tflite_flutter` dibuang | ditolak (> 12 MB) |
| ORT 1.28.0 arm64 saja (32-bit jatuh ke ML Kit) | +29,4 MB (+14,9 MB) | ditolak |
| `onnxruntime-mobile` 1.18.0 (Mei 2024, paket tidak dirilis lagi) | ≈ +8,5 MB bila `tflite_flutter` dibuang (+15,7 MB bila tidak) | ditolak: butuh format `.ort` + substitusi Gradle, belum terbukti, paket usang |
| ORT build minimal sendiri | beberapa MB per ABI (perkiraan dokumentasi ORT, tidak diukur) | ditolak: butuh CI build AAR sendiri |

Ukuran pustaka native (diukur dari AAR di Maven Central, bukan dari APK): ORT 1.28.0 `libonnxruntime.so` +
jni 28,75 MB (arm64-v8a) + 20,47 MB (armeabi-v7a) = 49,2 MB; LiteRT 1.4.0 `libtensorflowlite_jni.so`
4,32 + 2,87 = 7,2 MB (sudah di APK). .so disimpan tanpa kompresi di APK (AGP bawaan, minSdk ≥ 23); delta
APK nyata tidak diukur.

### Beban sesudah keputusan (13 Nov 2026)

- **Paket baru: NOL.** `pubspec.yaml` hanya menambah entri aset dan mengubah komentar; `pubspec.lock` tidak
  berubah oleh pekerjaan ini.
- **`tflite_flutter` kini TERPAKAI** (sebelumnya tidak terpakai oleh jalur mana pun). Pemakainya
  `lib/services/ocr_angka/interpreter_mentah_tflite.dart` (satu-satunya berkas yang menyentuh pustaka native).
  Berkas itu mengimpor `dart:ffi`, yang ditolak kompilator web, jadi `sesi_inferensi_tflite.dart` memakai impor
  bersyarat (`if (dart.library.ffi)`) dengan `interpreter_mentah_tflite_stub.dart` sebagai pengganti di web:
  `flutter build web` hijau (260 detik, lokal), dan mesin angka di web berakhir sebagai `runtimeGagalDimuat` →
  ML Kit. Android, iOS, dan desktop (Studio) tetap memakai berkas asli.
- **Aset:** `assets/models/ocr_angka_en.tflite` **+7.829.508 bita** (+7,83 MB mentah; APK mengompres aset
  bila `aapt` tidak mengecualikan `.tflite`, perkiraan ±7,2 MB, tidak diukur pada APK nyata) + meta 1 KB +
  ±126 KB crop uji sintetis (`integration_test/fixtures/ocr_tflite/`, hanya dipakai tes perangkat). Ikut APK
  **walau sakelar mati**; yang menahannya dimuat adalah sakelar dan pin sha256.
- **Dihapus karena terbukti mati** (grep: tak dirujuk dari `lib/`, `studio/`, `integration_test/`; hanya
  `test/pembaca_digit_tflite_test.dart`): `lib/services/pembaca_digit_tflite.dart`,
  `lib/services/interpreter_tflite.dart`, tes-nya, dan baris PENGECUALIAN di `tool/cek-berkas-yatim.sh`
  (408 baris Dart). Efek ke ukuran APK ≈ 0 (kode yang tak terjangkau sudah dibuang tree-shaker; tidak ada aset
  digit di repo); keuntungannya satu adaptor `tflite_flutter` saja, bukan dua. Sakelar `pakaiModelDigit`
  dipertahankan (bawaan mati, dijaga tes) tetapi tidak membaca apa pun.

## 5. Kesenjangan templat (verifikasi di repo API `sidik-api-undangan-aman`, `62ab1b4d`)

Sumber: `app/Services/Ocr/TemplateLembarKerja.php` (`aturan()`, `aturanPembacaan()`), dipinjam utuh oleh
`FormulirAsli`. `sel[kunci].aturan` memuat:

- `desimal` — **TERSEDIA per sel** tetapi `null` bila server tidak tahu resolusi/desimal alat
  (templat diminta tanpa `equipment_id`, atau profil tak menyebutnya). Pada 5 dari 6 fixture templat di repo ini
  (`test/assets/template-asli-*.json`; oven tidak diperiksa) hanya conductivity yang terisi (60/60 sel);
  micrometer, pressure gauge, TIDS `desimal: null`; pH tanpa `aturan`. Respons produksi per formulir belum diperiksa: **perlu dicek dengan GET nyata pakai alat.**
- `izinkan_minus` — **TERSEDIA tetapi konstan `false`** untuk pembacaan alat, jam, dan suhu. Sebelum PR
  ini app tidak membacanya (`AturanSelAsli.izinkanMinus` baru). Rig mengandaikan 22% sel boleh negatif;
  menurut templat sekarang hampir tidak ada. `min` bisa negatif (pita alat) dan dianggap membolehkan minus.
  Server tidak punya penanda "boleh negatif" terpisah dari kedua bidang itu.
- Sel `tipe: jam`/`suhu` dan isian lingkungan: tanpa `desimal` di sisi app → tetap ML Kit.
- `desimal > 4`: di luar yang diukur rig (format `d4`) → tetap ML Kit.
- Panjang: rig memakai ≤ 8 karakter; server mengizinkan `maks_digit` 9. Yang lebih dari 8 ditahan.
- **Sel bulat tanpa desimal di kolom berdesimal** (baris M0 timbangan Piston: teknisi menulis "0", bukan
  "0.0000"): templat TIDAK punya penanda per sel untuk itu (tidak ada `desimal` per baris, `bulat`, atau
  daftar bentuk tulisan yang sah). **PERMINTAAN FIELD SERVER: `aturan.boleh_bulat` (bool, per sel).**
  HP sudah membacanya (`AturanSelAsli.bolehBulat`, hanya bool sungguhan) dan, hanya bila `true`, gerbang
  format meloloskan string persis "0" (`AturanFormatSel.nolBulat`; nilainya sama dengan 0,0000). Selama
  server belum mengirimnya hasilnya `false`: "0" di sel berdesimal ditahan (`perluCek`), arah yang aman.
  Turunan lama `nominal == 0` DICABUT (review 13 Nov): server mengirim `nominal = 0` (`titik_ukur 0,0`)
  untuk SEMUA baris grid Enclosure/Autoklaf (`TemplateLembarKerja.php` ±396-442 dan `aturanPembacaan`
  ±586, repo API), sehingga "0" polos lolos di sel suhu. Server juga perlu menetapkan baris mana yang
  boleh bulat (M0 Piston) dan mematuhi `maks_digit` di HP (kini HP membatasi 8).

Gerbang bertahap yang dipakai: ada `desimal` → gerbang penuh; tidak ada → mesin tidak dipakai (bukan
gerbang umum yang lebih longgar). Tidak ada nilai yang dikarang.

## 6. Mengukur di tablet

Model sudah ada di APK (aset) dan dibaca dari sana: **tidak perlu `adb push` model**. Semua langkah di
bawah mensyaratkan APK dibangun dengan sakelar developer: `--dart-define=PAKAI_MESIN_ANGKA=true`
(tanpanya `buatSesiOcrAngkaProvider` `null` dan mesin angka berhenti dengan pesan "Mesin angka tidak aktif").
Tidak ada emulator/APK lokal di laptop pemilik; bangun lewat jalur yang biasa.

### 6.1 Tes otomatis di perangkat (21 crop golden)

```
flutter test integration_test/ocr_tflite_hp_test.dart -d <id-perangkat>
```

(`flutter devices` / `adb devices` untuk id.) Tes memuat model dari aset lewat gerbang rilis penuh (sha256
dipatok, kontrak tensor diperiksa), membaca 21 crop sintetis dari `integration_test/fixtures/ocr_tflite/`
dan memeriksa: sel "yakin" (skor rig ≥ 0,995) → teks IDENTIK dengan rig, selisih `jalur` ≤ 0,01, jadi
usulan; sel "ditahan"/"kosong" → tidak pernah jadi usulan; panggilan bersamaan = berurutan; lalu mencetak
satu baris `OCR-TFLITE:` berisi latensi per sel (putaran dingin dan hangat, median/p95). Tanpa perangkat
Android tes ini SKIP. **Belum pernah dijalankan: TIDAK TERBUKTI** sampai baris `OCR-TFLITE:` ada di laporan.

Set besar dari folder perangkat (opsional): `integration_test/ocr_onnx_hp_test.dart` (nama lama; paritas
terhadap `pred_rig.csv` ≥ 95% dan latensi pada ≤ 200 sel).

### 6.2 Layar `Ukur OCR`: ML Kit lawan mesin angka pada set yang SAMA

1. Bangun debug (layar tampil otomatis) atau rilis dengan `--dart-define=TAMPILKAN_UKUR_OCR=true`, keduanya
   dengan `--dart-define=PAKAI_MESIN_ANGKA=true`.
2. Titipkan set ke folder app (`adb push`, tanpa izin penyimpanan). Folder:
   `/sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur/` berisi `labels.csv`
   (`file,teks[,desimal,bertanda]`) dan crop dengan nama yang sama. Set kecil siap pakai (21 crop sintetis +
   `labels.csv`, dari repo ini):
   `adb shell mkdir -p /sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur` lalu
   `adb push integration_test/fixtures/ocr_tflite/. /sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur/`
   (`golden.json` ikut terkirim; tidak dibaca layar). Set besar: rig `sidik-ocr-eval\data\uji` (crop +
   `labels.csv`, SINTETIS) atau crop foto nyata.
3. Profil → Sistem → **Ukur OCR (pengembang)**. Pilih **ML Kit** → Mulai (folder, batas sel, dan label
   sama). Catat ringkasan, lalu pilih **Mesin angka** → Mulai pada folder yang SAMA. Hasil tiap mesin:
   akurasi terjawab, cakupan, exact, isi-palsu, latensi median/p95 per sel (waktu per sel mencakup pagar
   tinta + praproses + inferensi + dekode; sel kosong tanpa tinta tidak menjalankan model). Tersimpan
   `hasil.csv` + `hasil_mlkit.csv` / `hasil_mesin_angka.csv` (kolom `file,teks,keyakinan` plus `status,ms`).
   `hasil.csv` ditimpa tiap putaran; yang tetap per mesin adalah `hasil_<mesin>.csv`.
4. Banding di laptop: `python muat_foto_nyata.py <folder> --mesin B_en --mlkit hasil_mlkit.csv`.

Sel kosong tanpa kolom `desimal`: layar memakai satu asumsi (desimal 2, tanpa minus) untuk semuanya;
isi kolom `desimal` per baris untuk ukuran isi-palsu yang jujur.

## 7. Batas dan yang belum terbukti

- Inferensi NYATA di perangkat, latensi tablet (perkiraan laporan: 2–5× laptop ≈ 110–270 ms/sel; satu
  lembar ±150 sel ≈ 15–45 detik tanpa optimasi lawan target ≤ 8 detik), memori puncak, dan paritas Android:
  **belum**. Termasuk yang spesifik TFLite:
  - **LiteRT 1.4.0 memuat model ini?** Rig memakai TF 2.21 (x86) dan `ai-edge-litert` 2.1.2 (kernel
    referensi), bukan `libtensorflowlite_jni.so` 1.4.0 di ARM. Model hanya memakai operator versi 1 (18 jenis,
    342 operator, tanpa CUSTOM/Flex), tetapi `BATCH_MATMUL` (13 buah) dan penguraian `HardSigmoid` (30×
    `MUL`+`ADD`+`RELU_0_TO_1`) belum pernah dijalankan di LiteRT 1.4.0. Gagal memuat = `runtimeGagalDimuat` →
    ML Kit, tanpa crash (diuji dengan pustaka native yang memang tidak ada di mesin test).
  - **XNNPACK di Android:** app hanya menyetel jumlah thread (setengah inti, 2–4); delegate TIDAK ditambahkan
    eksplisit. Apakah delegate XNNPACK bawaan aktif di build LiteRT 1.4.0 tidak diperiksa. Tanpa XNNPACK
    jalurnya kernel referensi (di Windows 5× lebih lambat: 298 lawan 58 ms), yang bisa membuat latensi HP
    jauh di atas perkiraan. Ukur sebelum menambah delegate.
  - **Memori dan umur model:** `Interpreter.fromBuffer` menyalin model ke heap native dengan `calloc` yang
    tidak pernah dibebaskan paket, juga oleh `close()` (±7,8 MB bocor per pemuatan). Alur pindai membuat
    `PembacaSelOnnx` baru untuk TIAP foto, jadi tanpa tindakan tiap foto memuat ulang model (baca aset,
    sha256, spawn isolate, urai flatbuffer) dan membocorkan 7,8 MB lagi. Karena itu
    `buatSesiOcrAngkaProvider` memberi `PabrikSesiTfliteBersama`: model dimuat SEKALI per proses dan dilepas
    saat provider dibuang; `tutup()` per foto tidak menutupnya. Harganya: sesudah pindai pertama model
    (perkiraan ±20 MB: salinan native + bobot XNNPACK + isolate) tetap resident sampai proses berakhir.
    Puncak sementara saat muat: byte aset + salinan ke isolate pekerja + salinan native + bobot yang dikemas
    XNNPACK. Semuanya perkiraan, TIDAK diukur. Alternatif bila resident dipersoalkan: `Interpreter.fromFile`
    (mmap, tanpa salinan Dart/`calloc`) dengan berkas sementara, atau pelepasan setelah menganggur.
  - **Kegagalan muat diingat, jatahnya dibatasi.** Tiap percobaan memuat yang gagal juga membocorkan ≥ 7,8 MB
    native, jadi pabrik menyerah sesudah 2 pemuatan gagal per proses (`batasGagal`): sesudahnya
    `muatMesinAngka` (parameter `menyerah`) langsung `runtimeGagalDimuat` TANPA membuka sumber model, tanpa
    membaca aset 7,8 MB, tanpa membuka isolate. Pekerja yang MATI sesudah berhasil dimuat (`PelariTflite.mati`)
    dibuang dan dimuat ulang paling banyak SEKALI per proses (`batasMuatUlang`); kematian berikutnya membuat
    pabrik menyerah. Ingatan ini hidup selama provider (≈ proses); memulai ulang app mencoba lagi.
  - **Biaya per foto yang TERSISA:** gerbang `muatMesinAngka` tetap membaca aset 7,8 MB dan menghitung
    sha256-nya tiap foto sebelum pabrik bersama dipanggil (kecuali sudah menyerah). Tidak diukur di perangkat
    (perkiraan puluhan sampai ratusan milidetik). Menyimpan hasil verifikasi berarti membuat gerbang stateful di
    dua tempat; sengaja tidak dilakukan.
  - **Isolate:** `IsolateInterpreter` bawaan paket TIDAK dipakai (diam-diam kembali bila sibuk, lalu
    membaca keluaran lama; menggantung selamanya bila satu sel melempar galat). Pekerja sendiri:
    `PelariTfliteIsolate` (id per permintaan, galat dikirim balik, batas waktu 60 detik per sel dan 60 detik
    untuk memuat, penutupan menunggu sel yang berjalan paling lama 5 detik, pekerja yang mati ditandai
    sehingga sel berikutnya gagal seketika dan `tutup()` tidak menunggu). Diuji dengan isolate sungguhan dan
    interpreter tiruan; kematian pekerja disimulasikan dengan `Isolate.exit()`, BUKAN dengan kegagalan native
    sungguhan (crash di pustaka native mematikan seluruh proses, bukan hanya isolate).
- Akurasi pada foto nyata: belum ada satu pun. Kurva sintetis tidak boleh dikutip sebagai akurasi lapangan.
- Ambang 0,990 dipilih di runtime laptop pada data sintetis; geser sedikit (±0,003) membalik keputusan
  sebagian sel (3.2, 3.4: 1 dari 288 sel melintasi ambang pada rantai Dart). **Konfirmasi di perangkat**
  dengan runtime final dan hitung ulang pada foto nyata.
- **Lebar kanvas tetap 320.** Sel BERTINTA yang hasil resize-nya > 320 px (lebar:tinggi > 6,67:1) ditahan
  `MesinAngka` (`ukuranTakWajar`, model tidak dijalankan) dan `PembacaSelOnnx` mengalihkannya ke ML Kit,
  persis seperti `keluaranTakValid`: sel itu tidak hilang dari review dan tidak berisi teks dari model.
  Mesin tetap aktif untuk sel lain. Sel yang memang kosong (di bawah pagar tinta) tetap kosong. ONNX dinamis
  akan membacanya dengan aspek utuh. Di set sintetis maksimum 277 px, jadi tak ada yang kena; pada foto nyata
  dengan padding sel besar bisa. Layar `Ukur OCR` memakai `bacaLengkap` (mesin saja, tanpa ML Kit), jadi sel
  itu tampak sebagai status `kosong` dengan teks kosong pada sel berisi: itu cara menghitung berapa banyak
  sel yang beralih ke ML Kit sebelum sakelar menyala. Bila banyak, jalurnya: model kedua W=480.
- Sisa tulisan tetangga (3,3%) dan minus hilang tetap lolos sebagai usulan; hanya pemeriksaan teknisi
  per sel yang menahannya (tes "BATAS DIKETAHUI" di `test/ocr_angka_keputusan_test.dart`).
- Urutan review kini urutan kertas (bukan merah dulu); alasan dan pengamannya di bagian 10.
- Paritas bagian 3.2 diukur terhadap model rig sebelum berkas model di rig diubah proses lain (agen
  konversi TFLite). Tidak diukur ulang; jangan menjalankan ulang terhadap rig tanpa memeriksa sha256
  `inference.onnx` (`b5f833df…`). Paritas TFLite (3.4) memakai `rec_en_f32.tflite` sha256 `e1121d54…43b7`.
- Kontrak tensor diperiksa setelah model dimuat (`SesiInferensiTflite.periksaKontrak`): masukan
  `[1,48,320,3]` float32, keluaran `[1,40,438]` float32. Model lain (lebar dinamis, INT8, keluaran logit)
  ditolak, bukan dibaca dengan tebakan; jumlah nilai keluaran juga diperiksa tiap sel.
- Keluaran model NaN / tak hingga / negatif tidak pernah menjadi usulan: dekoder menandainya tidak valid,
  keputusan menahan selnya (`keluaranTakValid`), dan `PembacaSelOnnx` membaca sel itu dengan ML Kit tanpa
  mematikan mesin. Skor dan ambang dibandingkan dengan `!(jalur >= ambang)` supaya NaN menahan.
- Crop dengan sisi > 2048 px atau lebar kanvas > 2048 (rasio > ±43:1) tidak dibaca (`kosong`,
  `ukuranTakWajar`); tanpa batas, crop 1 piksel tinggi menghasilkan tensor ratusan ribu piksel lebar.
- `meta.json` tidak dipercaya penuh: `ambang_jalur` dijepit ke 0,5–1,0 (meta rusak tidak boleh meloloskan
  semua bacaan); di build rilis hanya model ber-sha256 yang dipatok di app (`sha256ModelDipercaya`) yang
  dimuat, jadi berkas di folder perangkat (adb push) tidak bisa menukarnya; bukti `SINTETIS` hanya diterima
  bila sakelar developer menyala. `kolom` dari meta belum dipatok per sha256.

## 8. Keputusan yang menunggu foto nyata

Target set berlabel 300–500 sel (cukup MENOLAK kandidat; mengesahkan butuh ±1.300–2.000 sel pada cakupan
20–30%), komposisi seperti bagian 5 laporan rig (20–25% kosong, ≥ 100 sel negatif, ≥ 30 coretan,
≥ 2 penulis). Gerbang resmi: ≥ 20 foto per formulir. Keluaran yang diadu: akurasi terjawab ≥ 90% tanpa
sel kosong palsu pada ambang yang ditetapkan SEBELUM melihat set uji nyata. Sebelum itu mesin angka
tetap sakelar developer; ML Kit pembaca bawaan.

## 9. Cara menukar model

1. Ganti berkas model dan `meta.json` di `assets/models/` (dibundel; build rilis hanya memuat sha256 yang
   dipatok di `sha256ModelDipercaya`, jadi pin ikut diganti dan dijaga `test/ocr_angka_tflite_aset_test.dart`)
   atau, hanya di build debug, di folder perangkat. Model TFLite WAJIB berkontrak `[1,48,320,3]` →
   `[1,40,438]` float32 (`SesiInferensiTflite.periksaKontrak`); model lain butuh sesi/praproses sendiri.
2. Isi `meta.json`: `berkas`, `sha256` (diperiksa saat dimuat, tidak cocok → ditolak), `alfabet`
   (`0123456789.,-`), `kolom` = indeks kelas model untuk `[blank, 0..9, ., ,, -]` (dari
   `inference.yml`: `[0] + [indeks karakter + 1]`, lihat `charset_dari_yml` di rig), `ambang_jalur`,
   `bukti_akurasi` (`SINTETIS` ditolak tanpa sakelar developer).
3. Bila arsitektur keluaran lain (bukan CTC `[1,T,K]` softmax), ganti `SesiInferensiCtc`/dekoder, bukan meta.
   Sesi yang tahu bentuk keluarannya mengisi `KeluaranCtc.sudahPeluang` (`true` = peluang, `false` = logit);
   `null` meniru rig dengan menebak dari jumlah baris pertama.
4. Ulangi pengukuran (bagian 6) dan hitung ulang ambang.

## 10. UX isi cepat (layar review)

Urutan kertas (`urutanKertas`: per tabel, baris demi baris dari geometri sel, kiri ke kanan);
**Konfirmasi dan lanjut** memeriksa sel aktif lalu pindah ke sel berikutnya yang masih butuh (memutar ke
awal bila perlu). Tidak ada tombol "terima semua usulan"; sel kosong tidak punya baris; merah wajib diketik;
tidak ada nilai disalin dari sel lain (tes `test/foto_review_isi_cepat_test.dart`).

### Layar: keypad hanya di layar lega

Keypad layar (±310 dp) menelan daftar di layar kecil (probe peninjau: 320×568 menyisakan 8 dp, tombol
Konfirmasi keluar layar pada 360×640 huruf 1,3× dan HP lanskap). `bolehKeypadLayar`: keypad hanya bila
tinggi ≥ 700 dp, skala huruf ≤ 1,15, dan bukan HP lanskap (sisi pendek < 600). Di luar itu papan ketik
sistem yang mengetik (`numberWithOptions(decimal, signed)`), fokus pindah ke sel berikutnya, dan yang tampil
di bawah hanyalah panel ringkas (kepala sel aktif + Konfirmasi dan lanjut); bila tinggi sisa < 360 dp
(papan ketik terbuka, lanskap) cukup satu baris "sisa + Konfirmasi". Panel tertutup di tinggi < 420 dp juga
meringkas penghitung Masukkan jadi satu baris. Pengantar ikut menggulir bersama daftar, jadi bagian tetapnya
hanya panel bawah dan tidak ada overflow. Kepala panel (keypad maupun ringkas) memuat crop sel aktif,
isi kotaknya, dan **"Sisa N sel"** — penghitung tidak hilang saat panel terbuka. Dijaga
`test/foto_review_ukuran_layar_test.dart` (320×568, 360×640 pada 1,0× dan 1,3×, 640×360, 360×800, 411×891,
600×960, 1280×800, dan papan ketik terbuka): tidak ada overflow, Konfirmasi, sisa, dan sel aktif terlihat.

### Kenapa urutan kertas (bukan merah dulu), dan pengamannya

Keputusan pemilik: isi cepat. Konfirmasi dan lanjut hanya masuk akal bila sel berikutnya selalu tetangga
sel yang baru diperiksa; mengurut menurut vonis memecah pekerjaan jadi loncatan acak. Harga: sel merah tidak
lagi muncul paling atas dan bisa tenggelam di daftar panjang. Pengamannya (semua diuji, tidak berubah dari
sebelumnya):

1. Tombol **Masukkan mati** selama ada sel merah yang kotaknya kosong atau sel kuning yang belum dicek;
2. penghitung ("N sel masih kosong", "N angka kuning belum dicek", "Sisa N sel") selalu terlihat, di
   bawah daftar saat panel tertutup dan di kepala panel saat terbuka;
3. "Konfirmasi dan lanjut" memutar ke sel mana pun yang masih butuh, merah termasuk, dan mati untuk merah
   yang masih kosong.

Tes pengunci: `PENGAMAN urutan kertas…` di `test/foto_review_isi_cepat_test.dart`, `tombol Masukkan MATI…`
dan `sel KUNING wajib dicek…` di `test/foto_review_screen_test.dart`.

## 11. Prasyarat sebelum sakelar menyala (BELUM dikerjakan)

Sakelar `PAKAI_MESIN_ANGKA` (dulu `PAKAI_MESIN_ANGKA_ONNX`) tetap mati sampai semua ini ada:

1. **Ukur berapa persen sel KOSONG di kertas yang berakhir jadi merah-wajib-isi.** Sel kosong yang oleh
   mesin dibaca sebagai noise berskor rendah berstatus "ditahan" (merah) dan tombol Masukkan menuntut
   kotaknya diisi; teknisi harus mengetik sesuatu di sel yang memang kosong. Ukur di `Ukur OCR` pada
   foto nyata (kolom `status`) sebelum sakelar menyala; dengan 20–25% sel kosong, angka kecil pun terasa.
2. **Pertimbangkan aksi eksplisit "kosongkan sel ini" per sel** (satu ketukan per sel, mengosongkan
   kotak dan menandai sel beres). BUKAN terima semua; tiap sel tetap diputuskan teknisi satu per satu.
3. **Pagar tinta: histogram + isolate.** Pengukuran peninjau 6,1 ms/sel; `PagarTinta.ukur` mengurutkan semua
   piksel jendela tengah. Ganti dengan histogram (persentil dari 256 tingkat) dan jalankan praproses +
   pagar di isolate latar (bersama `petaTerbatas`), lalu ukur ulang di tablet.
4. Runtime inferensi: TFLite terpilih dan terpasang (bagian 4). BELUM: inferensi nyata di tablet dan paritas
   Android (`integration_test/ocr_tflite_hp_test.dart`, lalu set besar `ocr_onnx_hp_test.dart`), termasuk
   latensi, XNNPACK, dan memori (bagian 7).
5. Ambang dihitung ulang di runtime final dan di crop SEBENARNYA dari app. Sejak 13 Nov mesin angka membaca
   hasil `PemotongSel` (bagian 12), bukan `PindaiLembar.potongSel` (yang tetap dipakai untuk ML Kit dan
   tampilan review). Ukur ulang di kanvas pindai HP (3 px/pt), bukan hanya di foto rig (±5 px/pt).
6. Respons produksi per formulir diperiksa: `aturan.desimal` terisi (bagian 5).
7. Ukur ML Kit pada crop yang sama sebagai pembanding, dan set foto nyata berlabel (bagian 8).
8. Pagar rilis: sha256 model dipatok di app (sudah); model dibundel di APK (sudah, +7,83 MB walau sakelar
   mati; keputusan bundel lawan unduh bisa ditinjau bila ukuran dipersoalkan); `izinkanSintetis` tetap
   hanya lewat sakelar developer.
9. Pagar lebar 320 (bagian 7): ukur berapa sel nyata yang beralih ke ML Kit karena `ukuranTakWajar`, dan
   putuskan jalurnya. Sesudah `PemotongSel`: 0 dari 103 crop Dart di dua foto rig melewati 320 px (pagar
   tetap ada sebagai jaring terakhir); di HP belum diukur.

## 12. Pemotong sel v2 dan keadaan "bertinta tapi tak terbaca" (13 Nov 2026, foto nyata)

> **SEMUA ANGKA DI BAGIAN INI IN-SAMPLE:** dua foto nyata (Sieve 114 sel, Piston 42 sel; 95 sel berisi
> berlabel buatan model, BELUM diverifikasi manusia), parameter disetel sambil melihat dua foto itu. BUKAN
> akurasi lapangan. Foto dan potongan sel nyata tidak ada di repo.

**Masalah (rig `sidik-ocr-eval\foto-nyata`, `hasil\analisis.md`):** sel utuh Sieve/Piston berbentuk 5–8:1,
kanvas model 320 px, sehingga 60% sel tak pernah sampai ke model; crop dipangkas ke kotak tinta menaikkan
cakupan 20% → 41% tetapi memunculkan 4 salah-yakin (1/7, 9→1) karena tinta menempel/terpotong di tepi
atas-bawah. Varian D rig ("luas") memberi cakupan 44,2% dengan 42/42 benar dan 0 salah-yakin.

**Yang dikerjakan:**

| bagian | perubahan |
|---|---|
| `PemotongSel` (`ocr_angka/pemotong_sel.dart`) | port Dart murni varian D. Dijalankan di isolate perataan `JalankanPindaiAsli` (halaman tidak disalin ke isolate lain). Hanya untuk sel yang templatnya punya format (yang dibaca mesin) dan hanya bila pembacanya `PembacaSelMesin`; ML Kit murni = nol kerja tambahan |
| Garis tabel | yang dihapus hanya garis mendatar di tepi atas/bawah kotak (garis terluar tiap sisi); garis datar di TENGAH sel adalah tulisan (STRIP "—"). Garis tegak yang masuk jendela dibuang (tipis, tinggi, dekat tepi; serpihan di tepi) |
| Pagar tinta | hanya `gelap >= 0,02` (konstanta `PagarTinta.gelapMin`, SEMENTARA, in-sample dari 2 foto). Angka `gelap` per sumber crop: **rig, sel utuh ternormalisasi** kosong maks 0,0000 / berisi min 0,063; **rig, varian D Python** kosong maks 0,013 / berisi min 0,033; **Dart `PemotongSel`** (setelan rig mutlak) kosong maks 0,0000 (50 + 3 sel) / berisi min 0,14 (Sieve), 0,08 (Piston), setelan produksi 0,21 / 0,08. Batas dikunci dari dua sisi oleh tes (0,014 ditolak, 0,026 lolos) |
| Tinta pudar | pemotong menganggap tinta bila abu ternormalisasi ≤ 0,78 × kertas, pagar menghitung `gelap` hanya di bawah 0,70 × kertas. Crop yang ADA (pemotong melihat tulisan) tetapi ditolak pagar = `perluCek`/`tintaPudar`, BUKAN `kosong` (dulu hilang diam-diam; sebelum perubahan 13 Nov cabang kontras meloloskannya). Hanya sel yang pemotongnya tidak menemukan apa pun yang tetap kosong. Batas diketahui: tinta lebih pudar dari 0,78 × kertas dianggap kertas oleh pemotong (sama dengan rig) |
| Keadaan baru | sel BERTINTA (lolos pagar) tetapi model diam, pemotong tak yakin, atau ML Kit juga diam setelah dialihkan = `perluCek` TANPA bacaan, bukan `kosong`. Diteruskan lewat `BacaanSelMesin.perluCekTanpaBacaan` → `HasilBacaAsli.gagalDibaca` → review MERAH kosong yang sudah ada (tidak ada teks/UI baru; aturan tinjauan tidak diubah) |
| Pemotong tak yakin | tinta menempel jendela atas/bawah, menempel tepi samping, komponen > 1,35 tinggi baris, garis datar panjang di tengah, kotak < 12 px. Model tidak dijalankan |
| `AturanFormatSel` | `nolBulat` hanya dari penanda eksplisit `boleh_bulat` (belum ada di server; bagian 5). Tanpa penanda "0" ditolak |
| Kegagalan pemotong | galat di `PemotongSel` (isolate perataan) tidak menjatuhkan pindai: sel dibaca dari crop apa adanya lewat jalur lama; `HasilBacaAsli.pemotongGagal = true` supaya tidak senyap. Diuji dengan pemotong yang melempar |
| Pagar lebar 320 | tetap ada; sel lebar yang lolos pagar tinta dialihkan ke ML Kit seperti sebelumnya |

**Paritas Dart vs rig** (`tool/ukur_pemotong_sel.dart`, masukan dari `SIDIK_PARITAS_DIR`, hasil dump
`dump_rig.py` yang tidak ada di repo; host saja, model TIDAK dijalankan: yang diukur kemiripan CROP):

| ukuran | Sieve (114 sel) | Piston (42 sel) |
|---|---|---|
| normalisasi cahaya: IoU tinta (≤198) lawan `norm` rig | 0,999 | 0,997 |
| selisih abu rata-rata per sel (0–255), median | 0,30 | 0,45 |
| crop sel berisi: IoU tinta gabungan, median (angka rig mutlak) | 0,994 | 0,990 |
| crop dengan IoU tinta ≥ 0,9 | 59 dari 64 | 35 dari 39 |
| kosong/berisi cocok dengan rig | 112/114 | 41/42 |
| crop > 320 px sesudah resize | 0 | 0 |

Tiga sel yang kosong/berisinya beda dari rig semuanya berlabel KOSONG: rig menyisakan serpihan (yang dibaca kosong
oleh model), Dart langsung kosong. Pada sel berisi kesepakatan kosong/berisi 100%.

**Efek ke usulan rig** (varian D, ambang 0,990, gerbang format; 42 usulan, semuanya benar): pemotong yang
tak yakin menahan 2 di antaranya (keduanya benar) → 40 dari 95 sel berisi = 42,1% lawan 44,2% di rig; tidak
ada bacaan salah yang menjadi usulan sebelum maupun sesudahnya. STRIP: 4 dari 5 sel ditandai "garis datar"
(perluCek tanpa bacaan); CORET/TIMPA dan STRIP sisanya: menurut status rig dibaca kosong atau berskor rendah → `perluCek` (model TIDAK
dijalankan di Dart, jadi ini bacaan dari hasil rig, bukan ukuran baru).

**Kepekaan** (bukan jaminan):

- kotak digeser 3 px: status kosong/berisi dan jumlah sel tak yakin tidak berubah;
- halaman dikecilkan ×0,6 (≈ 3 px/pt, kanvas pindai HP; pengecilan rata-rata, BUKAN homography bilinear
  seperti `ratakanHalaman`): IoU kotak median turun menjadi 0,946/0,954, dan sel tak yakin naik: Sieve 4 sel
  berisi (3 usulan rig benar ikut tertahan), Piston 16 (5 usulan rig benar ikut tertahan). Cakupan di HP
  hampir pasti lebih rendah dari angka rig; arahnya aman (menahan, bukan menebak);
- penyebab utama sel tak yakin di Piston: angka baris sebelah menyentuh garis dan tersambung lewat
  jembatan sehingga komponen menembus jendela. Itu kegagalan nyata, bukan artefak.

**Waktu** (host desktop, BUKAN HP): halaman ×0,6 (±4,6 MP): normalisasi ±150 ms + 114 sel ±150 ms (AOT);
JIT pada halaman rig penuh (12,7 MP) 0,7–1,2 s per halaman. **Kecepatan di HP TIDAK TERBUKTI.**

**Tidak terbukti / terbuka:** akurasi lapangan dan kecepatan di HP; ambang `gelapMin` dan semua ukuran
relatif pemotong (tak ada set validasi terpisah); perilaku pada foto selain dua foto ini; kode rig memakai
`ext=0,60` (jendela meluber ±0,6) sementara ringkasan tugas menulis ±0,5 (dipakai 0,6, angka rig);
bar hitam di bekas garis pada crop (piksel jembatan diberi nilai tinta pekat) diwarisi dari rig.

**Risiko yang dicatat (review 13 Nov):**

- **Laju "tak yakin"/perlu-cek pada sel KOSONG di skala HP BELUM diukur.** Di dua foto rig 0 dari 53 sel
  kosong menghasilkan crop (semuanya `kosong`), tetapi itu di ±5 px/pt; di kanvas pindai 3 px/pt (simulasi
  ×0,6 hanya mengukur sel berisi) sel kosong yang menghasilkan crop kecil (debu, tepi garis) akan jadi
  baris merah.
- **Baris merah kosong tidak bisa dilewati:** `FotoReviewScreen` (`foto_review_screen.dart` ±334) mematikan
  Masukkan selama ada merah kosong atau kuning belum dicek, dan tidak ada "terima semua". Sel bertinta yang
  salah ditandai memaksa teknisi mengetik sesuatu di kotak itu. Karena itu laju di atas harus diukur di HP
  sebelum sakelar menyala.
- `HasilBacaAsli.gagalDibaca` kini dipakai ganda (galat baca dan "bertinta tak terbaca"); teknisi tidak
  bisa membedakannya di layar. `AturanFormulirAsli.periksa` (`aturan_formulir_asli.dart` ±160, hanya
  formulir 0541) menghitung `gagalDibaca` sebagai "terisi" saat menilai kelengkapan blok per kolom: untuk
  sel bertinta yang tak terbaca itu BENAR (ada tulisan; dulu sel itu dihitung kosong dan blok tampak tidak
  lengkap). Hanya untuk tanda palsu (debu) pada kolom yang kosong, blok akan tampak "terisi sebagian" dan
  sel kosongnya jadi merah (`blokTidakLengkap`). Tidak diubah di berkas itu.

**Uji:** `test/ocr_angka_pemotong_sel_test.dart` (halaman sintetis: garis tabel, derau, bayangan, digit
melewati garis, palang "7", dua nol menyatu, titik, strip, coretan, garis tegak, fuzz kotak),
`test/ocr_angka_pemotong_mesin_test.dart` (keputusan sel, `PembacaSelOnnx.bacaMesin`, `nolBulat`),
tambahan di `jalankan_pindai_asli_test.dart` dan `ocr_angka_pagar_tinta_test.dart`. Uji mutasi (salinan
`mut-pemotong-<acak>` di scratchpad): semua mutan tertangkap sesudah tes ditambah (putaran 1: 19 mutan;
putaran review: tinta pudar, `boleh_bulat`, batas `gelapMin` dari dua sisi, blok `catch` pemotong).

# OCR angka tulisan tangan: mesin PP-OCR di balik sakelar

Diperbarui 12 Nov 2026. Dasar: laporan rig `_agents_workspace/ocr-kamera-20261112/10-uji-mesin-angka.md`
(repo API, tidak di-commit) dan rig `C:\Users\USER\sidik-ocr-eval\`.

> **SEMUA ANGKA AKURASI DI DOKUMEN INI SINTETIS** (digit MNIST + font bergaya tulisan tangan di atas
> latar sel buatan). Bukan tulisan teknisi di kertas yang difoto. Tidak ada klaim akurasi lapangan.

## 0. Status (apa yang ada, apa yang belum)

| bagian | status |
|---|---|
| Lapisan Dart murni `lib/services/ocr_angka/` (praproses, dekoder CTC, gerbang format, pagar tinta, status sel) | ADA, diuji di CI |
| `PembacaSelOnnx` di balik sakelar `PAKAI_MESIN_ANGKA_ONNX` (bawaan MATI), ML Kit sebagai cadangan | ADA, diuji dengan sesi tiruan |
| Layar diagnostik `Ukur OCR` (debug / `TAMPILKAN_UKUR_OCR`) | ADA, diuji (logika + layar); ML Kit bisa diukur SEKARANG di tablet |
| UX isi cepat di layar review (urutan kertas, keypad di layar lega / papan ketik sistem di layar sempit, konfirmasi dan lanjut) | ADA, aktif untuk semua pembaca |
| **Runtime inferensi (ONNX Runtime / LiteRT) di app** | **TIDAK ADA** — dependensi ditahan, lihat bagian 4 |
| Model `ocr_angka_en.onnx` di APK | TIDAK ADA (7,8 MB bobot mati tanpa runtime) |
| Inferensi nyata di HP/tablet, latensi nyata, akurasi pada foto nyata | **TIDAK TERBUKTI** |

Selama runtime belum ada, menyalakan sakelar tidak mengubah apa pun: `buatSesiOcrAngkaProvider` bernilai
`null`, mesin tidak termuat, semua sel dibaca ML Kit. Aturan keras tetap: OCR hanya di HP, hasil hanya
usulan, sel kosong tetap kosong, tulisan tangan tidak pernah hijau, `siap_pindai`/pintu server tidak
disentuh, tidak ada perhitungan kalibrasi di HP.

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
                             3. SesiInferensiCtc   ← jahitan ke runtime (belum ada)
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
| model | `en_PP-OCRv5_mobile_rec_onnx` rev `3fafbc3b`, 7.848.423 bita, Apache-2.0 | rig (sha256 di `assets/models/ocr_angka_en.meta.json`) |
| masukan | `[1,3,48,W]` float32 BGR, `W = max(320, ceil(48·lebar/tinggi))`, pad nol di kanan | `MesinPaddle._praproses` rig |
| keluaran | softmax `[1,W/8,438]`; kolom whitelist = indeks kelas `[0,1..10,76,74,75]` (blank, 0–9, `.`, `,`, `-`) | `inference.yml` |
| dekode | normalkan ulang ke 14 kolom, argmax per frame, buang blank, lebur kembar (blank memisahkan) | `dekode.py` rig |
| skor sel | `jalur` = rata-rata geometrik peluang maks SEMUA frame; 0 bila teks kosong | `dekode.py` rig |
| ambang awal | **0,990** pada `jalur` | rig, B-en |
| gerbang format | tepat `desimal` digit di belakang pemisah, `-` hanya bila boleh negatif, 1–8 digit bulat, ≤ 8 karakter | `lolos_format` rig |
| pagar tinta | tolak bila `gelap < 0,002` DAN `kontras < 0,02` (margin 15%, tinta > 0,30) | diukur di sini, bagian 3.3 |

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

## 4. Keputusan dependensi (tidak ditambahkan)

Batas pemilik: delta bersih ≤ ±12 MB per APK dua-ABI (`arm` + `arm64`, `--target-platform
android-arm,android-arm64`). APK saat ini (rilis v1.0.791): 74.991.208 bita.

`flutter_onnxruntime` 1.9.0 (6 Okt 2026, MIT, 8 rilis dalam 5 bulan, Android/iOS/Linux/macOS/Windows/web)
menarik `com.microsoft.onnxruntime:onnxruntime-android:1.28.0` (minSdk 21; app memakai
`flutter.minSdkVersion`). Diukur dari AAR di Maven Central (bukan dari APK):

| pustaka native | arm64-v8a | armeabi-v7a | 2 ABI |
|---|---:|---:|---:|
| ONNX Runtime 1.28.0 `libonnxruntime.so` + jni | 28,75 MB (deflate 11,1) | 20,47 MB (deflate 9,9) | **49,2 MB (deflate 21,0)** |
| LiteRT 1.4.0 `libtensorflowlite_jni.so` (tflite_flutter) | 4,32 MB | 2,87 MB | 7,2 MB (deflate 3,4) |
| model B-en | 7,85 MB (deflate 7,2) | | |

Delta bersih APK dua-ABI: ORT + model = **+57,1 MB** mentah (+28,3 MB bila .so dikompresi); bila
`tflite_flutter` dibuang sebagai pengimbang, **+49,9 MB** (+24,9 MB). .so disimpan tanpa kompresi di
APK (AGP bawaan, minSdk ≥ 23) sehingga angka "mentah" yang lebih mungkin; tidak diukur pada APK nyata.
arm64-saja (32-bit jatuh ke ML Kit): +29,4 MB (+14,9 MB). **Semua jauh di atas 12 MB, jadi dependensi
TIDAK ditambahkan.** Windows (Lab dan Studio, karena Studio memakai paket ini lewat path) juga akan
mengunduh zip ONNX Runtime 1.28.3 (78,6 MB) dari GitHub saat build; ukuran DLL tidak diukur.

**`tflite_flutter` / LiteRT tidak terpakai** (`grep`): satu-satunya pemakainya `interpreter_tflite.dart`
(adaptor yang sengaja tidak dipasang; masuk PENGECUALIAN `tool/cek-berkas-yatim.sh`) untuk
`PembacaDigitTflite`, yang hanya dirujuk test; sakelar `pakaiModelDigit` tidak dibaca kode mana pun.
Membuangnya menghemat 7,2 MB (3,4 MB terkompresi) — tidak dilakukan di sini (bukan bagian tugas, dan
keputusan "model digit TFLite mati" ada di tangan pemilik).

### Opsi (belum dikerjakan; pilihan pemilik)

1. **Pakai LiteRT yang sudah ada**: ubah model ke `.tflite` (ONNX → TFLite, mis. `onnx2tf`), jalankan lewat
   `tflite_flutter` yang sudah dibundel. Runtime baru 0 MB; selisih APK ≈ ukuran model (7,8 MB FP32;
   kuantisasi dinamis mungkin jauh lebih kecil — belum diukur). Syarat: konversi terbukti setara
   (bandingkan keluaran ke ORT pada 600 crop), semua operator model didukung. Model memakai 25 jenis operator
   dasar (Conv, MatMul, Softmax, HardSigmoid, BatchNorm, Reshape, Transpose, ReduceMean, …, 1.019 node).
2. **`onnxruntime-mobile` 1.18.0** (Maven Central, rilis terakhir paket itu: Mei 2024): arm64 4,5 MB +
   arm32 3,3 MB = **7,8 MB** mentah (deflate 3,4 MB) untuk dua ABI → delta bersih ≈ **+8,5 MB** bila
   `tflite_flutter` dibuang (+15,7 MB bila tidak; terkompresi +7,2 / +10,6 MB). Syarat belum terbukti: model harus dikonversi ke format `.ort` dengan
   kumpulan operator paket mobile; plugin dikompilasi terhadap API 1.28 sehingga butuh substitusi Gradle
   dan pengecekan kompatibilitas; paket sudah tidak dirilis lagi.
3. **ORT build minimal sendiri** (hanya operator model ini, format `.ort`): ukuran biasanya beberapa MB
   per ABI (perkiraan dokumentasi ORT, tidak diukur di sini); butuh CI build AAR sendiri.
4. **ORT penuh, arm64-saja** atau hanya Android/Windows: tetap +14,9 sampai +29,4 MB; ditolak oleh batas 12 MB.
5. **Tetap ML Kit** sampai satu opsi di atas terbukti, sambil mengukur ML Kit di tablet dengan layar
   `Ukur OCR` (sudah bisa, bagian 6).

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

Gerbang bertahap yang dipakai: ada `desimal` → gerbang penuh; tidak ada → mesin tidak dipakai (bukan
gerbang umum yang lebih longgar). Tidak ada nilai yang dikarang.

## 6. Mengukur di tablet

1. Titipkan ke folder app (`adb push`, tanpa izin penyimpanan):
   `/sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur/` berisi `labels.csv` (`file,teks[,desimal,bertanda]`)
   dan crop; untuk mesin angka juga `ocr_angka_en.onnx` + `ocr_angka_en.meta.json` (dari `assets/models/`).
   Rig: `sidik-ocr-eval\data\uji` (crop + `labels.csv`, SINTETIS) atau crop foto nyata.
2. Build debug (layar tampil otomatis) atau rilis dengan `--dart-define=TAMPILKAN_UKUR_OCR=true`.
   Profil → Sistem → **Ukur OCR (pengembang)**.
3. Pilih **ML Kit** (bisa SEKARANG) atau **Mesin angka** (butuh runtime), batas sel, ambang `jalur`, lalu
   Mulai. Hasil: akurasi terjawab, cakupan, exact, isi-palsu, latensi median/p95 per sel. Tersimpan
   `hasil.csv` + `hasil_<mesin>.csv`: kolom `file,teks,keyakinan` sama dengan CSV ML Kit untuk
   `muat_foto_nyata.py --mlkit`, plus `status,ms`.
4. Banding di laptop: `python muat_foto_nyata.py <folder> --mesin B_en --mlkit hasil_mlkit.csv`.
5. Tes perangkat otomatis: `integration_test/ocr_onnx_hp_test.dart` (paritas dengan prediksi rig dan latensi).
   SKIP selama `buatSesiUji` kosong; **TIDAK TERBUKTI**.

Sel kosong tanpa kolom `desimal`: layar memakai satu asumsi (desimal 2, tanpa minus) untuk semuanya;
isi kolom `desimal` per baris untuk ukuran isi-palsu yang jujur.

## 7. Batas dan yang belum terbukti

- Inferensi NYATA di perangkat, latensi tablet (perkiraan laporan: 2–5× laptop ≈ 120–300 ms/sel; satu
  lembar ±150 sel ≈ 15–45 detik tanpa optimasi lawan target ≤ 8 detik), dan paritas Android: belum.
- Akurasi pada foto nyata: belum ada satu pun. Kurva sintetis tidak boleh dikutip sebagai akurasi lapangan.
- Ambang 0,990 dipilih di runtime laptop pada data sintetis; geser sedikit (±0,003) membalik keputusan
  sebagian sel (3.2). Hitung ulang di runtime final.
- Sisa tulisan tetangga (3,3%) dan minus hilang tetap lolos sebagai usulan; hanya pemeriksaan teknisi
  per sel yang menahannya (tes "BATAS DIKETAHUI" di `test/ocr_angka_keputusan_test.dart`).
- Urutan review kini urutan kertas (bukan merah dulu); alasan dan pengamannya di bagian 10.
- Paritas bagian 3.2 diukur terhadap model rig sebelum berkas model di rig diubah proses lain (agen
  konversi TFLite). Tidak diukur ulang; jangan menjalankan ulang terhadap rig tanpa memeriksa sha256
  `inference.onnx` (`b5f833df…`).
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

1. Ganti berkas model dan `meta.json` di folder perangkat (atau di `assets/models/` bila kelak dibundel).
2. Isi `meta.json`: `berkas`, `sha256` (diperiksa saat dimuat, tidak cocok → ditolak), `alfabet`
   (`0123456789.,-`), `kolom` = indeks kelas model untuk `[blank, 0..9, ., ,, -]` (dari
   `inference.yml`: `[0] + [indeks karakter + 1]`, lihat `charset_dari_yml` di rig), `ambang_jalur`,
   `bukti_akurasi` (`SINTETIS` ditolak tanpa sakelar developer).
3. Bila arsitektur keluaran lain (bukan CTC `[1,T,K]` softmax), ganti `SesiInferensiCtc`/dekoder, bukan meta.
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

Sakelar `PAKAI_MESIN_ANGKA_ONNX` tetap mati sampai semua ini ada:

1. **Ukur berapa persen sel KOSONG di kertas yang berakhir jadi merah-wajib-isi.** Sel kosong yang oleh
   mesin dibaca sebagai noise berskor rendah berstatus "ditahan" (merah) dan tombol Masukkan menuntut
   kotaknya diisi; teknisi harus mengetik sesuatu di sel yang memang kosong. Ukur di `Ukur OCR` pada
   foto nyata (kolom `status`) sebelum sakelar menyala; dengan 20–25% sel kosong, angka kecil pun terasa.
2. **Pertimbangkan aksi eksplisit "kosongkan sel ini" per sel** (satu ketukan per sel, mengosongkan
   kotak dan menandai sel beres). BUKAN terima semua; tiap sel tetap diputuskan teknisi satu per satu.
3. **Pagar tinta: histogram + isolate.** Pengukuran peninjau 6,1 ms/sel; `PagarTinta.ukur` mengurutkan semua
   piksel jendela tengah. Ganti dengan histogram (persentil dari 256 tingkat) dan jalankan praproses +
   pagar di isolate latar (bersama `petaTerbatas`), lalu ukur ulang di tablet.
4. Runtime inferensi terpilih (bagian 4), inferensi nyata di tablet, dan paritas Android
   (`integration_test/ocr_onnx_hp_test.dart`).
5. Ambang dihitung ulang di runtime final dan di crop SEBENARNYA dari app: `PindaiLembar.potongSel` memangkas
   6% ke dalam, sedangkan crop rig memakai padding keluar 2–12 px dengan garis tabel di tepi.
6. Respons produksi per formulir diperiksa: `aturan.desimal` terisi (bagian 5).
7. Ukur ML Kit pada crop yang sama sebagai pembanding, dan set foto nyata berlabel (bagian 8).
8. Pagar rilis: sha256 model dipatok di app (sudah), dan keputusan apakah model dibundel di APK atau
   diunduh; `izinkanSintetis` tetap hanya lewat sakelar developer.

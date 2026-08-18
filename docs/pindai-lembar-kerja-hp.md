# Pindai Lembar Kerja — sisi HP (OCR lokal, tanpa AI berbayar)

Kontrak lengkapnya `docs/SPEC-ocr-template-lokal.md` di repo `sidik-calibration-api`.
Berkas ini cuma peta sisi Flutter-nya: mana yang ngerjain apa, dan mana yang
**belum** selesai.

Jalur AI Vision yang lama (`worksheet_vision.dart` + tombol "FOTO TABEL INI —
DIBACA AI") **sudah dicabut dari aplikasi** per 14 Agustus 2026. Endpoint
`POST /api/raw-measurements/extract-from-photo` masih hidup di backend dan
sengaja tidak disentuh — keputusan mematikannya ada di lab.

## Aturan yang mengikat kode ini

1. **Foto tidak pernah keluar dari perangkat ke pihak ketiga.** OCR dan
   pembacaan QR jalan on-device (`google_mlkit_text_recognition`,
   `google_mlkit_barcode_scanning` — dua-duanya model bundled, tanpa API key).
   Tidak ada biaya per foto.
2. **Yang naik ke server bukan foto, tapi hasil bacanya**: teks per sel, kotak
   koordinat, skor mutu, geometri. Citra hasil warp ikut naik sebagai lampiran
   audit dan boleh gagal naik tanpa membatalkan hasil pindai.
3. **Frontend tidak menghitung apa pun.** Tidak ada rata-rata, tidak ada
   koreksi, dan **tidak ada tebakan koma**. `133659` dikirim `133659`.
4. **Bentuk lembar tidak pernah di-hardcode.** Jumlah titik, kolom, satuan,
   desimal, jumlah tabel — semuanya dari `GET /api/worksheet-templates/{kode}`.
5. **Hasil pindai itu usulan.** Data kalibrasi tetap lahir dari
   `POST`/`PUT /api/calibrations`.

## Peta berkas

| Berkas | Tugas |
|---|---|
| `lib/services/pindai_lembar.dart` | cari 4 marker sudut (ambang gelap + titik berat gumpalan, Dart murni — **tanpa OpenCV**), warp perspektif ke ruang template, potong per sel, hitung skor mutu |
| `lib/services/pembaca_qr.dart` | baca QR versi lembar (`{template_id}\|v{versi}`) dari citra hasil warp |
| `lib/services/pembaca_sel.dart` | ML Kit baca **tiap potongan sel** (bukan sehalaman), lalu `PayloadPindai` menyusun kiriman |
| `lib/services/jalankan_pindai.dart` | urutan wajibnya: marker → warp → QR → gerbang mutu → potong per sel → OCR → payload. `AmbangMutu` menyalin `config/ocr.php` |
| `lib/services/worksheet_scan_service.dart` | `POST /worksheet-scans` (multipart + `citra_warp`), crop sel, koreksi. 422 dilempar sebagai `PindaiDitolak` |
| `lib/screens/calibration/pindai_review_screen.dart` | tabel bervonis warna, crop sel di sebelah kotak isian, "Pakai Angka Ini" → `POST .../koreksi` |
| `lib/screens/calibration/lembar_kerja_state.dart` | `terapkanHasilPindai()` — menuang angka yang disetujui teknisi ke kotak isian |

## Diuji di mana

| Yang dijaga | Di mana |
|---|---|
| marker, warp, tiap sel mendarat di dalam kotaknya, kotak jangkar menaungi tulisannya | `test/pindai_lembar_cetakan_test.dart` — diadu ke lembar cetak asli |
| urutan pipeline, QR, gerbang mutu, jangkar, semua sel terkirim | `test/jalankan_pindai_test.dart` |
| layar review: vonis warna, crop sel, koreksi dikirim semua | `test/pindai_review_test.dart` |
| **sambungan penuh**: tombol → server → review → angka masuk formulir → `input_method: ocr` + verifikasi pembacaan | `test/pindai_alur_layar_test.dart` |
| **ML Kit sungguhan** (QR & label Repeat) | `integration_test/pindai_hp_test.dart` — butuh HP: `flutter test integration_test/pindai_hp_test.dart -d <id>` |
| foto SATU tabel bentuk pH/spektro (Repeat berjajar ke kanan) | `test/peta_tabel_foto_test.dart` |
| foto SATU tabel bentuk Conductivity (Repeat turun ke bawah, slot larutan ke kanan) | `test/peta_tabel_foto_kebawah_test.dart` |

Ambang mutu di `AmbangMutu` menyalin `config/ocr.php` persis. Kalau salah
satunya digeser, yang lain wajib ikut — gerbang yang lebih longgar cuma
memindahkan penolakan ke belakang, yang lebih ketat menolak foto yang sah.

## Yang belum selesai

- **`siap_pindai` masih `false` untuk keenam alat** (`geometri_belum_diverifikasi`).
  Tombol pindai mati dan alasannya ditampilkan apa adanya. Yang menutup ini lab:
  cetak ulang formulir dari `php artisan ocr:cetak-lembar {kode}`, adu ke foto
  nyata, lalu set `terverifikasi: true`.
- **Ketajaman ML Kit pada tulisan tangan belum terukur.** Yang sudah dibuktikan
  di HP cuma yang TERCETAK (QR & label Repeat). Angka tulisan tangan bukan
  soal lulus/gagal tapi akurasi per kolom — `php artisan ocr:akurasi` di sisi
  server, dan datanya baru ada sesudah teknisi memakainya.
- **Tulisan kepala Repeat di formulir LAMA lab belum dipastikan.** Ini
  menyangkut jalur kedua — "Foto tabel ini" (`PetaTabelFoto`), yang justru
  diarahkan ke formulir tak bermarker, jadi lembar hasil `ocr:cetak-lembar`
  bukan acuannya. Jangkar kolomnya dicocokkan ke tulisan yang tercetak, dan
  yang dikirim layar sekarang ikut `prefiks_pengulangan` dari backend (`X`
  membuat `X1`); alat yang backend-nya diam jatuh ke bawaan `X1`..`Xn`. Kalau
  kertas lab ternyata mencetak `Repeat 1` atau nomor polos, satu-satunya yang
  perlu diubah `_TombolFotoTabelState._kepalaPengulangan` di
  `lembar_kerja_tabel.dart` — mesinnya sendiri sudah menerima daftar tulisan
  apa pun. Sampai itu dipastikan, foto per tabel hanya terbukti jalan pada
  lembar yang mencetak `Xn`.
- **Blok non-tabel tidak lagi terisi otomatis.** Jalur AI dulu ikut mengisi
  kondisi lingkungan, catatan, dan tanggal terima dari foto yang sama.
  Template OCR cuma memetakan sel tabel, jadi kolom itu kembali diketik manual.
  Ini penyempitan yang disengaja: template OCR menaruh angka lewat kunci sel
  yang eksplisit, dan kolom non-tabel tidak punya kunci semacam itu.

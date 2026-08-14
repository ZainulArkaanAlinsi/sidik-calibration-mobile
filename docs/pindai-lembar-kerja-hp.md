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

## Yang belum selesai

- **`siap_pindai` masih `false` untuk keenam alat** (`geometri_belum_diverifikasi`).
  Tombol pindai mati dan alasannya ditampilkan apa adanya. Yang menutup ini lab:
  cetak ulang formulir dari `php artisan ocr:cetak-lembar {kode}`, ukur, lalu
  set `terverifikasi: true`.
- **Jangkar (label Repeat) belum bisa dibaca.** Semua berkas geometri rangka
  menulis kotak jangkar `{x:0,y:0,w:0,h:0}`; kotak sebesar nol tidak bisa
  dipotong. Aplikasi **tidak** mengirim `sel_jangkar` palsu — akibatnya server
  menolak setiap pindai di tahap 4 (`mapping_gagal`) sampai kotak jangkarnya
  diisi di sisi backend.
- **Belum diuji di HP fisik.** Yang sudah diadu ke lembar cetak asli baru
  deteksi marker, warp, dan pemetaan sel (`test/pindai_lembar_cetakan_test.dart`,
  `test/jalankan_pindai_test.dart`). Ketajaman ML Kit pada tulisan tangan,
  pembacaan QR dari jepretan nyata, dan sambungan "kirim → verifikasi
  pembacaan" di layar belum ada yang menjaga.
- **Blok non-tabel tidak lagi terisi otomatis.** Jalur AI dulu ikut mengisi
  kondisi lingkungan, catatan, dan tanggal terima dari foto yang sama.
  Template OCR cuma memetakan sel tabel, jadi kolom itu kembali diketik manual.

---
name: sidik-fe-ocr-privasi-audit
description: Jaga pipeline pindai lembar kerja (OCR & QR on-device) tetap privasi-first — citra pelanggan tidak pernah keluar HP, dan penjagaan versi lembar (QR) tidak boleh dilewati/dipalsukan. Pakai saat menyentuh lib/services/pindai_lembar.dart, pembaca_qr.dart, pembaca_sel.dart, jalankan_pindai.dart, atau menambah dependency OCR/vision baru.
---

# Sidik FE OCR & Privasi Pindai Lembar Kerja

Ini fitur paling sensitif di app: teknisi motret lembar kerja fisik, dan
janji ke lab/pelanggan adalah **fotonya nggak pernah keluar dari HP**. Ini
setara "concurrency audit"-nya proyek Go — bukan soal race condition, tapi
soal jalur data yang diam-diam bisa "bocor" kalau nggak hati-hati.

## Aturan Keras

### 1. Dilarang dependency OCR/vision yang kirim citra ke server luar
`google_mlkit_text_recognition` (teks) dan `google_mlkit_barcode_scanning`
(QR) dipilih SPESIFIK karena modelnya jalan on-device (lewat Google Play
Services), bukan API cloud. Dependency baru buat scan/OCR/vision APA PUN
harus dicek: kalau dia kirim gambar/frame ke server pihak ketiga atau butuh
API key layanan cloud vision — TOLAK, walau lebih akurat atau lebih gampang
dipasang.

### 2. Yang boleh dikirim ke server cuma HASIL, bukan citra utuh
Lihat kontrak di `pindai_lembar.dart`/`worksheet_scan_service.dart`: yang
naik ke `POST /worksheet-scans` cuma teks per sel + skor + koordinat kotak
(+ `citra_warp` sebagai BUKTI geometri, bukan buat OCR ulang server-side).
Kalau ada perubahan yang mulai ngirim citra mentah/frame kamera langsung ke
endpoint baru, itu pelanggaran — flag keras.

### 3. QR versi lembar HARUS dibaca dari citra, tiap kali
`PembacaQr` isinya wajib hasil baca on-device dari foto yang lagi diproses
— BUKAN disalin dari `qrIsi` respons template sebelumnya. Server nolak
pindai kalau `qr.terbaca` bukan `true`, dan penjagaan itu cuma berarti
kalau isinya beneran datang dari foto: revisi lembar (Rev.4 vs Rev.5) mirip
di mata orang tapi beda koordinat sel — kalau QR dipalsu/disalin, error
salah baris nggak pernah muncul, cuma angka mendarat diam-diam di sel yang
salah.

### 4. `residualPx` (toleransi warp) jangan dilonggarin tanpa alasan tercatat
Server nolak di atas 2px penyimpangan sudut marker. Kalau ada yang mau
menaikkan toleransi ini (biar "lebih banyak foto keterima"), itu trade-off
akurasi-vs-kenyamanan yang HARUS didiskusikan eksplisit, bukan diubah diam-
diam di satu tempat.

## Checklist Saat Menyentuh Jalur Ini
- [ ] Cek `pubspec.yaml` — dependency baru di area kamera/scan/vision punya
      komentar WHY yang jelasin kenapa dia aman privasi (ikuti pola
      komentar yang udah ada di sekitar `google_mlkit_text_recognition`).
- [ ] `jalankan_pindai.dart` (orkestrator alur pindai) tetap urutannya:
      warp → baca QR dari citra warp → potong sel → OCR per sel → kirim
      hasil. Jangan reorder biar QR dibaca dari sumber lain buat "hemat
      waktu".
- [ ] Test baru buat jalur ini pakai citra/koordinat contoh nyata (lihat
      `[[sidik-fe-test-generator]]`), bukan mock yang skip validasi
      geometri.

## Guidelines
- Kalau user minta "biar OCR-nya lebih akurat, pakai AI Vision aja" —
  jangan langsung nurut. Jelaskan trade-off (biaya per foto, butuh sinyal,
  citra pelanggan nyampe pihak ketiga) dan konfirmasi eksplisit sebelum
  mengubah arsitektur ini, karena ini keputusan produk yang udah diambil
  sengaja, bukan kebetulan teknis.

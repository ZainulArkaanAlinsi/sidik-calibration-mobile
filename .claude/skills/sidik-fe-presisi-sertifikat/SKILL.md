---
name: sidik-fe-presisi-sertifikat
description: Audit konsistensi angka & desimal tampil di app (preview kalibrasi, tabel riwayat, sertifikat) terhadap bentuk cetak PDF/workbook master. Pakai saat mengubah tampilan angka hasil kalibrasi, menambah alat baru, atau curiga preview beda bentuk dari sertifikat tercetak.
---

# Sidik FE Presisi & Bentuk Cetak Sertifikat

Padanan `sidik-kalkulasi-presisi` di backend, sisi tampilan. Backend udah
mastiin angkanya BENAR; skill ini mastiin app NAMPILIN angka itu dengan
BENTUK yang sama seperti yang bakal tercetak — dua hal yang beda, dan
selisih di sini yang bikin lolos QA tapi ketauan pelanggan.

## Jebakan Utama (lihat `test/certificate_desimal_per_titik_test.dart`)

### 1. Desimal per titik MENANG atas desimal sesi/sertifikat
`BarisHasilSertifikat`/`MeasurementResult` punya `desimalEfektif(fallback)`
— pakai `desimal` per titik kalau backend ngirim, baru jatuh ke desimal
level sesi, baru ke desimal sertifikat. Widget manapun yang nampilin angka
titik ukur (Calibration Report, layar Riwayat) WAJIB manggil
`desimalEfektif(...)`, JANGAN patok angka desimal fix di widget (mis.
`toStringAsFixed(2)` ditulis langsung) — itu penyebab bug persis yang
dicatat di komentar test (Refractometer 5 desimal kepotong jadi 2).

### 2. Layar Riwayat & layar Sertifikat dua SUMBER data beda
Tabel yang sama tampil di dua tempat: layar Riwayat baca `titik[]` dari
respons sesi, layar Sertifikat baca snapshot sertifikat. KEDUANYA harus
lewat jalur `desimalEfektif` yang sama — kalau nambah widget tabel baru,
cek dia pakai model yang benar (`MeasurementResult` vs
`BarisHasilSertifikat`) dan bukan bikin format ulang sendiri.

### 3. Satuan campur/varian resolusi — jangan asumsikan satu alat = satu bentuk
Turbidimeter beda desimal per rentang (0,01 / 0,1 / 1), Conductivity beda
satuan per baris. Widget yang generic buat "tabel hasil kalibrasi" harus
baca desimal/satuan PER BARIS dari data, bukan dari konfigurasi level alat
yang ditulis sekali di UI.

### 4. Snapshot lama TIDAK BOLEH berubah tampilannya
Sertifikat yang sudah terbit dan sudah dipegang pelanggan — kalau field
`desimal` per titik belum ada di snapshot lama (`null`), fallback ke
desimal sertifikat, BUKAN default baru yang "kelihatan lebih benar". Uji
ini eksplisit tiap ada perubahan di sekitar `desimalEfektif`.

## Checklist Saat Menambah Alat/Layar Baru
- [ ] Format angka lewat `lib/core/utils/angka.dart`
      (`formatSertifikat`/`formatNilaiStandar`), bukan `toStringAsFixed`
      ditulis inline di widget.
- [ ] Kalau ada workbook master buat alat ini, cocokkan minimal satu baris
      contoh persis (nilai DAN jumlah desimal) sebagai kasus test — lihat
      `[[sidik-fe-test-generator]]`.
- [ ] Cek dokumen handoff alat (`docs/handoff-frontend-<alat>.md`) bagian
      "yang beda dari alat lain" SEBELUM asumsi pola alat sebelumnya
      berlaku sama.

## Guidelines
- Kalau ragu angka boleh dibulatkan ulang di widget atau tidak: TIDAK BOLEH
  — pembulatan/pemilihan desimal cuma boleh terjadi lewat
  `desimalEfektif()` + fungsi format di `core/utils/angka.dart`, satu
  tempat, sama seperti aturan "pembulatan satu tempat" di backend.

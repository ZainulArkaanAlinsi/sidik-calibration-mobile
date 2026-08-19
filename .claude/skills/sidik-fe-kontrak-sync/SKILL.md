---
name: sidik-fe-kontrak-sync
description: Audit field/endpoint di docs/kontrak-api.md dan docs/handoff-frontend-*.md terhadap pemakaian nyata di service/model Flutter, cegah drift kontrak backend-FE. Pakai saat kontrak API berubah, sebelum mulai fitur yang konsumsi endpoint baru, atau curiga field FE beda dari backend.
---

# Sidik FE Kontrak-API Sync

Repo `sidik-calibration-mobile` dan `sidik-calibration-api` dua repo
terpisah, disambung MANUAL lewat `docs/kontrak-api.md` (satu sumber
kebenaran, dipegang @raihannazhiif backend). Gak ada type-checking lintas
repo yang nangkep drift otomatis — skill ini gantiin itu.

## Yang Diperiksa

### 1. Field model Dart vs bentuk JSON di dokumen
Untuk model yang lagi disentuh (`lib/models/*.dart`), bandingkan
`fromJson`/`toJson`-nya field-per-field ke contoh JSON di
`docs/kontrak-api.md` atau `docs/handoff-frontend-*.md` terkait. Flag:
- Field ada di dokumen tapi gak dibaca model (data hilang diam-diam).
- Field dibaca model tapi gak ada/beda nama di dokumen (kemungkinan nama
  lama yang backend udah ganti, cek dokumen ada bagian "Update" gak).
- Tipe beda (dokumen bilang number, model expect String atau sebaliknya) —
  ini yang paling sering bikin crash `TypeError` di runtime, bukan error
  yang kelihatan pas compile.

### 2. Endpoint & method dipakai vs didokumentasikan
Path & HTTP method di `Api*Service` (`_api.get/post/put/patch/delete(...)`)
harus persis sama dengan yang tertulis di dokumen — termasuk query param
opsional (`page`, `search`, `pengulangan`, dst).

### 3. Update log di dokumen — WAJIB dibaca, bukan cuma isi terbaru
`kontrak-api.md` ditulis dengan catatan "Update <tanggal> — ..." nempel di
bagian yang berubah (contoh: token Sanctum bukan JWT). Kalau lagi audit
field lama, baca catatan update di sekitarnya dulu — sering ada alasan WHY
kenapa bentuknya berubah, bukan cuma "field baru ditambah".

## Kalau Ketemu Drift

- **Dokumen lebih baru dari kode FE** → backend sudah ubah kontrak, FE
  ketinggalan. Perbaiki model/service ikut dokumen.
- **Kode FE lebih baru dari dokumen** → FE nebak bentuk field yang belum
  didokumentasikan resmi. JANGAN cuma perbaiki kode diam-diam — beri tahu
  user untuk update `docs/kontrak-api.md` juga (dokumen itu dibaca backend
  juga, "satu sumber kebenaran").
- **Endpoint dipakai FE tapi gak ada sama sekali di dokumen** → kemungkinan
  besar backend belum expose. Cek dulu ke repo `sidik-calibration-api`
  sebelum asumsi endpoint itu ada.

## Format Output
- 📍 Field/endpoint yang drift
- 📄 Sumber dokumen vs lokasi kode FE (file:baris)
- ⚠️ Arah drift (dokumen lebih baru / kode lebih baru / endpoint gak ada)
- ✅ Yang perlu diubah, dan di mana (kode FE, atau minta update dokumen)

## Guidelines
- Ini audit read-only dulu — jangan langsung ubah model/service sebelum
  konfirmasi arah drift-nya ke user, karena bisa jadi dokumen yang perlu
  diupdate, bukan kodenya.
- Lanjut ke `[[sidik-fe-service-provider-scaffolder]]` kalau hasil audit
  butuh service/provider baru dibikin.

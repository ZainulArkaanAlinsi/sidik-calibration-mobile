---
name: sidik-fe-screen-scaffolder
description: Generate screen & widget baru di sidik-calibration-mobile dari dokumen handoff backend (kontrak-api.md, handoff-frontend-*.md), ikutin pola folder per domain (list_screen + form_screen), reuse widget bersama di lib/widgets. Pakai saat user minta bikin layar baru atau nyambungin fitur backend yang baru selesai.
---

# Sidik FE Screen Scaffolder

Titik masuk paling sering: user bilang "modul X udah selesai backendnya",
tempel dokumen `docs/handoff-frontend-*.md`, minta dibikinin layarnya. Skill
ini nurunin dokumen itu jadi screen konkret ikut pola yang udah ada.

## Pola Folder per Domain
- `lib/screens/<domain>/` — satu folder per domain (`equipment`,
  `calibration`, `certificate`, `order`, dst), berisi
  `<domain>_list_screen.dart` (daftar + filter + paginasi) dan
  `<domain>_form_screen.dart` (tambah/ubah) kalau CRUD.
- Widget yang dipakai LEBIH dari satu screen dalam domain sama masuk
  `lib/screens/<domain>/widgets/`; yang dipakai LINTAS domain masuk
  `lib/widgets/`. Jangan taruh widget bersama di `lib/screens/<domain>/`
  langsung.
- Model respons API punya file sendiri di `lib/models/<nama>.dart` dengan
  `fromJson`/`toJson` — dibaca dari bentuk JSON di dokumen handoff, BUKAN
  ditebak dari nama field yang "kelihatan masuk akal".

## Alur Baca Dokumen Handoff → Kode

1. Baca `docs/kontrak-api.md` untuk bentuk umum (auth, pagination, format
   error) — itu berlaku semua endpoint, jangan diulang tiap dokumen alat.
2. Baca `docs/handoff-frontend-<alat>.md` untuk yang KHUSUS alat ini:
   endpoint, query param, field yang beda dari alat lain (contoh:
   Conductivity punya `satuan_campuran` per baris, bukan per lembar —
   lihat catatan di dokumen itu SEBELUM asumsi semua alat satu satuan).
3. Cocokkan field respons ke model — kalau field di dokumen belum ada di
   model Dart, tambahkan; jangan bikin model baru yang duplikat kalau
   modelnya udah ada dan cuma butuh field tambahan.
4. Service & provider baru ikut `[[sidik-fe-service-provider-scaffolder]]`.
5. Layar konsumsi provider via `AsyncNotifier`/`FutureProvider`, tampilkan
   loading/error state — jangan `FutureBuilder` manual di atas `Future`
   yang harusnya lewat provider.

## Checklist Sebelum Dianggap Selesai
- [ ] Semua teks user-facing lewat `AppLocalizations` (ID+EN) —
      `[[sidik-fe-code-reviewer]]` §4.
- [ ] Kalau alat baru punya lembar kerja dengan presisi/desimal khusus,
      cek `[[sidik-fe-presisi-sertifikat]]` sebelum dianggap selesai —
      preview di layar harus sama bentuk dengan yang bakal tercetak.
- [ ] Field yang dokumen tandai `hanya_admin: true` — pastikan UI-nya juga
      nge-guard per role, bukan cuma percaya backend udah nyaring (backend
      MEMANG udah nyaring respons, tapi widget admin-only tetap harus
      dicek `role` biar gak nampilin tombol aksi yang bakal 403).

## Guidelines
- Kalau dokumen handoff bilang "endpoint lama, cuma bentuk lembar beda" —
  JANGAN bikin service/provider baru, reuse yang udah ada dan tambahin
  handling bentuk variannya di layar/model.
- Ragu suatu field opsional atau wajib? Cek dulu §0 `kontrak-api.md`
  (format error 422 nunjukin field mana yang required) sebelum nebak.

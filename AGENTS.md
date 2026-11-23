# AGENTS.md — sidik-calibration-mobile (lab app + Sidik Studio)

Agents (Codex, GPT, Claude): read these first, in order.
1. `docs/HANDOFF-CODEX.md` — full handoff (22 Oct 2026): current state, open work, hard rules, lab questions.
2. `CLAUDE.md` — repo conventions.
3. API rules live in the API repo `AGENTS.md` (sidik-calibration-api); they bind mobile work too.

Hard rules (short):
- Never push to `main` directly; PR + green CI. Merging to `main` auto-releases APK and Windows/Studio.
- Releases reach devices via in-app update; never tell the owner to download manually.
- OCR: on-device by default (ML Kit / local engine). **Cloud OCR is allowed since 23 Nov 2026**: Google Cloud Vision (`DOCUMENT_TEXT_DETECTION`) may read the WHOLE page photo, but ONLY through the backend (`POST /api/ocr/halaman`), behind a developer switch that is OFF by default. No Google key, credential or Google URL in the app or APK. Do not enable it for real technicians until the owner has confirmed that customer contracts allow sending page photos (customer names, certificate numbers) to a third party and that ISO/IEC 17025 §4.2 is not violated. No accuracy claims without human-labelled real photos. Suggestions only, no "accept all", empty cell stays empty, handwriting is never shown green. The old digit-character TFLite model/reader was removed (13 Nov 2026). The new TFLite number engine (PP-OCR whole-cell reader, `assets/models/`, `lib/services/ocr_angka/`) sits behind developer switch `PAKAI_MESIN_ANGKA` (old name `PAKAI_MESIN_ANGKA_ONNX` still accepted) and is OFF by default; ML Kit stays the default reader until it is proven on a tablet.
- Do not run emulators on the owner's laptop; one heavy process at a time. Do not commit `pubspec.lock` drift from local SDK.

## Cara kerja agen di repo ini

- Setiap perubahan OCR wajib punya cara verifikasi yang bisa diukur: tes otomatis, perintah evaluasi, atau uji
  pembanding. Jangan menyatakan selesai tanpa itu.
- Kriteria selesai harus bisa diperiksa: semua tes lulus, dan batas percobaan ditulis di awal (3 percobaan
  gagal, lalu berhenti dan lapor). Metrik "hijau palsu" ditulis **"belum terukur"** sampai ada set uji berlabel
  manusia; jangan menulis "nol" tanpa set itu.
- Tinjauan kedua oleh agen lain dengan konteks baru dilakukan untuk perubahan yang menyentuh perhitungan atau
  OCR. Jalankan peninjau independen (di repo API: `sidik-code-reviewer`) sekali sebelum commit.
- Jangan menjadwalkan atau menjalankan loop yang menyentuh server produksi, database, Render (env/deploy), atau
  billing Google tanpa persetujuan pemilik. Pemantauan CI (`gh run watch`, maks 10 menit) tetap boleh.
- Kalau hasil tidak memenuhi standar, catat perbaikan sebagai aturan, tes, atau fixture di repo, bukan hanya
  memperbaiki satu kasus.

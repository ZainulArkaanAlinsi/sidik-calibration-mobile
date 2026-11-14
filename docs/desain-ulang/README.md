# SIDIK Lab — "Biru Awan" (repo `sidik-calibration-mobile`)

Baca berurutan:
1. `BEKU.md` — yang tidak boleh berubah (lembar kerja dkk.) dan cara menguncinya.
2. `PETA-LAYAR.md` — 105 berkas layar: DESAIN / POLA / TOKEN / BEKU.
3. `DESIGN.md` — warna (dengan kontras), huruf, sudut, gerak.
4. `LAYAR.md` — tiap layar berartboard: susunan, ukuran, sumber data, berkas.
5. `POLA.md` — cara menyusun 46 layar tanpa artboard.
6. `ELEMEN.md` — toast, dialog, lembar bawah, banner, keadaan, splash, masuk, kontrol kecil + tabel elemen lanjutan (semua widget yang dipakai app).
7. `VISUAL.md` — 48 gambar untuk 48 alat, 7 gambar bentuk + contoh medis untuk alat baru, cara menggambar.
8. `tokens.json`, `flutter/*.dart` — nilai dan kerangka kode siap tempel.
9. `skill/sidik-ui/SKILL.md` — patokan UI yang dipasang ke `.claude/skills/`.
10. `referensi-html/` — markup artboard; semua angka gaya tertulis inline.

Peran (dari `UserRole`): teknisi · admin = Master Data · superAdmin = admin +
teknisi (sesi isiannya disetujui orang lain) · viewer = baca saja.

Keputusan pemilik yang mengubah `docs/standar-kualitas-desain.md`: primer biru
langit (kobalt hanya logo), kartu 24/28, stempel pil, gambar alat, bayangan hanya
dock/tombol Mulai/toast/dialog. Tetap: Inter + IBM Plex Mono, tanpa paket/font baru,
status ikon + kata, sentuh ≥ 48, `AppMotion`, l10n, aturan keras repo (angka dari
server, OCR saran saja, nilai teknisi tidak dihapus).

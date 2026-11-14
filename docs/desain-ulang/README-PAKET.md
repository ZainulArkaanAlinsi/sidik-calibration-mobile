# Paket desain ulang SIDIK — Pelanggan + Lab (v2, 14 Nov 2026)

Isi:

| Folder | Untuk repo | Isi |
|---|---|---|
| `lab-biru-awan/` | `sidik-calibration-mobile` | teknisi, admin (Master Data), super admin, viewer, elemen + elemen lanjutan, splash, masuk, layar lebar, 57 gambar alat |
| `pelanggan-bento-lab/` | `sidik-pelanggan-mobile` | 6 layar + komponen + elemen + gambar alat |
| `PROMPT.md` | keduanya | prompt bertahap untuk Claude Sonnet di Claude Code, satu PR per prompt |

Hal yang PALING penting:
1. **Lembar kerja app Lab dikunci** (`lab-biru-awan/BEKU.md`). Prompt L0 membuat
   tes golden SEBELUM apa pun berubah; setiap PR sesudahnya harus lolos golden itu.
2. **Hanya UI.** Tidak ada perubahan API, logika hitung, alur, struktur tab/laci,
   atau aturan peran. `sidik-calibration-api` tidak disentuh (A0 hanya membaca).
3. **Patokan UI untuk masa depan** = skill Claude Code `sidik-ui` (Lab) dan
   `sidik-ui-pelanggan`, dipasang di `.claude/skills/` masing-masing repo. Setelah
   terpasang, Claude Code otomatis memakainya setiap kali membuat UI baru.

Cara pakai:
1. Salin `lab-biru-awan/` ke `sidik-calibration-mobile/docs/desain-ulang/` dan
   `pelanggan-bento-lab/` ke `sidik-pelanggan-mobile/docs/desain-ulang/`.
2. Buka Claude Code di repo itu, pilih model Sonnet, tempel "Pembuka sesi" dari
   PROMPT.md, lalu prompt langkah pertama. Satu prompt = satu PR. Uji di HP, merge,
   baru prompt berikutnya.

Canvas (bisa dibuka, tombol Play untuk mencoba):
- Lab: https://claude.ai/artifact/PRFdznJjNfaPHRjiSZ8AfC
- Pelanggan: https://claude.ai/artifact/6diwFNURJtVYqRR8uJE8gi

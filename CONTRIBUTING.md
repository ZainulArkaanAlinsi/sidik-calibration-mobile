# Cara Kerja Bareng — ASMO Mobile

Repo ini dikerjakan berdua (@ZainulArkaanAlinsi & @raihannazhiif). Tulisan ini biar kita nggak nabrak-nabrakan kerjaan.

## Setup Pertama Kali

```bash
git clone https://github.com/ZainulArkaanAlinsi/asmo-mobile.git
cd asmo-mobile
git config core.hooksPath .githooks   # WAJIB — aktifin pengaman branch main
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

> **Jangan skip baris `core.hooksPath`.** Itu yang bikin git nolak kalau kamu nggak sengaja push ke `main`. Cukup sekali per laptop.

## Branch

| Branch | Isinya |
| --- | --- |
| `main` | Versi stabil. **Jangan pernah push langsung ke sini.** Cuma keisi dari `develop` pas mau demo/rilis. Dijaga hook `.githooks/pre-push` — push langsung bakal ditolak. |
| `develop` | Branch integrasi. Kerjaan yang udah kelar dimerge ke sini. |
| `feature/<nama>` | Tempat ngoding. Satu fitur satu branch, mis. `feature/bottom-nav`, `feature/login`. |

## Alur Harian

**1. Mulai kerja — tarik dulu punya orang, jangan langsung ngoding:**
```bash
git checkout develop
git pull origin develop
```

**2. Bikin branch buat kerjaan hari ini:**
```bash
git checkout -b feature/bottom-nav
```

**3. Commit pakai Conventional Commits:**
```bash
git add .
git commit -m "feat: bottom navigation 5 tab"
```
Prefix: `feat:` (fitur baru), `fix:` (benerin bug), `refactor:`, `docs:`, `test:`, `chore:`.

**4. Sebelum push, pastikan nggak bawa error:**
```bash
flutter analyze   # harus 0 issue
flutter test      # harus lolos semua
```

**5. Push & buka PR ke `develop`:**
```bash
git push -u origin feature/bottom-nav
gh pr create --base develop --fill
```
Atau lewat web — GitHub bakal nawarin tombol "Compare & pull request".

**6. Yang satunya review PR-nya**, kasih komentar / approve, baru di-merge. Jangan merge PR sendiri tanpa dilihat partner — ini gunanya kita berdua.

## Cara Lihat Perubahan Partner

- **Notifikasi otomatis**: tiap ada PR/commit baru, muncul di tab [Pull requests](https://github.com/ZainulArkaanAlinsi/asmo-mobile/pulls) dan email GitHub.
- **Baca perubahannya baris per baris**: buka PR → tab **Files changed**. Di situ bisa komentar langsung di baris tertentu.
- **Dari terminal**:
  ```bash
  git fetch --all              # tarik semua update tanpa ngubah kerjaan kamu
  git log --oneline --all      # lihat semua commit, termasuk punya partner
  gh pr list                   # lihat PR yang nunggu direview
  gh pr checkout 3             # cobain branch PR #3 di laptop sendiri
  ```

## Ngoding Bareng Real-Time (VS Code Live Share)

Kalau lagi mau ngerjain satu masalah barengan (mis. debug OCR), pakai **Live Share** — dua-duanya ngetik di file yang sama, kelihatan kursornya:

1. Di VS Code, tekan `Ctrl+Shift+P` → **Live Share: Start Collaboration Session**
2. Link-nya ke-copy otomatis, kirim ke partner
3. Partner buka link itu → langsung masuk ke workspace kamu, nggak perlu clone

Live Share buat **pair programming sesaat**, bukan pengganti git. Hasil akhirnya tetap harus di-commit & di-push seperti biasa.

## Aturan Main Biar Nggak Bentrok

- **Jangan ngedit file yang sama barengan** tanpa ngobrol dulu. Bagi tugas per layar/fitur.
- **Pull tiap pagi**, push tiap sore — jangan numpuk kerjaan 3 hari baru push, konfliknya ngeri.
- Kalau kena **merge conflict**, jangan panik dan jangan `--force`. Kabarin partner, selesaikan berdua.
- Rencana harian & pembagian tugas ada di vault Obsidian `Project-PT-ASMO/` (nggak ikut ke-push ke repo ini).

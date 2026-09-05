# Prompt terminal yang kebaca — di mesin mana pun

**Kenapa berkas ini ada.** Prompt bawaan cuma nampilin path. Tiga hal yang paling
sering bikin salah langkah di project ini justru tidak kelihatan sama sekali:

| Yang tidak kelihatan | Akibatnya |
|---|---|
| Lagi di branch apa | Ngoding sejam di `main`, baru sadar pas `git push` ditolak hook |
| Ada kerjaan yang belum di-commit | Pindah branch, kerjaan kebawa / ketinggalan |
| Versi Flutter yang lagi aktif | **Yang paling mahal.** CI mematok `3.44.6`. Mesin yang versinya beda menghasilkan "hijau di CI, merah di laptop" — kebalikan dari gunanya CI (lihat [`sinkron-laptop-windows.md`](sinkron-laptop-windows.md)) |

Mesinnya [oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh) — satu binary
Go plus satu berkas tema JSON, dan dia yang merakit baris prompt untuk shell apa
pun. Temanya ada di [`tool/terminal/sidik.omp.json`](../tool/terminal/sidik.omp.json).

---

## 1. Pasang

**macOS / Linux** (bash, zsh, fish — termasuk Git Bash & WSL di Windows):

```bash
./tool/pasang-terminal.sh
```

**Windows — pakai PowerShell, bukan Command Prompt:**

```powershell
.\tool\pasang-terminal.ps1
```

Lalu **buka terminal baru**. Selesai.

> **`cmd.exe` tidak didukung.** Bukan karena belum dikerjakan — oh-my-posh
> menyetel prompt cmd lewat skrip **Lua**, dan Lua cuma bisa jalan di cmd kalau
> ada [Clink](https://chrisant996.github.io/clink/). Buktinya bisa dilihat
> sendiri: `oh-my-posh init cmd` mengeluarkan `os.setenv(...)`, bukan perintah
> cmd. Jadi di Windows bukalah **PowerShell** (tekan tombol Windows, ketik
> "PowerShell") atau **Windows Terminal**. Kalau memang harus di cmd, pasang
> Clink dulu — skrip ini tidak mengurusnya.

Ingat juga cmd dan PowerShell beda cara baca variabel: `$POSH_CONFIG` cuma jalan
di PowerShell (`$env:POSH_CONFIG`), sedangkan cmd memakai `%POSH_CONFIG%`. Dan
tanda sambung baris `\` itu milik bash — di PowerShell pemisahnya backtick
`` ` ``, di cmd `^`.

Skripnya boleh dijalanin berkali-kali — blok yang lama diganti, bukan ditumpuk.
Yang dia kerjakan: pasang oh-my-posh kalau belum ada, pasang Nerd Font, salin
tema ke `~/.config/oh-my-posh/`, dan tambah satu blok bertanda ke berkas rc/profil.

> **Di Windows, binary yang diunduh diperiksa dulu.** Waktu `winget` tidak ada,
> skripnya menarik `.exe` mandiri dari GitHub Releases — dan sebelum berkas itu
> dipakai atau didaftarkan ke PATH, SHA256-nya diadu ke `checksums.txt` milik
> rilis yang sama.
>
> Yang penting soal cara gagalnya: kalau `checksums.txt` tidak bisa diunduh atau
> nama asetnya tidak terdaftar di situ, **pemasangan berhenti** — bukan lanjut
> tanpa diperiksa. Pemeriksaan yang diam-diam berubah jadi "tidak diperiksa"
> lebih buruk daripada tidak ada pemeriksaan sama sekali, karena dia terbaca
> sebagai sudah diverifikasi. Berkas yang ditolak juga langsung dihapus, supaya
> tidak nangkring di folder yang sebentar lagi masuk PATH.
>
> Jalur `winget` dan jalur Homebrew/`install.sh` di macOS-Linux tidak diperiksa
> di sini — verifikasinya sudah jadi urusan package manager masing-masing.

| Opsi | Gunanya |
|---|---|
| `--tanpa-font` / `-TanpaFont` | Lewati pemasangan font (font-nya sudah ada) |
| `--tautan` / `-Tautan` | Symlink tema ke repo, bukan disalin — buat ngoprek temanya |
| `--cabut` / `-Cabut` | Balikin seperti semula |

> **Kenapa temanya disalin, bukan dibaca langsung dari repo?** Supaya prompt tetap
> hidup di folder mana pun — termasuk waktu repo ini lagi dipindah, di-`git clean`,
> atau belum di-clone di mesin itu. Kalau temanya ikut hilang, yang rusak bukan
> cuma tampilan tapi seluruh prompt. Konsekuensinya: **kalau temanya diubah di
> repo, jalankan skripnya sekali lagi** biar salinannya ikut baru. Kecuali kamu
> pasang pakai `--tautan`.

---

## 2. Font — ini yang paling sering bikin "kok jelek?"

Prompt-nya pakai glyph **Nerd Font** (ikon folder, cabang git, logo Flutter).
Kalau font terminalnya belum diganti, glyph itu muncul jadi **kotak kosong** (`▯`)
atau tanda tanya. Konfignya benar, fontnya yang belum.

Skrip di atas sudah memasang **MesloLGM Nerd Font** ke sistem, tapi **memilih font
itu di aplikasi terminal harus manual** — tidak ada aplikasi terminal yang mau
diganti fontnya dari luar.

| Aplikasi | Langkahnya |
|---|---|
| **Windows Terminal** | `Ctrl+,` → pilih profilnya → *Appearance* → *Font face* → **MesloLGM Nerd Font** |
| **VS Code** (terminal built-in) | `Ctrl/Cmd+,` → cari `terminal.integrated.fontFamily` → isi `MesloLGM Nerd Font` |
| **iTerm2** (macOS) | *Settings* → *Profiles* → *Text* → *Font* → **MesloLGM Nerd Font** |
| **Terminal.app** (macOS) | *Settings* → *Profiles* → *Text* → *Change...* → **MesloLGM Nerd Font** |
| **GNOME Terminal** | *Preferences* → profil → *Custom font* → **MesloLGM Nerd Font** |

Android Studio & JetBrains: *Settings* → *Editor* → *Color Scheme* → *Console Font*.

---

## 3. Yang ditampilkan

```
┌─ ikon OS      ┌─ path (2 folder terakhir)   ┌─ git     ┌─ versi toolchain
│               │                             │          │
▼               ▼                             ▼          ▼
  macOS      ~ › sidik-calibration-mobile    main +2 ~1   3.44.6       1.2s  14:32
❯                                                                          ▲     ▲
▲                                                                          │     └─ jam
└─ hijau = perintah tadi sukses · merah = gagal                            └─ lama perintah (>2 detik)
```

| Segmen | Muncul kapan | Isinya |
|---|---|---|
| OS | selalu | ikon macOS / Windows / Linux |
| Path | selalu | 2 folder terakhir, `~` untuk home |
| Git | di dalam repo | nama branch (dipotong 24 huruf), jumlah berkas berubah, beda dari remote |
| Flutter | ada `pubspec.yaml` | versi Flutter yang **benar-benar** aktif |
| PHP / Node / Python | ada berkas projectnya | versi aktif — berguna waktu buka repo `sidik-calibration-api` |
| Root | lagi jadi root/admin | ikon kunci inggris merah — peringatan |
| Lama perintah | perintah > 2 detik | mis. `flutter test` makan berapa lama |
| Baterai | laptop | merah kalau di bawah 20% |
| Jam | selalu | jam selesainya perintah |

Segmen bahasa **hilang total** kalau toolchain-nya tidak terpasang — bukan
nampilin "NO VERSION". Jadi prompt-nya tetap bersih di folder biasa.

### Warnanya bukan asal pilih

Temanya memakai palet yang **sama persis** dengan aplikasinya
([`lib/core/theme/app_colors.dart`](../lib/core/theme/app_colors.dart)), dengan
aturan yang sama: warna inti dipakai rata, tidak pernah dicampur, dan tingkatan
dibuat dengan menggelapkan warna yang sama — bukan meleburkan dua warna.

| Warna | Hex | Di app | Di prompt |
|---|---|---|---|
| Cobalt | `#2962FF` | satu-satunya warna interaktif | path — jangkar posisi, tidak pernah berarti status |
| Mint | `#9FF5E4` | aksen + status lolos | git bersih |
| Mint deep | `#0B7A67` | — | git ada perubahan · `❯` sukses |
| Mint ink | `#05473B` | — | git beda dari remote (ahead/behind) |
| Crimson | `#D91E41` | status gagal, dipakai paling irit | `❯` gagal · root · baterai kritis |
| Ink elevated | `#262626` | permukaan | OS & versi toolchain — netral, tidak berteriak |

Kalau PT Sidik ganti warna brand, `app_colors.dart` dan blok `palette` di
`sidik.omp.json` sama-sama perlu diganti.

---

## 4. Kalau ada masalah

| Gejalanya | Sebabnya | Bereskan |
|---|---|---|
| Ikonnya kotak-kotak `▯` | Font terminal belum diganti | §2 di atas |
| Prompt tidak berubah sama sekali | Terminalnya belum dibuka ulang | Tutup & buka lagi, atau `exec $SHELL` |
| `oh-my-posh: command not found` tiap buka shell | Binary-nya terpasang tapi belum di PATH | Jalankan ulang skripnya — blok yang ditulis sudah menyertakan `~/.local/bin` |
| Windows: sudah `winget install` tapi tidak kebaca | PATH sesi lama belum ikut baru | Tutup & buka PowerShell, jalankan skripnya sekali lagi |
| `'oh-my-posh' is not recognized` | Belum terpasang di mesin itu — atau kamu di `cmd.exe`, yang memang tidak didukung | Buka **PowerShell**, lalu jalankan `.\tool\pasang-terminal.ps1` dari dalam folder repo |
| `echo $POSH_CONFIG` malah mencetak `$POSH_CONFIG` | Itu sintaks bash. cmd/PowerShell beda | PowerShell: `$env:POSH_CONFIG` · cmd: `%POSH_CONFIG%` |
| Versi Flutter di prompt beda dari `flutter --version` | Ada dua SDK di PATH, atau `fvm` aktif | `which -a flutter` (Windows: `where.exe flutter`) |
| Versi Flutter telat berubah setelah ganti SDK | Versinya di-cache 24 jam per folder | `oh-my-posh cache clear` |
| Prompt terasa lambat | Ada segmen yang menunggu proses lain | `oh-my-posh debug --config ~/.config/oh-my-posh/sidik.omp.json` — dia nunjukin segmen mana yang lama |
| Windows: `0x80073CF6` / `cannot create the AppContainer profile` | Pemasangan MSIX ditolak Windows — tidak ada hubungannya dengan oh-my-posh | Skrip ini sudah tidak memakai MSIX; pastikan kamu di versi terbaru (`git pull`) lalu jalankan lagi. Dia bakal mengunduh binary mandiri ke `%LOCALAPPDATA%\Programs\oh-my-posh\bin` |
| Windows: `winget tidak ada` | App Installer belum terpasang / belum di PATH | Tidak perlu dibetulkan — skripnya otomatis pindah ke jalur binary mandiri |
| Windows: `checksum nggak cocok` | Unduhan rusak di tengah jalan, atau rilis baru terbit persis waktu skrip lagi jalan | Jalankan skripnya sekali lagi. Berkas yang ditolak sudah dihapus sendiri, jadi tidak ada sisa yang bisa kejalan |
| Windows: `checksum buat ... nggak ada di ...` | `checksums.txt` gagal diunduh (proxy/kantor memblokir), atau nama asetnya berubah di rilis baru | Pemasangan sengaja DIHENTIKAN, bukan diteruskan tanpa verifikasi. Cek koneksi ke `github.com`, lalu ulangi |
| Windows: `.ps1 cannot be loaded` | Execution policy | `Set-ExecutionPolicy -Scope Process Bypass` lalu jalankan lagi |

---

## 5. Ngoprek temanya

```bash
./tool/pasang-terminal.sh --tautan     # tema dibaca langsung dari repo
$EDITOR tool/terminal/sidik.omp.json   # edit
exec $SHELL                            # lihat hasilnya
```

Lihat hasilnya tanpa buka shell baru:

```bash
oh-my-posh print primary --config tool/terminal/sidik.omp.json --shell bash
```

Daftar segmen & opsinya: <https://ohmyposh.dev/docs/segments>. Kumpulan tema
bawaan oh-my-posh buat contekan: <https://ohmyposh.dev/docs/themes>. Untuk
menyalin konfig yang lagi aktif ke berkas lain: `oh-my-posh config export
--output ~/tema.json`.

Kalau nambah segmen, ikuti aturan palet di §3 — pakai referensi `p:cobalt`,
`p:mint`, dst. yang sudah didefinisikan di blok `palette`, jangan tulis hex baru
langsung di segmen.

---

## 6. Cabut

```bash
./tool/pasang-terminal.sh --cabut      # macOS/Linux
.\tool\pasang-terminal.ps1 -Cabut      # Windows
```

Blok di rc/profil dan salinan temanya dihapus. Binary oh-my-posh dan font-nya
sengaja **dibiarkan** — dua-duanya kepakai project lain juga, dan menghapusnya
diam-diam lebih ngeselin daripada menyisakan satu binary 15 MB.

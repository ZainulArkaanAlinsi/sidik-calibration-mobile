# SIDIK — Serah terima lengkap (untuk Codex / GPT / agen berikutnya)

Ditulis 22 Okt 2026 oleh Claude (Claude Code). Pemilik: Zainul (zainaril13@gmail.com).
Target pemilik: **semua project Sidik selesai Jumat 24 Okt 2026 siang**, tanpa bug/error,
rilis lewat update otomatis di aplikasi. Bahasa ke pemilik: Indonesia santai, singkat, jujur
(jangan bilang "udah" kalau belum terbukti — pemilik sangat sensitif soal ini).

> Baca juga: `C:\Users\USER\sidik-calibration-api\AGENTS.md` (aturan keras repo API — WAJIB),
> `sidik-calibration-api/docs/permintaan-user-7.md` (§49–§55 keputusan & status),
> `C:\Users\USER\sidik-calibration-api\_agents_workspace\studio-kendali-olah-data\` (00-status,
> 02-rencana, 05-profil-progres, 06-survei-master — catatan kerja lokal, tidak di-commit).

---

## 1. Peta sistem

| Bagian | Repo / lokasi | Teknologi | Jalan di |
|---|---|---|---|
| Server API + panel admin | `github.com/ZainulArkaanAlinsi/sidik-calibration-api` (lokal: `C:\Users\USER\sidik-calibration-api` + banyak worktree `sidik-api-*`) | Laravel 13, Filament 5, PHP 8.4, MySQL (Aiven) | Render free, Singapore, Docker FrankenPHP. URL `https://sidik-calibration-api.onrender.com` |
| App lab (teknisi, Master Data/admin, super admin, viewer) — Android HP/tablet + Windows desktop | `github.com/ZainulArkaanAlinsi/sidik-calibration-mobile` (lokal: `C:\Users\USER\sidik-calibration-mobile`, worktree kerja `C:\Users\USER\sidik-mobile-ocr-tt`) | Flutter + Riverpod | APK via GitHub Releases + update otomatis di app; Windows zip via Firebase Hosting `sidik-kalibrasi.web.app` |
| **Sidik Studio** (desktop Windows, kelola master Excel jarak jauh) | folder `studio/` di repo mobile | Flutter desktop | Rilis via job `studio` di `.github/workflows/rilis-desktop.yml` → Firebase `versi-studio-windows.json` |
| App pelanggan (view-only) | `github.com/ZainulArkaanAlinsi/sidik-pelanggan-mobile` (lokal `C:\Users\USER\sidik-pelanggan-mobile`) | Flutter Android | GitHub Releases + update otomatis (manifest `versi-pelanggan.json`) |
| Master Excel lab (kebenaran rumus) | `C:\Users\USER\Downloads\EXEL CALIBRATION SIDIK\` (72 file, 69 terenkripsi) | .xlsm | HANYA dibaca di tempat. Jangan pernah disalin ke repo |

Peran: `super_admin`, `admin` (label "Master Data"), `teknisi`, `viewer` (lama), `pelanggan`.
Jangan ubah nilai kolom `role`.

## 2. Keadaan produksi saat ini (22 Okt 2026 sore)

- **API live**: `main` = `51106b0` (pin PHP 8.4.27; deploy sedang diverifikasi — cek
  `/api/health`: `deploy.versi`, `php_versi` harus `8.4.27`, `append_only_db` harus `true`).
  Sebelumnya `baa418b` (Studio fondasi + alur versi acuan + Micrometer) sudah live & terverifikasi.
- **App lab**: rilis `v1.0.754+754` (GitHub Releases), feed `/api/app/versi-terbaru` menunjukkan 1.0.754.
- **App pelanggan**: `v0.2.0+2` (rilis pertama yang bisa update sendiri; HP lama harus pasang manual
  sekali dari `https://github.com/ZainulArkaanAlinsi/sidik-pelanggan-mobile/releases/latest/download/sidik-pelanggan.apk`).
- **Windows & Studio**: build sukses tapi **terbit ke Firebase gagal 403** (lihat §7 blocker 1).
- **Server tidak tidur**: pemilik pasang cron-job.org ketuk `/up` tiap 10 menit (aktif).
- **Trigger append-only** log alur acuan: terpasang di produksi (`append_only_db: true`).

## 3. Aturan keras (dilanggar = tidak ada error, tapi rusak)

1. **Push ke `main` API = deploy produksi.** Satu push, satu deploy; tunggu deploy sebelumnya
   terverifikasi (`gh run` hijau + `/api/health` `deploy.versi` cocok). Workflow `tes.yml`
   menjalankan phpunit lalu Deploy Hook Render.
2. **Dua suite wajib hijau sebelum modul "selesai"**: SQLite (`php artisan test`) dan MySQL
   (`& C:\Users\USER\sidik-calibration-api\jalankan-test-mysql.ps1` dari folder checkout; skrip itu
   memegang sandi DB test lokal — jangan dicetak). SQLite ±2,5 jam, MySQL ±3,5 jam di laptop ini.
   **Jangan pernah dua proses test di checkout yang sama** (Storage::fake bentrok → hasil palsu).
   Worktree wajib punya `vendor/` salinan nyata (bukan symlink). `APP_KEY` diset acak di env proses.
3. **Mobile & pelanggan: tidak push langsung ke `main`** — lewat PR, merge setelah CI hijau.
   Merge ke `main` mobile otomatis memicu `apk-rilis-cloud.yml` (APK) dan `rilis-desktop.yml`
   (Windows/web/Studio). App yang terpasang memunculkan update sendiri — **jangan suruh pemilik
   unduh manual** (kecuali bootstrap pertama).
4. **Jangan tulis ke DB produksi** tanpa perintah eksplisit (tabel + jumlah baris). Dilarang tanpa izin:
   `sertifikat:bangun-ulang --termasuk-terbit`, `kalibrasi:hitung-ulang` di produksi, aktivasi master 187/152,
   `kalibrasi:pindahkan-pengesahan --jalankan`. Render MCP: baca saja (workspace `tea-d9sjukajobas73fgipag`,
   service `srv-d9sk4p7avr4c73beba80`); jangan ubah env var/deploy lewat MCP.
5. **Secret**: jangan cetak/commit. Sandi master Excel ada di env Windows User `SIDIK_MASTER_SANDI`
   (baca via registry HKCU\Environment, dekripsi ke memori saja, jangan tulis berkas terdekripsi).
6. **Master ditiru, tidak dibetulkan diam-diam**; kejanggalan → pertanyaan lab bernomor.
   Sertifikat harus sama persis dengan lembar SERTIFIKAT master (keputusan K-50-15).
   Sertifikat terbit beku (snapshot); nilai yang diisi teknisi tidak pernah dihapus (ISO 17025 7.5.2).
7. **OCR**: hanya di HP (ML Kit + TFLite sendiri, tidak cloud); saran saja, tanpa "terima semua";
   tidak ada hijau palsu; sel kosong tetap kosong; model TFLite digit MATI sampai "Gerbang 0";
   jangan klaim akurasi tanpa angka.
8. Laptop pemilik lemah (pernah bluescreen saat emulator + build). **Jangan jalankan emulator.**
   Satu proses berat sekaligus. Pemilik yang menguji di HP sungguhan.

## 4. Yang sudah selesai & live

- OCR kamera tahan HP sungguhan (PR #209): modul ML Kit belum terunduh, tanpa Play Services,
  izin kamera ditolak, foto hilang saat activity dibunuh (retrieveLostData + konfirmasi),
  batas 4200 px, server bangun, `<queries>` IMAGE_CAPTURE.
- Update otomatis semua role + Windows banner + Studio self-update (PR #210, #208 BOM fix).
- App pelanggan: tahan cold start Render (retry 90 s), UI HP sempit, self-update (PR #7, #8, #9).
- API: Studio mengendalikan data acuan (lapis 1) — fondasi peta sel per profil
  (`database/data/peta-sel/<kode>.json`), validasi struktur master saat impor (422
  `struktur_master_berubah`), draf `paket_acuan_versi`, alur **ajukan → simulasi → aktifkan**
  (`/api/data-acuan/...`, aktifkan = super_admin + sandi + bukan pembuat/pengimpor, pengakuan wajib),
  log append-only + trigger DB, `--ganti` jadi riwayat, `bangun-ulang` dry-run default.
  Micrometer live. Layar alur di app lab + Studio read-only (PR #211).
- Keamanan PHP CVE-2026-109618/109619: produksi terbukti PHP 8.4.27 (digest image), lalu dikunci
  di Dockerfile + penjaga build + `php_versi` di health (`51106b0`). api-security-scanner PR #1
  (pin 8.3.36). Laragon lokal: PHP 8.4.27 & 8.3.36 terpasang di `C:\laragon\bin\php\`, PATH User
  sudah dialihkan; PATH Machine + pilihan versi Laragon menunggu pemilik (perlu Admin).

## 5. Pekerjaan BELUM selesai (urutan prioritas untuk Jumat)

### 5.1 API branch `feat/studio-peta-profil` — worktree `C:\Users\USER\sidik-api-profil` (26 commit, belum push)
Isi: peta sel + paritas untuk dial_indicator, height_gauge, jangka_sorong, volumetric, flowmeter,
gaya, putaran, timer_stopwatch, tekanan, piston_volume, kalibrator_suhu, enclosure (CY saja),
tids, sieve, timbangan, suhu_3alat, anak_timbangan, chlorine, do_meter; `kodePaketAcuan()` paket
bersama; `bersama_antar_paket`; fix rute `%2F`; fix keamanan sandi di 3 skrip (`7712108`);
**format sertifikat = master (K-50-15, `d86fc69`)** — mengubah cetak TIDS, Micrometer varian A
(U95 `0.0000`), Enclosure CY set point 5–6.
Langkah:
1. **Review angka dulu** (agen penjaga-angka / reviewer): khususnya Micrometer A U95 `0.0000`
   (contoh master itu sesi inch — cek apakah untuk mm benar), TIDS kolom standar/UUT/koreksi,
   Enclosure `desimal_setting`. Kalau ragu → tahan perubahan format alat itu, tanya lab.
2. Rebase ke `origin/main` (sekarang `51106b0`), selesaikan konflik (kemungkinan di `routes/api.php`,
   `docs/permintaan-user-7.md`).
3. Gate penuh SQLite lalu MySQL (berurutan, satu checkout). Hijau → fast-forward `main` → verifikasi deploy.
4. Sisa profil konstanta-kode (belum): Autoclave, Conductivity, pH, Refractometer, Spectrophotometer,
   Turbidimeter, Viscometer, Gas Detector, Hydrometer, Volumetric Rev7 — pola di `05-profil-progres.md`
   (generator ber-alamat dari .xlsm → `tabel-standar-<alat>.json` → `skemaAcuan()` → Tabel* via
   `SumberAcuan` → peta sel → test paritas; angka tidak boleh berubah).
5. Enclosure Recorder ditahan (pertanyaan lab −20 °C).

### 5.2 API branch `feat/titik-ukur-sesi` — worktree `C:\Users\USER\sidik-api-gabung` (commit `9187cc5`, belum push)
Titik ukur per sesi di server: `CalibrationProfile::batasTitik()/titikSesiBawaan()/cakupanCmcTitik()`,
`app/Services/Calibration/TitikUkurSesi.php`, simpan di `spesifikasi_alat.titik_sesi` (revisi, 409
konflik), nonaktif (tidak hapus) + alasan, audit, `titik_di_luar_cmc` (ERROR tanpa justifikasi),
catatan kaki titik pelanggan di sertifikat. Pilot: Timer, Timbangan, Micrometer (tanpa tambah),
Tekanan; generik untuk 11 profil jalur datar. Kontrak mobile: `docs/perintah-frontend-titik-ukur-sesi.md`.
Langkah: review (`sidik-peninjau`) → rebase ke main (dan urutkan dengan 5.1) → gate 2 suite → deploy
→ kerjakan **sisi mobile** (lihat 5.3).

### 5.3 Mobile — titik ukur per sesi (belum dimulai)
Di `lib/screens/calibration/lembar_kerja*`, `lembar_kerja_state.dart` (`_titikKustom`, `aturTitik`,
`toDraftJson`, `muatDariSesi`), `pengatur_titik.dart`:
- baca `data.batas_titik` + `titik_sesi_bawaan` dari `GET /calibrations/lembar-kerja`, dan
  `meta.titik_sesi.set` dari `GET /calibrations/{id}`; pulihkan di `muatDariSesi`;
- kirim `titik_sesi {revisi, titik[], pengulangan}` saat simpan/preview; tangani 409 (muat ulang + beri tahu);
- "hapus titik" diganti **nonaktifkan + alasan** (isian tidak dikosongkan);
- titik pelanggan (asal `pelanggan`, alasan wajib); tampilkan peringatan `titik_di_luar_cmc`.
Rilis via PR → update otomatis.

### 5.4 Infra / pemilik
1. **Firebase IAM**: service account di secret `FIREBASE_SERVICE_ACCOUNT` (proyek `sidik-kalibrasi`)
   butuh role **Service Usage Consumer**. Sesudah itu re-run workflow "Rilis desktop & web".
   Tanpa ini Windows & Studio tidak dapat update.
2. Render env `GITHUB_TOKEN` (read-only) supaya `/api/app/versi-terbaru` tidak jatuh ke fallback.
3. Sandi master Excel ada di riwayat git PUBLIK repo API (3 skrip lama) → rotasi sandi di lab atau
   rewrite riwayat (force-push butuh izin eksplisit pemilik).
4. api-security-scanner: setelah PR #1 merge → `fly deploy` (flyctl belum terpasang di laptop).
5. Laragon: PATH Machine + pilih versi PHP baru di menu Laragon (perintah ada di chat 22 Okt).

## 6. Pertanyaan lab terbuka (jangan dikarang)
- Enclosure Recorder: titik −20 °C (JSON tidak memuat, master memuat). `koreksi_sensornew` #REF! (42 rumus).
- DRUCK07G jatuh tempo: `STANDAR_DRUCK!K3` 2027-04-29 vs `DATABASE!X13` 2028-04-29.
- Pressure Differential S/N: `211H18280008` vs `21H18280008`.
- TITS ketertelusuran: sertifikat LK-241-IDN vs tabel STANDAR LK-202-IDN; master Measure menulis "Std Mode: Source".
- TIDS dryblock serial beda JSON vs master.
- Anak Timbangan: TH-7 vs Thermobarometer (master memakai pilihan DATABASE S32:T42); tekanan wajib?
- Timbangan: pita Q JSON 2000.001 vs rumus master `<=2000`; maks titik 10 vs 11 slot master.
- Micrometer titik tambahan di luar 11 nominal (butuh tumpukan balok dari IK).
- Pengulangan Timer/Micrometer minimal (IK 3 & 5 vs app 2–10).
- Tautan luar barometer_*/index_* di 12+ master — nilai cache belum diverifikasi ke workbook sumber.

## 7. Cara kerja yang terbukti
- Riset paralel → rencana → bangun → peninjau independen (+ penjaga-angka untuk angka) → gate → deploy.
- Bukti dulu, klaim belakangan: `file:baris`, sel master `Sheet!A1`, angka test. Bedakan terbukti/dugaan.
- Status ke pemilik: hasil dulu, singkat, bahasa awam; sebut terang yang belum terbukti.
- Catatan kerja: `C:\Users\USER\sidik-calibration-api\_agents_workspace\studio-kendali-olah-data\00-status.md`.
- Log test: `C:\Users\USER\sidik-test-logs\` (gate detached: `gate-studio.ps1` contoh pola).

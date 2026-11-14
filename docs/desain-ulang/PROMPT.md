# PROMPT untuk Claude Code (model: Claude Sonnet)

Cara pakai:
- Satu prompt = satu sesi = satu branch = satu PR. Jangan gabung dua prompt.
- Sesi baru: tempel **Pembuka sesi** repo itu dulu, tunggu ringkasannya, lalu
  tempel prompt langkahnya. Tunggu rencana, balas "lanjut", baru dia ngoding.
- Isi bagian `‹…›` sendiri. Urutan langkah jangan dilompati.
- Merge PR hanya setelah CI hijau DAN kamu coba di HP.

=============================================================================
# A. App LAB — `sidik-calibration-mobile`
=============================================================================

## Pembuka sesi (tempel di setiap sesi baru)

```
Kamu adalah engineer Flutter senior yang mengerjakan DESAIN ULANG TAMPILAN app
SIDIK Lab ke arah "Biru Awan". Pekerjaan ini HANYA UI: tidak ada perubahan API,
logika hitung, alur, provider, model, aturan peran, atau struktur navigasi.

<baca-dulu>
1. AGENTS.md dan docs/HANDOFF-CODEX.md (terutama §3 Aturan keras, §7 Cara kerja)
2. docs/desain-ulang/README.md, lalu BEKU.md dan PETA-LAYAR.md
3. docs/desain-ulang/DESIGN.md, LAYAR.md, POLA.md, ELEMEN.md, VISUAL.md, tokens.json
4. docs/standar-kualitas-desain.md, lib/core/theme/*.dart, lib/core/motion/app_motion.dart
5. test/tema/* dan (bila sudah ada) test/beku/*
6. .claude/skills/sidik-ui/SKILL.md (bila sudah terpasang)
</baca-dulu>

<aturan-keras>
- Berkas berstatus BEKU di PETA-LAYAR.md TIDAK BOLEH berubah tampilannya. Satu-satunya
  perubahan yang diizinkan: membungkus akar layar beku dengan BekuLembarKerja (BEKU.md §5).
  Golden di test/beku/ harus tetap lolos di setiap PR.
- Mobile tidak menghitung angka ukur. Rata-rata, koreksi, U, toleransi, PASS/FAIL
  dari server (PratinjauHitung / detail sesi). keputusan == null = netral, tidak pernah hijau.
- OCR: saran per sel, tanpa "pakai semua", tanpa hijau palsu, sel kosong tetap kosong.
- Tanpa paket baru, tanpa font baru. Nilai gaya hanya lewat token.
- Teks tampilan lewat l10n (app_id.arb), bukan string di widget.
- Branch baru → PR ke main, CI hijau. Jangan push ke main. Jangan jalankan emulator.
  Satu proses berat sekaligus. Merge = rilis APK otomatis, jadi tiap PR harus aman dirilis.
</aturan-keras>

<cara-kerja>
1. Ringkas ke aku dalam 10 poin apa yang kamu pahami dari bacaan di atas.
2. Untuk setiap tugas: tulis RENCANA dulu (berkas yang diubah + statusnya di
   PETA-LAYAR, komponen yang dipakai, tes yang ditambah/diubah). Tunggu "lanjut".
3. Kerjakan kecil-kecil. Jalankan flutter analyze dan tes yang relevan sebelum bilang selesai.
4. Kalau tugas bertabrakan dengan aturan keras, desain tidak menjawab, atau kamu
   ragu: BERHENTI dan tanya. Jangan memilih sendiri, jangan mengarang gaya.
5. Jangan melonggarkan tes supaya hijau.
</cara-kerja>

<laporan>
Bahasa Indonesia, singkat: apa yang berubah (per berkas), artboard rujukan,
hasil analyze/tes, tangkapan golden/galeri bila ada, dan daftar yang BELUM.
</laporan>
```

---------------------------------------------------------------------------
## L0 — Kunci lembar kerja dengan golden (TANPA perubahan tampilan)
```
<tugas>
Kunci tampilan lembar kerja sebelum desain ulang dimulai. PR ini tidak boleh
mengubah tampilan apa pun.
</tugas>
<langkah>
1. Salin docs/desain-ulang/ (dari paket desain) ke repo bila belum ada.
2. Buat test/beku/lembar_kerja_golden_test.dart sesuai BEKU.md §Teknik langkah 1:
   lembar kerja pH (tabel), autoclave (matriks), grid sensor, keypad terbuka,
   calibration_input; tema terang dan gelap; 390×844 dan 1024×768. Pakai data
   contoh/mock yang sudah dipakai tes lain (jangan memanggil jaringan).
   Muat font Inter + IBM Plex Mono di tes agar golden tidak memakai Ahem.
3. Hasilkan golden di OS yang sama dengan CI (cek .github/workflows). Bila harus
   dari CI, buat workflow manual sekali jalan yang mengunggah golden sebagai
   artefak, lalu commit hasilnya.
4. Buat test/beku/berkas_beku_test.dart: SHA-256 tiap berkas BEKU (daftar di
   BEKU.md) dibandingkan dengan tabel di tes. Pesan gagal menyebut berkasnya dan
   menyuruh membaca BEKU.md.
</langkah>
<selesai-jika>
Semua tes lama + tes beku hijau di CI. Tidak ada berkas lib/ yang berubah.
</selesai-jika>
```

## L1 — Token Biru Awan + tema beku
```
<tugas>Ganti token tema ke Biru Awan, sambil membekukan lembar kerja.</tugas>
<baca-dulu>BEKU.md §Teknik 2–5, DESIGN.md, tokens.json, flutter/palet_lab_biru_awan.dart,
flutter/bentuk_ukuran_lab.dart, flutter/beku_lembar_kerja.dart</baca-dulu>
<langkah>
1. lib/core/theme/palet_beku.dart = salinan PERSIS nilai PaletLab hari ini (nilai
   mentah). Tambahkan ke pengecualian token_only_test.
2. lib/core/theme/tema_beku.dart = ThemeData terang/gelap PERSIS seperti sekarang,
   dibangun dari PaletBeku (termasuk semua ThemeExtension).
3. lib/core/theme/beku_lembar_kerja.dart dari flutter/beku_lembar_kerja.dart.
   Bungkus akar LembarKerjaScreen, CalibrationInputScreen, SkemaDinamisScreen,
   TemperaturIndikatorGerbangScreen (satu baris per berkas). Catat di berkas_beku_test.
4. AppColors dialihkan ke PaletBeku.
5. palet_lab.dart → nilai Biru Awan; nama lama (kobalt*) jadi alias sementara.
   Tambah nama baru (primer, primerTua, langit, awan, kabut, …). Tambah
   BentukBiruAwan dan UkuranBiruAwan. JANGAN ubah AppSpacing.
6. sidik_theme.dart / app_theme.dart: komponen Material bertema Biru Awan
   (FilledButton pil 56 primer, OutlinedButton pil 48 tepi #C5D5E6, input radius 16,
   Switch, Chip, Dialog radius 28, BottomSheet radius atas 32). Tema gelap dari tokens.json.
7. Tes kontras: semua pasangan di DESIGN.md + dua pasangan DILARANG sebagai tes negatif.
8. docs/standar-kualitas-desain.md §2–§3 ditulis ulang ke Biru Awan + bagian "Area beku".
</langkah>
<dilarang>Mengubah layar/widget selain baris pembungkus di langkah 3.</dilarang>
<selesai-jika>Golden test/beku/ LOLOS tanpa diperbarui. test/tema dan sakelar_tema_test hijau.</selesai-jika>
```

## L2 — Elemen buatan sendiri (toast, dialog, lembar bawah, banner, keadaan)
```
<tugas>Bangun elemen di ELEMEN.md bagian atas (E2) sebagai komponen baru. Belum ada layar yang memakainya.</tugas>
<baca-dulu>ELEMEN.md, artboard E2 di referensi-html/Elemen.dc.html, flutter/toast_sidik.dart,
lib/widgets/lapisan_kabar_masuk.dart, lib/models/kabar_toast.dart</baca-dulu>
<langkah>
1. lib/widgets/biru_awan/: toast_sidik.dart (selesaikan kerangka), dialog_sidik.dart,
   lembar_bawah_sidik.dart, banner_sidik.dart (tanpa koneksi, pembaruan, peringatan),
   keadaan_sidik.dart (memuat/kosong/galat), README.md daftar komponen.
2. lapisan_kabar_masuk.dart memakai varian kabar navy (perilaku dedup tetap).
3. Tes widget tiap elemen: Semantics, tombol tutup, durasi hilang sendiri, galat
   tidak hilang sendiri, kurangi gerak = tanpa animasi, satu toast sekaligus.
4. Galeri: halaman design_system_screen.dart menampilkan semua elemen (khusus pengembang).
</langkah>
<dilarang>Mengganti SnackBar di layar mana pun pada PR ini. Mengubah widget beku.</dilarang>
```

## L2b — Elemen lanjutan (E6)
```
<tugas>Bangun semua elemen di tabel ELEMEN.md §Elemen lanjutan sebagai komponen baru
di lib/widgets/biru_awan/ (PilihanSidik, TanggalSidik, JamSidik, PenggeserSidik,
MenuAksiSidik, AkordeonSidik, TabGaris, SegarkanSidik, GeserAksi, UnggahBerkas,
KisiFoto, ProgresSidik, SpinnerSidik, KartuQr, BingkaiPindai, BidangTandaTangan,
TeksSalin, TabelSidik, BingkaiPdf, Lencana, TooltipSidik, ChipSaring).</tugas>
<baca-dulu>ELEMEN.md §Elemen lanjutan, referensi-html/Elemen2.dc.html</baca-dulu>
<aturan>
- Boleh satu PR per 4–6 komponen bila terlalu besar; urutkan dari pemakaian terbanyak
  (Pilihan, Segarkan, Spinner/Progres, Tanggal, Unggah/Foto, lalu sisanya).
- Komponen membungkus widget bawaan / paket yang SUDAH ada (image_picker, file_picker,
  pdfrx, camera, mlkit); tanpa paket baru. Logika pemanggilnya tidak berubah.
- Tiap komponen: tes widget (Semantics, ukuran sentuh 48, kurangi gerak, skala huruf 1,3)
  + masuk galeri design_system_screen.
- Belum mengganti pemakaian di layar (itu dikerjakan saat layar disentuh di L7–L11).
</aturan>
```

## L3 — Komponen dasar Biru Awan
```
<tugas>Bangun komponen dasar baru di lib/widgets/biru_awan/.</tugas>
<baca-dulu>LAYAR.md §Ukuran ringkas, POLA.md, Komponen.dc.html, flutter/gerak_bersama.dart</baca-dulu>
<langkah>
Komponen: TombolSidik (utama/tegas/sekunder/teks/bahaya), TombolBulat (44/48/60),
IsianSidik (biasa/fokus/galat/mati, label di atas), StempelSidik (pil 30, nada dari
pemetaan status yang ada), ChipSaring (dengan jumlah), SegmenPil, KartuSidik24,
PanelBaris + BarisMenu64 + BarisDaftar72, UbinIkon, KepalaTab, KepalaAnak,
HeroLangit (dengan motif skala dari aset/motif_skala.svg, BUKAN awan), UbinKpi, GrafikBatang, StepperTegak, GarisWaktu,
AvatarInisial, Lencana, BilahLangkah, KolomCari.
Gerak: lib/core/motion/gerak_bersama.dart (MasukBerurutan, TekanSkala).
Tiap komponen: tes widget (Semantics + aksi ketuk, kurangi gerak, skala huruf 1,3,
lebar 320) dan masuk galeri.
</langkah>
<dilarang>Mengubah app_button.dart, app_text_field.dart, sidik_loader.dart, status_badge.dart (BEKU).</dilarang>
```

## L4 — Gambar alat (57 gambar)
```
<tugas>Pasang semua gambar alat dan VisualAlat dengan jalur cadangan untuk alat baru.</tugas>
<baca-dulu>VISUAL.md (seluruhnya), aset/visual/*.svg (57 berkas), flutter/visual_alat.dart,
referensi-html/VisualAlat.dc.html dan AlatBaru.dc.html, docs/Rekap-Data-Kemampuan-Kalibrasi.md</baca-dulu>
<langkah>
1. Ekspor ke-57 SVG → PNG transparan 1x/2x/3x (240/480/720) ke assets/images/visual/
   dengan rsvg-convert di mesin. Daftarkan di pubspec.yaml. Tanpa paket baru.
2. lib/widgets/biru_awan/visual_alat.dart dari flutter/visual_alat.dart (peta 48 nama,
   alias, kata kunci bentuk, kelompok, umum). Jangan mengubah urutan pencarian.
3. test/visual_alat_cakupan_test.dart sesuai VISUAL.md §Penjaga: gagal bila salah satu
   dari 48 nama tidak mendapat gambar SENDIRI atau berkas tidak ada; cetak daftar nama
   dari fixture yang jatuh ke bentuk/kelompok/umum. Tes tambahan: nama acak → bentuk_umum,
   "Tensimeter Digital" → tensimeter, "Oksimeter" → bentuk_genggam.
</langkah>
```

## L5 — Splash dan Masuk
```
<tugas>Desain ulang splash_screen.dart (E1) dan login_screen.dart + forgot_password (E0).</tugas>
<aturan>Splash tetap timeline SEKALI jalan (tanpa repeat; pumpAndSettle harus selesai),
urutan dan durasi dari ELEMEN.md §Splash. onboarding_screen.dart BEKU.
Login: logika, validasi, dan provider tidak berubah; hanya susunan dan gaya.</aturan>
<selesai-jika>Tes auth dan splash yang ada tetap hijau + tes baru untuk kurangi gerak.</selesai-jika>
```

## L6 — Shell: dock dan laci
```
<tugas>main_shell.dart + floating_nav_bar.dart: dock teknisi (01), dock admin (A1),
laci menu (A3).</tugas>
<aturan>Tab per peran dan isi laci per peran PERSIS seperti switch `peran` sekarang.
Tombol Mulai di dock teknisi membuka alur Mulai kalibrasi yang sudah ada.
desktop_shell.dart belum disentuh (L12).</aturan>
<selesai-jika>adaptive_shell_test dan tes peran hijau; tes baru: tiap butir dock punya
label pembaca layar, laci menampilkan menu yang benar untuk 4 peran.</selesai-jika>
```

## L7 — Layar teknisi (SATU layar per PR, urut)
```
<tugas>Desain ulang layar ‹01 Kalibrasi | 02 Pilih alat | 04 Cek hasil pindai |
05 Ringkasan sebelum kirim | 06 Profil› sesuai LAYAR.md dan referensi-html/‹berkas›.</tugas>
<aturan>
- Data dari provider yang ada. Jangan tambah endpoint.
- 04: tanpa aksi massal; potongan foto asli dari server; kalimat dari pindaiAlasan*.
- 05: gerbang ButirRingkasan tetap di atas; hasil per titik dari PratinjauHitung;
  keputusan null netral; belumDihitung tampil dengan alasan server.
- SnackBar di layar ini → tampilkanToast.
- Lembar kerja (03) TIDAK disentuh.
</aturan>
<selesai-jika>Tes alur lama hijau (alur_kirim_ke_admin_test, alur_profil_lembar_kerja_test,
kamera_pindai_desain_test, …) + tes keadaan baru (memuat/kosong/galat/tanpa koneksi).
Golden beku lolos.</selesai-jika>
```

## L8 — Layar admin (SATU layar per PR, urut)
```
<tugas>Desain ulang ‹A1 Beranda admin | A4 Antrean approval | A5 Periksa sesi |
A6 Alur kerja | A7 Penugasan | A8 Jadwal kalibrasi ulang›.</tugas>
<aturan>
- A1: viewer melihat versi tanpa aksi + menuCatatanViewer.
- A5: tabel_perhitungan.dart BEKU (hanya dibingkai). Alur Periksa → Setujui/Revisi tidak berubah.
  Pemisahan wewenang ditampilkan sebagai catatan, penolakan server tetap ditangani seperti sekarang.
- A8: dialog_ubah_jatuh_tempo jadi LembarBawahSidik.
- SnackBar → tampilkanToast; dialog → DialogSidik.
</aturan>
<selesai-jika>approve_peringatan_test dan tes admin lain hijau; golden beku lolos.</selesai-jika>
```

## L9 — Super admin
```
<tugas>Desain ulang beranda_super_admin.dart (A2).</tugas>
<aturan>Urutan bagian dan sumber angka tetap seperti komentar di berkasnya (yang
menunggu dia → paket berjalan → perlu dilihat). Tiap bagian memuat/galat sendiri.</aturan>
```

## L10 — Master Data (SATU layar per PR)
```
<tugas>Desain ulang ‹M1 Kelola lab | M2 Standar acuan | M3 Buat akun teknisi |
M4 Versi data acuan (alur_versi + paket_alur) | M5 Riwayat perubahan›.</tugas>
<aturan>M4: tombol tanpa hak (hak_alur_acuan) tidak ditampilkan. Status dari acuanStatus*.
Simulasi/sahkan/tolak memakai alur yang ada.</aturan>
```

## L11 — Sapu POLA (satu kelompok per PR)
```
<tugas>Terapkan POLA.md ke berkas berstatus POLA di PETA-LAYAR.md, kelompok:
‹Daftar | Formulir | Detail | Riwayat | Dialog & lembar bawah | Banner & keadaan›.</tugas>
<langkah>
1. Tulis tabel: berkas → pola → komponen yang dipakai. Tunggu "lanjut".
2. Ganti SnackBar → tampilkanToast di berkas yang disentuh.
3. Berhenti memakai neu.dart, glass_surface, liquid_glass, kartu_gradien, panorama_kartu
   di berkas yang disentuh.
</langkah>
<dilarang>Menyentuh berkas BEKU atau TOKEN di luar kelompok ini.</dilarang>
```

## L12 — Layar lebar
```
<tugas>desktop_shell.dart + master_detail_pane.dart sesuai D1 (navigasi 248, daftar 360,
detail). Berlaku untuk Antrean, Riwayat, Alat, Arsip. Lembar kerja tetap BEKU di semua lebar.</tugas>
```

## L13 — Bersih-bersih dan pasang patokan UI
```
<langkah>
1. Hapus alias kobalt* dan widget yang tidak dipakai lagi (neu/glass/gradien bila
   sudah nol pemakaian di luar berkas beku). Turunkan token_only_baseline.json.
2. Pasang skill: salin docs/desain-ulang/skill/sidik-ui/ ke .claude/skills/sidik-ui/.
3. Tambah satu baris di AGENTS.md: "UI: wajib ikuti .claude/skills/sidik-ui/SKILL.md
   dan docs/desain-ulang/; berkas BEKU tidak boleh diubah."
4. Perbarui PETA-LAYAR.md: status akhir tiap berkas.
</langkah>
<dilarang>Perubahan tampilan.</dilarang>
```

=============================================================================
# B. App PELANGGAN — `sidik-pelanggan-mobile`
=============================================================================

## Pembuka sesi
```
Kamu adalah engineer Flutter senior yang mengerjakan DESAIN ULANG TAMPILAN app
SIDIK Pelanggan ke arah "Bento Lab". HANYA UI: tanpa perubahan API, logika,
provider, model, atau struktur navigasi.

<baca-dulu>
1. AGENTS.md, docs/HANDOFF-CODEX.md
2. docs/standar-kualitas-desain.md, lib/core/tema/README.md, lib/widgets/README.md
3. docs/desain-ulang/README.md, PETA-LAYAR.md, DESIGN.md, KOMPONEN.md, UKURAN.md,
   GERAK.md, LAYAR.md, ELEMEN.md, VISUAL.md, tokens.json
4. test/tema/* (token_only, kontras, tema_sidik, anti_slop), test/guard_tulis_test.dart
5. .claude/skills/sidik-ui-pelanggan/SKILL.md (bila sudah terpasang)
</baca-dulu>

<aturan-keras>
- App tetap baca-saja; guard_tulis_test tidak dilonggarkan.
- Tanpa paket/font baru. Nilai gaya hanya lewat lib/core/tema.
- Status ikon + kata; istilah dari pemetaan_status.dart.
- Area pratinjau PDF tidak diubah (cermin PDF).
- Branch → PR → CI hijau. Jangan push ke main. Jangan jalankan emulator.
</aturan-keras>

<cara-kerja>Sama dengan app Lab: ringkas 10 poin → rencana → tunggu "lanjut" →
kerjakan → analyze + tes → laporan. Ragu = berhenti dan tanya.</cara-kerja>
```

## P1 — Token Bento Lab
```
Langkah 1 di docs/desain-ulang/README.md. Ubah palet_sidik, warna_sidik, bentuk,
ukuran, spasi (sisi 20→16), tipografi (tambah 64/800), tema_sidik. Perbarui tes
tema (izin ukuran 64, pasangan kontras baru — hitung) dan docs/standar-kualitas-desain.md §3–§4.
JANGAN ubah layar/widget. Selesai: test/tema hijau.
```

## P2 — Komponen Bento
```
Komponen BARU di KOMPONEN.md (tombol_bulat, saringan_pil, segmen_pil, ubin_alat,
ubin_ringkas, ubin_menu) + ubah gaya Stempel (pil 30), PanelSidik (28), TombolSidik,
KolomCariUtuh. lib/core/motion/gerak_bento.dart. Tes widget + galeri render.
```

## P3 — Elemen, gambar alat, splash, masuk
```
1. Elemen ELEMEN.md dengan palet Bento (aksi navy, kosong = ubin kuning + visual):
   toast_sidik, dialog_sidik, lembar_bawah_sidik, banner_sidik, keadaan_sidik. Ganti
   banner offline/pembaruan yang ada ke bentuk baru (perilaku tetap).
2. Gambar alat: ekspor aset/visual/*.svg ke PNG 1x/2x/3x, VisualAlat (VISUAL.md).
3. Layar auth (sambutan, masuk, lupa sandi, terima undangan) mengikuti susunan E0
   dengan palet Bento. Logika auth tidak berubah.
Tes widget untuk semua elemen.
```

## P4 — Dock
```
NavigasiUtama di HP → dock navy melayang (KOMPONEN.md §Dock). Rel ≥ 600 dp tetap.
```

## P5 — Layar (SATU per PR, urut)
```
Layar ‹Beranda | Alat | Sertifikat | Akun | Anggota | Paket› sesuai LAYAR.md +
referensi-html. Data dari provider yang ada. SnackBar → tampilkanToast di layar ini.
Turunkan angka ratchet anti_slop untuk berkas yang diubah. Empat keadaan wajib ada.
```

## P6 — Sapu POLA
```
Berkas POLA di PETA-LAYAR.md (detail alat, arsip sertifikat, detail sertifikat,
bantuan, ganti sandi, preferensi notifikasi, detail paket, notifikasi). Tabel
rencana dulu, satu kelompok per PR.
```

## P7 — Bersih-bersih + patokan UI
```
Hapus widget lama yang tidak dipakai, turunkan baseline ratchet, salin
docs/desain-ulang/skill/sidik-ui-pelanggan/ ke .claude/skills/, tambah baris di AGENTS.md.
```

## G1 — Gambar untuk alat baru (dipakai kapan pun lab menambah alat)
```
<tugas>Gambar visual untuk alat: ‹nama alat› (kelompok: ‹kelompok›, foto rujukan
terlampir bila ada).</tugas>
<baca-dulu>docs/desain-ulang/VISUAL.md §Menggambar alat baru, tiga SVG terdekat di
docs/desain-ulang/aset/visual/ sebagai contoh gaya.</baca-dulu>
<langkah>
1. Tulis SVG 240 × 240 baru di docs/desain-ulang/aset/visual/‹kunci›.svg memakai <defs>
   yang sama. Tanpa merek/teks merek; angka layar = nilai wajar alat itu.
2. Render ke lembar kontak bersama 5 gambar lain (rsvg-convert + montage) dan kirim
   gambarnya ke aku untuk dicek SEBELUM lanjut.
3. Setelah aku setuju: ekspor PNG 1x/2x/3x, tambah satu baris di PetaVisualAlat.perAlat
   (+ alias bila ejaannya beragam), jalankan visual_alat_cakupan_test.
</langkah>
<dilarang>Mengubah layar, mengubah urutan pencarian, foto stok, gambar dari internet.</dilarang>
```

=============================================================================
# C. API — `sidik-calibration-api` (HANYA MEMBACA, opsional)
=============================================================================

## A0 — Cek kontrak data
```
Hanya membaca. Jangan ubah berkas, jangan jalankan suite tes, jangan deploy.
Pastikan field ini ada dan laporkan file:baris buktinya:
- POST /api/calibrations/preview: titik[] (rata_rata, koreksi, ketidakpastian_diperluas,
  toleransi, keputusan boleh null) + belum_dihitung[] (alasan).
- Antrean approval: penanda sesi yang punya titik FAIL + nama teknisi.
- Dashboard admin & beranda super admin: angka total alat, lewat jadwal, draft,
  sertifikat bulan ini, tren 7 hari, paket berjalan + progres per alat.
- Pindai lembar: per sel crop foto, teks terbaca, tingkat, alasan.
Yang tidak ada: JANGAN ditambahkan. Tulis permintaan di
sidik-calibration-mobile/docs/permintaan-backend-‹tanggal›.md dan beri tahu aku;
layar terkait menampilkan bagian itu kosong/tersembunyi sampai backend siap.
```

=============================================================================
# D. Untuk UI BARU di masa depan (setelah skill terpasang)
=============================================================================

```
Buat tampilan untuk ‹fitur›. Ikuti .claude/skills/‹sidik-ui | sidik-ui-pelanggan›/SKILL.md
dan docs/desain-ulang/. Sebelum ngoding, kirim:
1. Status berkas yang disentuh menurut PETA-LAYAR.md (BEKU = berhenti).
2. Pola dari POLA.md / LAYAR.md yang dipakai, dan komponen yang sudah ada yang
   dipakai ulang. Komponen baru hanya bila tidak ada padanannya — sebutkan alasannya.
3. Teks baru (kunci l10n) dan keadaan memuat/kosong/galat/tanpa koneksi.
4. Gambar alat yang dipakai (VisualAlat) atau alat baru yang perlu digambar (VISUAL.md).
Tunggu "lanjut". Selesai = analyze bersih, tes hijau, golden beku lolos.
```

=============================================================================
# E. Kalau Claude Code melenceng (tempel kalimat ini)
=============================================================================
- Menyentuh lembar kerja → "Berkas itu BEKU. Batalkan perubahannya, baca BEKU.md."
- Golden beku gagal → "Golden tidak boleh diperbarui. Cari yang bocor ke tema beku."
- Mengarang warna/ukuran → "Ambil dari tokens.json/token Dart, sebutkan namanya."
- Mau menghitung di HP → "Baca lib/models/pratinjau_hitung.dart baris 12: angka dari server."
- Mengubah banyak layar sekaligus → "Satu layar per PR. Kembalikan sisanya."
- Melonggarkan tes → "Tes tidak boleh dilonggarkan. Perbaiki kodenya atau berhenti dan jelaskan."
- Mengubah navigasi/peran → "Hanya UI. Struktur tab dan laci tetap seperti main_shell.dart."
- Menambah paket/font → "Tanpa paket dan font baru. Cari cara dengan yang sudah ada."

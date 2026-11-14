# LAYAR — susunan, ukuran, sumber data, berkas

Bagian 1: teknisi. Bagian 2: admin (Master Data) dan super admin. Bagian 3: layar lebar dan masuk.
Navigasi TIDAK berubah strukturnya: tab dan isi laci per peran tetap seperti `main_shell.dart` hari ini; hanya tampilannya.

Lebar rujukan 390, margin 16, jarak antar-blok 12. Mockup: `referensi-html/`.

## 01 Kalibrasi (beranda teknisi) — `lib/screens/teknisi/kalibrasi_teknisi_screen.dart`
- Kepala 48: logo PT Sidik (30 × 42, `assets/images/logo_pt_sidik.png`) + "SIDIK Lab" 16/800
  + "Kalibrasi terakreditasi KAN" 12 + tombol lonceng 48 putih, lencana koral jumlah belum dibaca.
- Sapaan 14 tinta2 + kalimat 28/34·800: "{n} draf belum dikirim. {m} menunggu approval."
  (bagian kedua tinta2). Angka dari provider yang sudah ada; bagian 0 tidak ditulis.
- Hero langit 212, radius 28, padding 20: "Kalibrasi baru" 13/700, judul 24/28·800 maks 190,
  tombol navy 48 "Mulai kalibrasi" + bulat putih 34 panah; visual 188 kanan bawah.
- Draf: judul 17 + jumlah; baris geser mendatar kartu 196 × 148 radius 24 (nomor mono 12,
  nama 16/20·800 maks 2 baris, PT 12 satu baris terpotong, visual 92). Sumber: draf server +
  `drafLokal*` (draf lokal tampil dengan stempel "Belum tersinkron").
- Terkirim terakhir: panel putih radius 24, baris 72: ubin visual 48 kabut, nama 16/800,
  nomor mono 12, stempel di kanan. Ketuk → detail sesi.
- Dock teknisi (`floating_nav_bar.dart`): putih radius 40, padding 8, jarak 10;
  Kalibrasi (pil kabut 52, ikon + label 14/800 primerTua) · Mulai (bulat 60 primer,
  bayangan primer 40 %) · Profil (bulat 52). Melayang 16 dp di atas tepi sistem.

## 02 Pilih alat — `category_picker_screen.dart` + `instrument_picker_screen.dart`
Satu layar: chip kelompok (44, aktif navy) di atas grid 2 kolom ubin alat 164
(radius 24, terpilih: kabut + garis primer 2 + centang bulat 32 primer).
Bilah langkah 4 segmen (tinggi 6, radius 3; aktif primer) + label 12.
Tombol utama "Lanjut dengan {alat}". Kelompok dan alat dari data profil/kategori
yang sudah dipakai layar lama; JANGAN dikeraskan di kode.

## 03 Lembar kerja — BEKU
Tidak diubah. Lihat `BEKU.md`. Artboard 03 hanya penanda.

## 04 Cek hasil pindai — `foto_review_screen.dart` (judul `pindaiReviewJudul`)
Hero langit: titik + tiga pil hitungan (dibaca putih, perlu dicek kuning,
tidak terbaca koral) dari `pindaiRingkasan`, kalimat `pindaiCatatanKuning`.
Satu kartu per sel: potongan foto ASLI 92 × 64 radius 12 (dari crop server,
bukan gambar ulang) + "Repeat n" + angka terbaca mono 20 + alasan
`pindaiAlasan*` + tombol "Pakai" 44 primer, atau "Ketik" koral bila tak terbaca.
Tanpa tombol pakai-semua. Bawah: "Kembali ke lembar kerja" + hitungan "x/n".

## 05 Ringkasan sebelum kirim — `ringkasan_sebelum_kirim.dart` + dialog
Tetap jalankan gerbang `ButirRingkasan` (menahan/peringatan) di ATAS daftar
hasil. Kartu identitas (nomor, alat, PT, pil "n titik", "n pembacaan", "k = 2").
Per titik dari `PratinjauHitung.titik`: koreksi, U (`ketidakpastianDiperluas`),
|kor| + U, stempel dari `keputusan`; batang (tinggi 10) dengan garis toleransi
(`toleransi`). `keputusan == null` → stempel netral, tanpa batang.
`belumDihitung` → kartu kuning "Belum dihitung" + alasan server.
Tombol utama "Kirim untuk approval" + "Simpan draf".

## A4 Antrean approval — `lib/screens/admin/antrean_approval_screen.dart`
Ubin navy radius 28: menunggu / ada FAIL / teknisi (36·800). Chip saring
`antreanSemuaPt` dll. Kartu per sesi radius 24: visual 52 kabut, nama, nomor,
stempel "1 FAIL" bila ada, PT + `antreanOleh`, tombol "Periksa" 44 primer.
Layar anak (dibuka dari laci/beranda): kepala kembali, tanpa dock. Tombol "Periksa" → A5.

## 06 Profil — `lib/screens/profile/profile_screen.dart`
Hero langit 204: avatar 84 putih (inisial primerTua), pil peran navy, nama
24·800, organisasi. Kartu akreditasi 76: logo, "Akreditasi KAN" + nomor
mono 16, pil "ISO/IEC 17025". Panel menu baris 64 (ikon 44 berwarna). "Keluar"
navy 56.

## Ukuran ringkas
Tombol utama 56 · tegas 48 · sekunder 48 (garis #C5D5E6) · bulat 44/48/60 ·
cari 56 · chip 44 · stempel 30 · sel 72 · tuts 56 · baris 72 · menu 64 ·
kartu draf 196 × 148 · ubin alat 164 · hero 212 · dock 52/60 (teknisi), 48 (admin).
Tinggi kartu = minimum (`ConstrainedBox`), tumbuh bila huruf sistem diperbesar.
≥ 700 dp (`ambangDuaKolom`): lihat D1. Lembar kerja tetap BEKU di semua lebar.

---------------------------------------------------------------------------
# Bagian 2 — Admin (Master Data) dan Super Admin

Peran dari `UserRole`: admin = Master Data; superAdmin = semua aksi admin + teknisi
(sesi isiannya sendiri tetap disetujui orang lain: server 422 `pemisahan_wewenang`);
viewer = baca saja (beranda A1 tanpa aksi + kalimat `menuCatatanViewer`).
Tab admin/super admin TETAP: Beranda, Alat, Riwayat, Arsip, Profil. Sisanya dari laci.

## A1 Beranda admin — `dashboard/dashboard_screen.dart` (+ `stat_card`, `work_chart`, `technician_pulse_panel`)
Kepala tab (peran "Admin, Master Data", lonceng, tombol menu navy 48 → laci).
Kalimat 28/34: "{n} lembar kerja menunggu approval. {m} alat lewat jadwal."
Hero langit min 196: "Antrean approval", angka 56/800, "menunggu, {f} ada FAIL",
tombol navy "Buka antrean"; visual spektro 170. Ubin KPI 2 × 2 (min 112, radius 24,
angka 36/800): Total alat (putih, "se-lab"), Lewat jadwal (koral), Draft kalibrasi
(kabut), Sertifikat bulan ini (hijau, tren). Grafik pekerjaan: 7 batang radius 10,
hari ini primer, lainnya awan, angka mono 12 di atas, tren di bawah (`dashTrend*`).
Aksi cepat 2 × 2: Mulai kalibrasi (primer), Tambah alat, Tugaskan, Jadwal ulang.
Semua angka dari provider yang sama dengan layar tujuannya.

## A2 Beranda super admin — `dashboard/beranda_super_admin.dart`
Urutan tetap seperti kode: yang menunggu dia → paket berjalan → yang perlu dilihat.
Dua ubin 196: Antrean approval (langit, angka 56, catatan pemisahan wewenang 12)
dan Mulai kalibrasi (navy, tombol bulat 44 primer, visual pH). Paket berjalan:
panel baris (nama 16/800, PT + jumlah + target 13, tik progres 8 per alat,
"n dari m alat selesai"). Perlu dilihat: kartu 76 berwarna sesuai nada
(koral tipis jatuh tempo, kuning tipis standar segera habis, putih versi acuan diajukan).
Tiap bagian memuat/galat sendiri (aturan lama).

## A3 Laci menu — `shell/main_shell.dart`
Panel kiri 320, radius kanan 32, latar redup navy 42 %, masuk geser 280 ms.
Kepala: avatar 52 langit + nama + stempel peran (kabut) + tutup 44.
Seksi dari kode (`menuKerjaHarian`, `menuArsip`, `menuPengaturan`), label 12/700 tinta2.
Butir 52 radius 26: ikon 22 + label 15/600; aktif kabut + primerTua 800;
lencana koral untuk Antrean, Draf, Jadwal, Notifikasi. Isi per peran PERSIS dari switch `peran` di kode.

## A5 Periksa sesi — `admin/perhitungan_screen.dart` + widgets
Kepala anak (judul + nomor mono). Kartu identitas (data_administrasi): visual 132,
alat 22/800, PT, teknisi, pil kondisi (blok_kondisi) kabut. Tabel PERHITUNGAN: BEKU,
hanya dibingkai kartu putih. Temuan (panel_temuan): baris dengan stempel Galat
(koral) / Peringatan (kuning) / Info (awan) + kalimat validator apa adanya.
Catatan pemisahan wewenang (kabut, ikon perisai) bila sesi milik sendiri.
Bilah aksi bawah: Periksa ulang (sekunder) + Minta revisi (bahaya) + Setujui &
terbitkan (primer penuh). Dialog setujui = DialogSidik.

## A6 Alur kerja — `alur/alur_kerja_screen.dart`
Kalimat penjelas → cari → kartu sesi (nomor, alat, PT, visual) berisi stepper
tegak 4 tahap (`alurTahap*`): selesai = bulat 32 primer + centang; sekarang =
primer dengan cincin awan 4 + stempel "Lagi di sini"; belum = tepi 2. SATU tombol
utama = langkah berikutnya (aturan layar ini).

## A7 Penugasan — `penugasan/penugasan_screen.dart` (+ buat = POLA Formulir)
Kepala anak + tombol pil "Tugaskan" 44 primer. Chip Berjalan/Selesai/Semua.
Kartu: judul 16/800 (maks 230), tumpukan avatar 36 (ketua pertama), "Ketua: …",
batang progres 10 + "n dari m selesai" + "Target …", stempel "Belum dibuka" atau
"Dibuka {tanggal}"; visual jenis alat 88 di pojok.

## A8 Jadwal kalibrasi ulang — `jatuh_tempo/layar_jatuh_tempo.dart`
Chip zona (Lewat jadwal koral, ≤30, 31–60, 61–90) → panel baris 72: visual 48,
alat, PT, kanan: hari terlewat mono 18 merah tua + tanggal 12. Ketuk baris →
lembar bawah "Jadwalkan pengambilan" (`jadwalPenjelasan`, Tanggal + Jam 2 kolom,
Lokasi opsional, Simpan jadwal) = LembarBawahSidik.

## M1 Kelola lab — `settings/kelola_lab_screen.dart`
Ubin navy (Master Data + nama organisasi + logo di plat putih). Empat grup dari
kode (`kelolaGrup*`): panel putih berisi baris menu 64 (ubin ikon 44 berwarna
bergilir kabut/hijau/awan/kuning/koral tipis, judul 16/700, sub 13 dari `prof*Sub`).

## M2 Standar acuan — `settings/standard_list_screen.dart` (pola semua daftar data master)
Kepala anak + tambah bulat 48 primer. Cari. Chip Semua/Segera habis/Berakhir.
Banner kuning dari `banner_status_standar`. Kartu 104: visual 56, nama 16/800,
nomor seri mono 12, "Sertifikat sampai …", stempel sisa hari (kuning) atau Berlaku (hijau).

## M3 Buat akun teknisi — `settings/buat_teknisi_screen.dart` (pola semua formulir)
Lihat POLA.md §Formulir. Peran = segmen pil (Teknisi/Admin/Viewer sesuai yang
diizinkan server). Organisasi = isian mati.

## M4 Versi data acuan — `data_acuan/alur_versi_acuan_screen.dart` + `paket_alur_acuan_screen.dart`
Hero langit "Aktif sekarang" + versi mono 30 + sejak/oleh. Riwayat versi: kartu
per versi (versi mono 18 + stempel status `acuanStatus*`: Diajukan awan, Draf
netral, Aktif hijau, Pensiun netral, Ditolak koral, Ditarik/Dibuang netral) +
kalimat. Versi Diajukan: Simulasikan (sekunder) · Sahkan (primer) · Tolak (teks).
Hak per tombol dari `hak_alur_acuan` (tombol tanpa hak tidak tampil, bukan mati).

## M5 Riwayat perubahan — `audit/audit_log_screen.dart`
Tombol saring bulat 48. Chip jenis. Panel garis waktu (POLA §Riwayat).

---------------------------------------------------------------------------
# Bagian 3 — Layar lebar, masuk, splash

## D1 Desktop/tablet ≥ 700 — `shell/desktop_shell.dart`
Tiga kolom: navigasi 248 putih (logo, seksi laci yang sama, butir 44, aktif kabut)
· daftar 360 (judul 24/800, cari, kartu antrean, terpilih kabut + tepi primer 2)
· detail (identitas + pil kondisi di satu baris, tabel BEKU kiri 1,4 fr, temuan
kanan 1 fr, bilah aksi kanan bawah). Berlaku sama untuk Riwayat, Alat, Arsip
(daftar kiri, detail kanan) memakai `master_detail_pane.dart`.

## E0 Masuk, E1 Splash
Lihat `ELEMEN.md`.

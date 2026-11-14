---
name: sidik-ui
description: Patokan UI app SIDIK Lab (Biru Awan). Pakai SETIAP kali membuat, mengubah, atau meninjau tampilan Flutter di sidik-calibration-mobile — layar baru, widget, dialog, toast, keadaan kosong/galat, warna, ukuran, animasi, ikon, atau gambar alat.
---

# Patokan UI SIDIK Lab — "Biru Awan"

Rujukan lengkap: `docs/desain-ulang/` (README, DESIGN, LAYAR, POLA, ELEMEN,
VISUAL, BEKU, PETA-LAYAR, tokens.json, referensi-html/). Skill ini ringkasannya.
Kalau ada yang tidak tercakup di sini maupun di dokumen itu: tanya pemilik,
jangan mengarang gaya baru.

## 0. Sebelum menyentuh UI
1. Cek `docs/desain-ulang/PETA-LAYAR.md`: status berkas yang akan disentuh.
   BEKU = jangan diubah sama sekali (lihat BEKU.md). TOKEN = tata letak tetap.
2. Cari komponen yang sudah ada di `lib/widgets/biru_awan/` sebelum membuat baru.
3. Semua warna/ukuran/jarak/sudut lewat token (`PaletBiruAwan`, `BentukBiruAwan`,
   `UkuranBiruAwan`, `AppMotion`). Tidak ada `Color(0x…)`, angka jarak, atau
   `fontSize` mentah di layar. `token_only_test` menjaganya.

## 1. Warna
Primer #1C6FC4 (aksi utama, fokus) · primer tua #0F4F94 (teks biru) · langit
#5BB4F5 (hero, HANYA teks navy) · awan #A9D8FB · kabut #E4F2FD (terpilih, sel,
ubin ikon) · latar #F3F7FB · kertas putih · navy #0B2545 (tinta, tombol tegas) ·
tinta2 #4A5D78 · status: hijau #BFE6C4 lulus, kuning #F6D36B perlu dicek/segera,
koral #F2957A galat/ditolak, awan = menunggu, netral #EEF2F6.
DILARANG: teks putih di atas langit; primer sebagai teks di atas kabut; gradien di
UI (gradien hanya di dalam gambar alat); ungu; lebih dari satu ubin langit per
layar. Kontras teks ≥ 4,5:1, ikon/garis penting ≥ 3:1 — hitung, jangan tebak.

## 1b. Hiasan
Satu-satunya hiasan = motif skala kalibrasi (busur tik + jarum + penggaris), satu per hero, diam.
Tidak ada gambar awan, bintang, gelombang, gradien, atau ilustrasi stok. "Biru Awan" = nama warna.

## 2. Huruf
Inter untuk semua UI, IBM Plex Mono untuk angka ukur dan nomor (KAL/…, seri).
28/34·800 judul tab · 20/26·800 judul anak · 22/28·800 nama alat · 17/24·800
bagian · 16/24·700 label · 14/20·400 keterangan · 12/16·700 stempel (minimum 12).
Koma desimal Indonesia. Tanpa HURUF BESAR untuk label, tanpa pemisah "A · B · C".

## 3. Bentuk dan ukuran
Pil untuk tombol, stempel, cari, chip · kartu 24 · hero/panel besar 28 · dock 40 ·
isian 16 · ubin ikon 16 (persegi) atau bulat. Tombol utama 56 (satu per layar),
tegas/sekunder 48, bulat 44/48/60; area sentuh minimum 48; baris daftar 72,
baris menu 64; stempel 30. Tinggi kartu = minimum, boleh tumbuh (skala huruf).

## 4. Susunan layar
Kepala tab (logo + peran + lonceng + menu) atau kepala anak (kembali bulat 48 +
judul 20). Margin 16, jarak 12/24. Satu hero langit maksimal per layar. Daftar,
formulir, detail, riwayat: ikuti POLA.md persis. Dock hanya di layar tab;
struktur tab dan laci per peran TIDAK diubah.

## 5. Status
Selalu ikon + kata (stempel). Normal diam, pengecualian bersuara. Istilah dari
pemetaan yang ada. FAIL = "Tidak memenuhi toleransi", stempel navy pekat, tidak
dilunakkan. `keputusan == null` = "Tanpa PASS/FAIL" netral, TIDAK PERNAH hijau.

## 6. Angka dan data (aturan keras repo)
Mobile tidak menghitung angka ukur: rata-rata, koreksi, U, toleransi, PASS/FAIL
dari server (`PratinjauHitung`, detail sesi). `belumDihitung` wajib tampil.
OCR: saran per sel, tanpa "pakai semua", tanpa hijau palsu, sel kosong tetap kosong.

## 7. Umpan balik dan keadaan
Semua elemen ada di ELEMEN.md (E2) dan §Elemen lanjutan (E6): pilihan, tanggal, waktu,
menu titik tiga, akordeon, tab, tarik segarkan, geser aksi, unggah, foto, QR, pindai,
tanda tangan, salin, tabel data, pratinjau PDF. Jangan memakai widget bawaan polos
bila padanannya ada.
Toast = `tampilkanToast` (bukan SnackBar), dialog = `DialogSidik`, lembar bawah =
`LembarBawahSidik`, banner menempel di bawah kepala. Setiap layar data punya 4
keadaan: memuat (kerangka), kosong (ubin langit + motif skala + 1 aksi), galat (koral
tipis + Coba lagi), tanpa koneksi (data terakhir + banner navy).

## 8. Gerak
`AppMotion` saja: masuk 240 ms naik 12 dp berurutan 35 ms (maks 210, maks 6
butir), visual 0,92→1, tekan 0,97 120 ms, pindah halaman 280 ms. Tanpa gerak berulang (kecuali kerangka/spinner memuat), tanpa
pegas memantul, angka ukur tidak dianimasikan. Selalu lewat `AppMotion.hormati`.

## 9. Gambar alat dan ikon
`VisualAlat(nama:, kelompok:, ukuran:)`; peta di satu berkas; tidak pernah kosong
(nama → alias → kata kunci bentuk → kelompok → umum). Alat baru tanpa gambar boleh
memakai gambar bentuk; gambar sendiri ditambahkan lewat prompt G1 sesuai VISUAL.md.
Jangan pernah foto stok, gambar bermerek, atau ikon pengganti. Ikon:
Material Icons outlined/rounded yang sudah dipakai, 20–24, tanpa emoji.

## 10. Bahasa
Pakai `lib/l10n/app_id.arb` (nada santai yang sudah ada). Teks baru = kunci l10n baru.

## 11. Aksesibilitas
`Semantics` label + aksi ketuk pada komponen yang bisa diketuk; tombol ikon
punya tooltip; gambar dekoratif `ExcludeSemantics`; uji 1,3× skala huruf dan 320 dp.

## 12. Selesai jika
`flutter analyze` bersih · `flutter test` hijau (termasuk `test/tema/` dan golden
`test/beku/`) · tes widget untuk komponen baru (Semantics + kurangi gerak) ·
PR menyebut layar yang berubah, rujukan artboard, dan yang belum dikerjakan.

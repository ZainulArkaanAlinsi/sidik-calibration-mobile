# DESIGN — Biru Awan

## Warna (terang)
| Token | Hex | Pakai | Kontras |
|---|---|---|---|
| primer | #1C6FC4 | tombol utama, fokus, sel aktif, tombol Mulai | putih 5,10 |
| primerTua | #0F4F94 | teks/ikon biru, butir dock aktif, tautan | di kabut 7,18 |
| langit | #5BB4F5 | hero, ubin sorot | navy 6,81 — putih DILARANG (2,26) |
| awan | #A9D8FB | stempel "Menunggu approval" | navy 10,19 |
| kabut | #E4F2FD | sel terisi, ubin terpilih, butir dock aktif, latar ikon | navy 13,50 |
| latar | #F3F7FB | halaman | navy 14,29 |
| kertas | #FFFFFF | kartu, panel, dock | — |
| navy (tinta) | #0B2545 | teks, tombol tegas, ubin ringkasan admin | putih 15,39 |
| tinta2 | #4A5D78 | keterangan | di kertas 6,71, di kabut 5,89 |
| hijau / kuning / koral | #BFE6C4 / #F6D36B / #F2957A | lulus·disetujui / perlu dicek·revisi / ditolak·tak terbaca | navy 11,23 / 10,59 / 6,85 |

Primer `#1C6FC4` sebagai TEKS di atas kabut = 4,47 (gagal tipis): pakai
primerTua. Tema gelap: lihat `tokens.json` → `gelap` (primer gelap #7CC4F6
dengan teks gelap di atasnya, 9,58).

Motif hiasan = **bagian alat kalibrasi**: busur skala dengan tik dan jarum + garis penggaris bertik, putih 45–55 % (di atas langit) atau langit 25–35 % (di atas latar). Hanya di hero (beranda, profil, cek pindai, masuk, splash), satu motif per hero, diam. Ini satu-satunya hiasan. "Biru Awan" hanya nama palet (warna biru langit cerah); TIDAK ADA gambar awan di mana pun. SVG motif: `aset/motif_skala.svg`.

## Huruf
Inter untuk UI; IBM Plex Mono untuk angka ukur dan nomor (aturan lama tetap).
Skala: 28/34·800 judul layar, 20/26·800 judul anak, 22/28·800 nama alat,
17/24·800 bagian, 16/24·700 label, 14/20·400 keterangan, 12/16·700 stempel.
Mono: 22·700 hasil, 18·700 nilai di kartu hasil, 12·600 nomor KAL/....
Koma desimal Indonesia di semua angka tampil.

## Sudut
isian 16 · kartu 24 · hero/segmen 28 · dock 40 · pil untuk
tombol, stempel, cari, chip.

## Gerak
Sama dengan Pelanggan (`AppMotion` ada di repo ini juga): masuk 240 ms naik
12 dp berurutan 35 ms (maks 210); visual 0,92→1 setelah ubinnya; tekan 0,97
120 ms; batang |kor|+U tumbuh 240 ms. Angka ukur TIDAK dianimasikan (tidak menghitung naik,
tidak berkedip): nilai ukur harus terbaca stabil. Tanpa gerak berulang.
Helper siap pakai: `flutter/gerak_bersama.dart` (impor `app_motion.dart`
yang sudah ada di `lib/core/motion/`).


> Lembar kerja (sel, keypad, tabel) BEKU: tidak memakai token Biru Awan, lihat `BEKU.md`.

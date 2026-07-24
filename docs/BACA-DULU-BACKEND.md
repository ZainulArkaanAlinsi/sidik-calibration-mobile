# Status Backend ↔ Mobile

*Dicek ulang 22 Juli 2026 sore ke `asmo-api` (`routes/api.php`, `git log`,
`BALASAN-FRONTEND-fase2.md`). Halaman ini nandain siapa yang lagi kena
giliran — dulu isinya daftar permintaan ke backend, sekarang kebalik.*

---

## Backend: SELESAI SEMUA. Nggak ada yang perlu diminta lagi.

Dua belas permintaan di `permintaan-endpoint.md` §5 dan
`permintaan-endpoint-fase-2.md` **udah dikerjain semua**, plus CRUD folder
arsip yang duluan jadi.

| # | Permintaan | Endpoint / field |
|---|---|---|
| 1 | QR verifikasi | `qr_token` + `qr_url` di objek sertifikat |
| 2 | Nomor order & tanggal terima | ikut di detail sesi |
| 3 | Technician ID | `employee_id` di objek teknisi |
| 4 | Identitas alat + pelanggan | `equipment` digemukin |
| 5 | Standar acuan lengkap | `merk_type`, `tertelusur_ke`, `serial_number` |
| 6 | Logo lab | `logo_url` + `POST /organization/logo` |
| 7 | Notifikasi ke admin | `GET /notifications`, `POST /notifications/{id}/baca` |
| 8 | Hitung sambil ngetik | `POST /calibrations/preview` |
| 9 | Penanda tangan | atribut `department`, **bukan** role keempat |
| 10 | Kirim sertifikat | `POST /certificates/{id}/kirim-email` |
| 11 | Ruangan di sesi | `room_id` |
| 12 | Laporan | `GET /laporan/kalibrasi` + `/export` (PDF & CSV) |
| — | Matriks peran | `GET /me/permissions` + `MATRIKS-PERAN.md` |
| — | CRUD folder arsip | `FolderController`, 24 test |

---

## Dua jawaban yang mengubah cara kerja mobile

### 1. `titik_ukur` — mobile SUDAH BENAR, jangan dirombak

Terus kirim nilai **terkoreksi suhu** (`4.009244572`), bukan nominal botol
(`3.99`). `3.99` itu label botol pada suhu referensi; nilai pH buffer bergerak
ikut suhu larutan.

**Kenapa ini bahaya kalau salah:** backend nyocokin CMC pakai
`round(titik_ukur)` toleransi 0.1 — jadi `3.99` **maupun** `4.0092` sama-sama
lolos, nggak ada `422`, nggak ada error. Yang beda cuma **angka koreksi yang
tercetak di sertifikat pelanggan**. Salahnya baru ketahuan waktu ada yang
membandingkan sertifikat baru sama arsip lama.

> Bloker ini dulu nahan seluruh perluasan form pH. **Sekarang terbuka.**

### 2. Kredensial & deep link ganti

| | Lama ❌ | Baru ✅ |
|---|---|---|
| ID pegawai | `ASM-000x` | `SDK-000x` |
| Email | `@asmo.test` | `@sidik.test` |
| Deep link reset | `asmo://` | `sidik://` |
| Database | `asmo_db` | `sidik_db` |

`docs/kontrak-api.md` udah diperbarui. Ini yang bikin login uji gagal sebelum
ketahuan — `ASM-0002` sekarang dijawab `401`.

---

## Sekarang giliran mobile

Semua di bawah ini **nggak nunggu siapa-siapa lagi**:

| Prioritas | Kerjaan | Endpointnya |
|---|---|---|
| 1 | Sambungin CRUD folder ke `arsip_screen.dart` | `POST/PUT/DELETE /arsip/folders` |
| 2 | Lengkapi kepala worksheet pH dari data yang sekarang udah dikirim | detail sesi yang digemukin |
| 3 | Hitung sambil ngetik di form pH | `POST /calibrations/preview` |
| 4 | Layar Notifikasi beneran | `GET /notifications` |
| 5 | QR di layar sertifikat | `qr_token` |
| 6 | Layar Laporan + unduh | `GET /laporan/kalibrasi` |
| 7 | Sembunyiin tombol sesuai peran | `GET /me/permissions` |
| 8 | Layar Data Ruangan | `GET /rooms` (udah lama ada) |
| 9 | Deep link `sidik://` di manifest | — |

---

## Satu-satunya yang masih nyangkut di backend

**`qr_url` masih nunjuk alamat dev.** Kalau QR-nya dicetak di sertifikat
sekarang, yang scan bakal mentok. Perlu domain produksi sebelum sertifikat
beneran diterbitkan ke pelanggan.

---

*Pelajaran yang bikin halaman ini ada: dua sesi menggarap repo yang sama tanpa
saling lihat, dan dokumen jadi basi dalam hitungan jam — dua kali kami hampir
minta backend ngerjain ulang barang yang udah jadi. **Sebelum ngirim apa pun
ke backend, cek dulu `routes/api.php` dan `git log` mereka.** Lima menit,
mencegat kerja ganda yang bisa berhari-hari.*

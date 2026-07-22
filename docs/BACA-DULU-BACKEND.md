# Buat Raihan — Baca Ini Dulu

*Diperbarui 22 Juli 2026 sore, setelah ngecek langsung ke `asmo-api` branch
`feat/kalibrasi-ph-lengkap-dan-arsip` dan `routes/api.php` — bukan dari
dokumen lama.*

Ada **empat dokumen permintaan** dari mobile, dan sebagian isinya udah basi
karena kamu keburu ngerjain duluan. Halaman ini yang nentuin mana yang masih
berlaku, biar nggak ada yang dikerjain dua kali.

---

## 1. JANGAN dikerjain — udah selesai

| Barang | Bukti | Dokumen yang udah basi |
|---|---|---|
| **CRUD folder arsip** (bikin/rename/pindah/hapus + pindah berkas) | `FolderController`, 24 test di `FolderArsipTest.php` | `permintaan-endpoint-fase-2.md` §4 — **udah dicoret** |
| `kalibrasi_selesai` di `/dashboard` | Kepakai di mobile | `permintaan-endpoint.md` §1 |
| `GET /dashboard/tren` | Kepakai di mobile | `permintaan-endpoint.md` §2 |
| CRUD `/rooms` | Kepakai — tinggal layar mobilenya | `permintaan-endpoint.md` §3 |
| Entitas `/orders` + penugasan teknisi | Kepakai di layar Tugas Saya | `permintaan-endpoint.md` §4 |
| `total_sertifikat` di `/dashboard` | Kepakai di kartu hero | — |

**Juga jangan dikerjain** (bukan karena selesai, tapi karena diputuskan bukan
buat HP): Import Excel, Backup Database, User Management penuh, menu sidebar.
Alasannya di `permintaan-endpoint.md` §6.

---

## 2. BLOKER — ini yang nahan mobile paling keras

### a. `titik_ukur` nominal vs terkoreksi suhu

**Belum kejawab, dan ini nahan seluruh perluasan form pH.**

Worksheet Excel nampilin nominal `3,99 / 7,00 / 10,01`; handoff kamu minta
`4.009244572` (terkoreksi suhu). Sekarang mobile ngirim yang **terkoreksi**.
Kalau ternyata yang bener nominal, payload-nya harus dirombak — dan kalau
mobile keburu bangun formnya duluan, bongkarnya dua kali.

Detail + opsinya: **`permintaan-worksheet-ph.md` §0**.

### b. Matriks peran — siapa boleh apa

Sekarang aturan hak akses ditebak mobile dari `403` yang kejadian di lapangan.
Itu udah bikin satu bug beneran: form Tambah Alat mulus waktu dites pakai
admin, tapi **mentok total di akun teknisi** karena dropdown pelanggannya
narik `GET /customers` yang admin-only — padahal `pelanggan_id` wajib.

Nggak harus endpoint. **Satu file markdown daftar endpoint × role udah cukup.**
Kalau mau sekalian rapi: `GET /api/me/permissions`.

Detail: `permintaan-endpoint-fase-2.md` §1.

---

## 3. Masih berlaku, urut dari yang paling murah

| # | Permintaan | Ukuran | Dokumen |
|---|---|---|---|
| 1 | `qr_token` di objek `sertifikat` | **Sangat kecil** — endpoint `/verify` udah ada, tokennya aja yang nggak ikut dikirim | fase-2 §3b |
| 2 | `nomor_order` + `tanggal_terima` di detail sesi | **Sangat kecil** — mobile udah ngirim waktu `POST`, cuma nggak pernah dibalikin | `permintaan-endpoint.md` §5a |
| 3 | `employee_id` di objek `teknisi` | Sangat kecil — kolom *Technician ID* di sertifikat isinya `DR`, bukan nama panjang | `permintaan-endpoint.md` §5c |
| 4 | `equipment` digemukin (+`pelanggan`) di detail sesi | Kecil — semua udah ada di tabel `equipments` | `permintaan-endpoint.md` §5b |
| 5 | `merk_type` + `tertelusur_ke` di `standar_acuan` | Kecil | `permintaan-endpoint.md` §5d |
| 6 | `logo_url` di organisasi | Kecil | fase-2 §3a |
| 7 | Notifikasi kejadian yang butuh admin | Sedang — polling dulu nggak apa-apa | fase-2 §2 |
| 8 | `POST /calibrations/preview` (hitung sambil ngetik) | Sedang | `permintaan-worksheet-ph.md` §4 |
| 9 | Penanda tangan / Manajer Teknis | Sedang — **perlu keputusan role dulu** | fase-2 §3c |
| 10 | `POST /certificates/{id}/kirim-email` | Sedang | fase-2 §3d |
| 11 | `room_id` di sesi kalibrasi | Sedang — **kamu sendiri yang minta dibahas dulu** (`kontrak-api.md` §9) | fase-2 §3 |
| 12 | `GET /laporan/kalibrasi` + export PDF/Excel | Besar | fase-2 §5 |

Nomor **1–5 semuanya cuma nambah field di resource yang udah ada**, dan
mobile aman nerima respons tanpa field itu (`fromJson` nganggep `null`, barisnya
nggak dirender). Jadi bisa dirilis satu-satu kapan aja tanpa nunggu mobile.

---

## 4. Satu hal kecil: nama seeder

Nama akun di seeder masih **"Teknisi ASMO"** (`DatabaseSeeder.php`), dan itu
kebaca di layar HP sebagai sapaan: *"Halo, Teknisi ASMO"*.

Sisi mobile udah bersih dari ASMO. Yang ini cuma bisa kamu yang ganti — jadi
**"Teknisi Sidik"** aja biar seragam.

Catatan: `ASM-0001` dan `@asmo.test` **jangan diganti** kalau belum
dikoordinasi — mobile & dokumen kontrak masih nunjuk ke situ buat login uji.
Yang perlu diganti cuma **nama tampilannya**.

---

## 5. Peta fitur yang beredar itu udah basi

Kalau kamu dikasih dokumen *"Peta Fitur: Spec vs Kode"* yang dibaca dari branch
`develop` — **lima barisnya salah**. Ini yang sebenernya udah ADA di mobile:

- Grafik pekerjaan (`work_chart.dart`) — bukan "belum ada charting sama sekali"
- Data Teknisi (`technician_list_screen.dart`)
- Rentang ukur (`range_min`/`range_max` di `Equipment`)
- `kalibrasi_selesai`
- Order Kalibrasi (`my_tasks_screen.dart`)

---

## Ringkasnya

1. **Jawab dulu `titik_ukur`** (§2a) — ini nahan paling banyak.
2. **Kirim daftar peran** (§2b), walau cuma markdown.
3. Habis itu ambil **nomor 1–5** di §3; semuanya nambah field, bisa sekali duduk.

Kalau ada yang di sini keliatan udah kamu kerjain tapi masih ketulis "diminta",
bilang aja — berarti dokumen kami yang ketinggalan lagi, dan lebih baik
dibetulin daripada kamu ngerjain dua kali.

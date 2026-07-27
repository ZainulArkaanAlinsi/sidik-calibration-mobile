# Catatan Alur Revisi & QR — hasil cek ulang 27 Juli 2026

Untuk: Raihan (backend) · dari: Arkaan (frontend)

> **Versi pertama dokumen ini salah.** Isinya minta empat field yang ternyata
> **sudah dikirim backend**. Sumber salahnya: aku baca `permintaan-endpoint-fase-2.md`
> (daftar permintaan lama) dan model Dart kami, bukan `BACA-DULU-BACKEND.md`
> yang lebih baru dan sudah dicek langsung ke `routes/api.php`. Ditulis ulang.

Alur yang dituju:

```
foto / manual  →  teknisi isi  →  admin periksa
       ↑                              ↓
       └──── perbaiki ←───────────────┘
                                      ↓ (disetujui)
                                SERTIFIKAT  →  PDF · QR · Excel · email
```

---

## Yang ternyata SUDAH ada (bukan permintaan — catatan buat mobile)

| Yang sempat kukira kurang | Kenyataannya |
|---|---|
| `equipment_id` di detail sesi | **Ada.** `kontrak-api.md:412` — `"equipment": { "id": 12, "nama_alat": "..." }`. Yang membuang id-nya model Dart kami (`calibration_detail.dart:423` cuma ambil `nama_alat`) |
| `qr_token` / `qr_url` | **Ada.** `BACA-DULU-BACKEND.md` #1 |
| Kirim sertifikat lewat email | **Ada.** `POST /certificates/{id}/kirim-email`, `BACA-DULU-BACKEND.md` #10 |
| `tanggal_terima` & `nomor_order` | **Ada** di detail sesi (`BACA-DULU-BACKEND.md` #2) |

Semua itu pekerjaan **mobile**, bukan backend. Sudah masuk antrean kami.

---

## Satu-satunya yang masih perlu jawabanmu: `room_id`

Dua dokumen kita **saling bertentangan**:

- `BACA-DULU-BACKEND.md` #11 — "Ruangan di sesi | `room_id`" (ditandai selesai,
  dicek 22 Juli ke `routes/api.php`)
- `kontrak-api.md:626` — "⚠️ **Belum nyambung ke sesi kalibrasi.**
  `POST /api/calibrations` **belum** nerima `room_id`."

Tolong konfirmasi mana yang benar sekarang. Kalau `room_id` memang sudah
diterima di `POST`/`PUT /calibrations` dan ikut dikirim balik di detail sesi,
mobile langsung pakai. Kalau belum, kami tahan dropdown ruangan di form.

---

## Kenapa dokumennya bisa bentrok — ada sebab yang bisa diperbaiki

`kontrak-api.md` di `main` belum mendokumentasikan `nomor_order` dan
`tanggal_terima`, padahal backend sudah mengirimnya. Penyebabnya ketemu:
commit **`1653603` `docs(kontrak-api): dokumentasi nomor_order, tanggal_terima,
titik metode`** tidak pernah sampai `main` — nyangkut di
`feature/lembar-kerja-teknisi` dan `feature/rename-pt-sidik`.

Commit **`f0f9dad` `fix(profile): scope foto profil per akun`** senasib, dan itu
bug yang masih hidup di `main`: satu key `avatar_path` global, jadi di HP yang
dipakai bergantian semua teknisi berbagi & bisa menimpa foto satu sama lain.

Dua-duanya commit kamu — aku sengaja tidak cherry-pick sendiri. Tolong
diputuskan mau diangkat ke `main` atau ditinggal.

---

## Permintaan tambahan: satu sumber kebenaran

Audit paritas kami berbasis `kontrak-api.md`, dan dokumen itu ketinggalan —
frontend memanggil **14 endpoint yang tidak tercantum di sana**, dan satu
(`/calibrations/{id}/perhitungan`) tidak ada di dokumen mana pun.

Boleh kirim output `php artisan route:list`? Sekali saja cukup. Dengan itu
audit berikutnya berbasis rute asli, bukan dokumen yang sudah tercecer di
enam berkas.

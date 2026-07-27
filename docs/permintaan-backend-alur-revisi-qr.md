# Permintaan Backend — nutup alur input → approval → sertifikat → QR

Ditulis 27 Juli 2026 · untuk: Raihan (backend) · dari: Arkaan (frontend)

Alur yang dituju:

```
foto / manual  →  teknisi isi lembar kerja  →  admin periksa
       ↑                                            ↓
       └──────── perbaiki (kalau ditolak) ←─────────┘
                                                    ↓ (disetujui)
                                              SERTIFIKAT  →  QR yang bisa discan
```

Sebagian besar rantai ini **sudah jalan**. Dua sambungan putus, dan dua-duanya
kekunci di backend — bukan sesuatu yang bisa dibereskan dari sisi mobile.

---

## 1. KRITIS — respons sesi kurang field buat bisa diperbaiki

**Masalahnya:** admin bisa nolak sesi dengan catatan revisi, statusnya jadi
`perlu_revisi`, dan catatannya tampil di layar teknisi. Tapi teknisi **nggak
punya jalan buat mbenerin** — dia harus ngisi ulang dari nol sebagai sesi baru.

Potongannya sebenernya udah ada semua di mobile: `PUT /api/calibrations/{id}`
udah diimplementasiin (`lembar_kerja_service.perbarui`), dan layar lembar kerja
udah nerima `sesiId` buat mode edit.

**Yang bikin nggak bisa dipasang:** buat ngisi ulang formnya, mobile perlu nilai
yang dulu dikirim. `GET /api/calibrations/{id}` sekarang nggak ngasih itu.

Yang dibutuhin form (`LembarKerjaSubmission`) lawan yang ada di respons:

| Field | Wajib? | Ada di `GET /calibrations/{id}`? |
|---|---|---|
| `equipment_id` | **WAJIB** | ❌ — cuma ada `nama_alat` (string) |
| `room_id` | opsional | ❌ — cuma ada `lokasi` (string) |
| `tanggal_terima` | opsional | ❌ |
| `catatan_teknisi` | opsional | ❌ |
| `standard_id` | opsional | ✅ lewat `standar_acuan.id` |
| `tanggal_kalibrasi` | opsional | ✅ |
| suhu/kelembaban awal & akhir | opsional | ⚠️ ada `kondisi_lingkungan.suhu/kelembaban`, perlu dipastiin bentuknya cocok |

`equipment_id` yang paling nyekek: itu satu-satunya field yang **wajib** di
submission. Tanpa itu, form nggak bisa dibangun ulang sama sekali.

**Yang diminta:** tambahin di respons `GET /api/calibrations/{id}`:

```json
{
  "equipment_id": 12,
  "room_id": 3,
  "tanggal_terima": "2026-07-20",
  "catatan_teknisi": "Alat datang dalam kondisi berdebu."
}
```

Kalau `kondisi_lingkungan` udah nyimpen suhu/kelembaban **awal dan akhir**
terpisah, tolong konfirmasi bentuknya — biar mobile bisa ngisi keempat kolomnya,
bukan cuma nebak dari satu angka rata-rata.

**Kenapa nggak diakalin di mobile:** bisa aja mobile nyari `equipment_id` lewat
`GET /equipments` terus nyocokin `nama_alat`-nya. Tapi nama alat nggak dijamin
unik, dan salah tebak artinya sesi revisi **nempel ke alat yang salah** — di lab
terakreditasi itu temuan audit, bukan sekadar bug. Lebih baik nunggu.

---

## 2. `qr_token` belum ikut di respons sertifikat

Ini **pengulangan** dari `permintaan-endpoint-fase-2.md` §3b yang belum
kejawab, ditulis ulang karena sekarang jadi penghalang fitur yang diminta.

`kontrak-api.md` §5 udah nyebut `GET /verify/{qr_token}` (halaman web) dan
`GET /api/verify/{qr_token}` (JSON). Tapi `qr_token`-nya sendiri **nggak pernah
dikirim** di objek sertifikat, jadi mobile nggak tau token apa yang mau
digambar jadi QR.

Mobile udah siap nerima: `Certificate.qrToken` dan
`CertificateSnapshot.qrToken` dua-duanya udah ada dan udah mem-parse
`json['qr_token']`. Yang ngisi baru mock.

**Yang diminta:** di objek `sertifikat` (respons `GET /api/certificates/{id}`
dan yang nempel di `GET /api/calibrations/{id}`):

```json
"qr_token": "a1b2c3d4e5f6",
"qr_url": "https://sidik.example/verify/a1b2c3d4e5f6"
```

`qr_url` lebih disukai daripada cuma token: yang discan orang harus URL utuh,
dan kalau domainnya ditentuin backend, mobile nggak perlu nyusun URL sendiri
(dan nggak ikut salah kalau domainnya ganti).

**Backend nggak perlu ngirim gambar QR-nya.** Mobile yang render sendiri dari
string itu — lebih ringan, dan tetap tajam di layar resolusi berapa pun.

---

## Yang mobile kerjakan duluan, tanpa nunggu

Render QR-nya digarap sekarang pakai data mock, jadi begitu `qr_token` /
`qr_url` beneran dikirim, tinggal nyambung tanpa ubah layar.

Tombol "Perbaiki" **ditahan** sampai poin 1 kejawab — dipasang sekarang justru
bikin teknisi lihat form kosong dan `PUT`-nya bakal ngehapus isian sesi yang
lama.

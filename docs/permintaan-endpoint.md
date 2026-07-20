# Permintaan Endpoint Baru — dari Mobile ke Backend

Dokumen ini nutup celah antara spec fitur yang diminta atasan sama endpoint
yang sekarang ada di `sidik-calibration-api`. Formatnya ngikutin
[`kontrak-api.md`](kontrak-api.md).

Yang ditulis di sini **cuma yang bener-bener ngeblok**. Fitur yang bisa
digarap mobile tanpa backend baru nggak dimasukin.

Urutannya udah diurutin dari yang paling murah ke paling mahal — nomor 1 dan 2
kemungkinan cuma nambah beberapa baris di controller yang udah ada.

---

## 0. Kenapa ini muncul

Empat bagian spec (Dashboard, Master Data, Order Kalibrasi, Input Pengukuran)
udah dipetakan ke kode. Sebagian besar ternyata **udah ada** dan tinggal dipoles.
Yang tersisa nggak bisa digarap mobile karena datanya memang belum pernah
dikirim backend — bukan karena layarnya belum dibikin.

Mobile sengaja **nggak** bikin layar-layar itu pakai data karangan. Layar yang
kelihatan jadi tapi isinya kosong lebih berbahaya daripada layar yang belum ada,
apalagi kalau sampai kebuka di depan klien.

---

## 1. Tambahan field di `GET /api/dashboard` — **paling murah**

Sekarang responsnya:

```json
{
  "data": {
    "total_alat": 5,
    "alat_overdue": 2,
    "kalibrasi_draft": 0,
    "menunggu_approval": 0,
    "sertifikat_bulan_ini": 1
  }
}
```

Spec minta kartu **"Kalibrasi selesai"**, dan angka itu belum ada. Yang paling
mendekati (`sertifikat_bulan_ini`) beda arti — sesi bisa selesai tanpa
sertifikatnya keburu terbit.

**Minta ditambah:**

```json
"kalibrasi_selesai": 12
```

Definisinya diserahkan backend (kemungkinan `status = disetujui`), tapi tolong
dikabarin batasannya apa — mobile cuma nampilin, nggak nurunin sendiri.

> Mobile udah aman kalau field-nya belum ada: `DashboardSummary.fromJson()`
> nganggep field yang hilang sebagai `0`, nggak bikin app crash. Jadi ini bisa
> dirilis kapan aja tanpa nunggu mobile.

---

## 2. Endpoint grafik pekerjaan

Spec minta **grafik pekerjaan** di Dashboard, plus grafik Error/Koreksi/Deviasi
di halaman Perhitungan. Semua endpoint yang ada sekarang cuma ngasih angka
sesaat — nggak ada deret waktu, jadi nggak ada yang bisa digambar.

**Minta endpoint baru:**

```
GET /api/dashboard/tren?dari=2026-05-01&sampai=2026-07-31&satuan=bulan
```

`satuan`: `hari` | `minggu` | `bulan`

```json
{
  "data": [
    { "periode": "2026-05", "masuk": 14, "selesai": 11 },
    { "periode": "2026-06", "masuk": 9,  "selesai": 9  },
    { "periode": "2026-07", "masuk": 6,  "selesai": 3  }
  ]
}
```

Catatan:

- Agregasinya di backend, bukan mobile. Kalau mobile narik semua sesi lalu
  ngitung sendiri, di lab yang udah jalan setahun itu ribuan baris cuma buat
  gambar 12 titik.
- Scope-nya ngikut role kayak `/dashboard` — teknisi lihat miliknya sendiri,
  admin lintas-teknisi. Diambil dari token, mobile nggak ngirim role.
- Periode kosong tetap dikirim dengan nilai `0`, jangan di-skip — biar sumbu
  waktunya nggak bolong.

---

## 3. CRUD Data Ruangan

Spec naruh **Data Ruangan** di Master Data, sederajat sama Pelanggan / Alat /
Standar. Sekarang nggak ada apa-apa — nggak ada tabel, model, maupun route.

**Minta CRUD standar**, bentuknya ngikut pola `customers` yang udah ada:

```
GET    /api/rooms
GET    /api/rooms/{id}
POST   /api/rooms
PUT    /api/rooms/{id}
DELETE /api/rooms/{id}
```

```json
{
  "id": 1,
  "nama": "Lab Kalibrasi 1",
  "kode": "LK-01",
  "lokasi": "Gedung A Lantai 2",
  "suhu_min": 18.0,
  "suhu_maks": 25.0,
  "kelembaban_min": 40.0,
  "kelembaban_maks": 65.0,
  "organization_id": 1
}
```

Kenapa rentang suhu & kelembaban ikut: form kalibrasi pH udah nangkep kondisi
lingkungan awal/akhir. Kalau ruangan punya rentang yang diizinkan, mobile bisa
langsung ngingetin teknisi waktu kondisinya keluar batas — sebelum datanya
kekirim dan ditolak di tahap approval.

Sama kayak pelanggan, `DELETE` tolong nolak dengan **422** kalau ruangannya
masih kepakai di sesi kalibrasi, dan pesannya dikirim apa adanya — mobile
nampilin persis pesan dari backend.

---

## 4. Entitas Order Kalibrasi — **paling besar**

Ini bukan nambah field, tapi entitas baru. Sekarang "nomor order" cuma **field
teks** yang nempel di sesi kalibrasi, bukan sesuatu yang bisa dicari, dicetak,
atau ditugaskan ke teknisi.

Spec-nya minta Order jadi entitas sendiri: satu order masuk (alat dari
pelanggan) → ditugaskan ke teknisi → baru jadi sesi kalibrasi.

**Minta:**

```
GET    /api/orders
GET    /api/orders/{id}
POST   /api/orders
PUT    /api/orders/{id}
```

```json
{
  "id": 1,
  "nomor_order": "ORD-2026-07-001",
  "tanggal": "2026-07-20",
  "tanggal_terima": "2026-07-18",
  "customer": { "id": 3, "nama": "PT Tirta Gracia" },
  "equipment": {
    "id": 5,
    "nama_alat": "pH Meter Bench",
    "merk": "Hanna",
    "model": "HI-2211",
    "serial_number": "HN-2211-05",
    "rentang_ukur": "0–14 pH"
  },
  "lokasi_kalibrasi": "lab",
  "teknisi": { "id": 2, "nama": "Teknisi ASMO" },
  "status": "menunggu"
}
```

Dua hal yang **belum ada di model Equipment** dan dibutuhin di sini:

| Field | Kenapa |
|---|---|
| `rentang_ukur` | Diminta spec di form Order; sekarang nggak ketemu di model |
| penugasan `teknisi` | Belum ada relasi teknisi ke order/sesi mana pun |

Yang perlu diputuskan bareng sebelum digarap:

1. Sesi kalibrasi nyantol ke order (`order_id`), atau order cuma pembungkus
   longgar? Ini nentuin apakah `nomor_order` di sesi tetap dipertahankan atau
   diganti relasi.
2. Satu order = satu alat, atau bisa banyak alat sekaligus? Klien biasanya
   nganter beberapa alat barengan, tapi bentuk JSON di atas masih asumsi
   satu alat per order.

**Cetak Work Order** nyusul setelah entitasnya ada — kemungkinan bentuknya
sama kayak sertifikat (`GET /api/orders/{id}/download`, balikin PDF, bukan HTML).

---

## 5. Yang **tidak** diminta, dan alasannya

Supaya nggak salah paham arah:

| Item spec | Kenapa nggak diminta |
|---|---|
| Kolom Koreksi & Ketidakpastian di form input | Itu **hasil hitungan**, bukan isian teknisi. Udah diputuskan jadi domain backend (`Aturan Bisnis Inti.md`). Mobile nampilin hasilnya, nggak ngitung. |
| Tombol "Hitung" di mobile | Sama. Kalau HP ikut ngitung GUM/ILAC-G8, angkanya berisiko beda sama sertifikat resmi — masalah serius buat lab terakreditasi. |
| Import Excel | Pola desktop. Di HP, ngambil file Excel lalu mappingnya lebih ribet daripada ngetik langsung. Kalau tetap dibutuhin, lebih pas di panel web admin. |
| Backup Database | Urusan server, bukan aplikasi HP. |
| User Management penuh | Sebagian udah kepenuhin `GET /users` + approve/reject/reset-password, dan layar Data Teknisi udah dibikin di atas itu. Bikin/hapus akun lebih pas di panel admin. |

---

## 6. Ringkasan buat rapat

| # | Permintaan | Ukuran | Ngeblok |
|---|---|---|---|
| 1 | `kalibrasi_selesai` di `/dashboard` | Kecil | Kartu "Kalibrasi selesai" |
| 2 | `GET /dashboard/tren` | Sedang | Semua grafik (Dashboard & Perhitungan) |
| 3 | CRUD `/rooms` | Sedang | Master Data → Data Ruangan |
| 4 | Entitas `/orders` + `rentang_ukur` + teknisi | Besar | Seluruh bagian Order Kalibrasi |

Nomor 1 bisa dirilis sendirian kapan aja — mobile udah aman nerima respons
tanpa field itu.

---

*Disusun 20 Juli 2026 · dibaca dari `develop` setelah PR #21 & #22 di-merge,
dicek langsung ke `routes/api.php` dan controller-nya, bukan dari dokumentasi.*

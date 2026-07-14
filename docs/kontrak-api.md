# Kontrak API — apa yang dibutuhin Mobile

Dokumen ini buat @raihannazhiif (backend, [`sidik-calibration-api`](https://github.com/ZainulArkaanAlinsi/sidik-calibration-api)). Isinya daftar endpoint yang app Flutter panggil, plus bentuk JSON yang diharapkan — biar nggak ada tebak-tebakan nama field.

**Kalau ada yang mau diubah, boleh banget** — tapi kabarin dulu, jangan diam-diam, karena mobile ngoding persis ngikutin bentuk di sini. Ubah namanya di dokumen ini juga biar tetap satu sumber kebenaran.

---

## 0. Aturan Umum (berlaku buat semua endpoint)

**Base URL**: `/api` — mobile nembak ke `http://10.0.2.2:8000/api` waktu dev (itu cara emulator Android manggil `localhost` laptop).

**Auth**: JWT lewat header. Semua endpoint butuh ini kecuali `/health`, `/login`, dan `/verify/{qr_token}`.
```
Authorization: Bearer <token>
Accept: application/json
```

**Tanggal**: selalu format ISO 8601 (`2026-07-14T09:30:00Z`), jangan `14/07/2026` — biar Dart bisa `DateTime.parse()` langsung tanpa nebak format.

**Angka desimal**: kirim sebagai **number**, bukan string. `"nilai": 10.05` ✅, `"nilai": "10.05"` ❌.

**Sukses (1 objek)** — data selalu dibungkus `data`:
```json
{ "data": { "id": 1, "nama": "..." } }
```

**Sukses (list, pakai paginasi Laravel)**:
```json
{
  "data": [ { "id": 1 }, { "id": 2 } ],
  "meta": { "current_page": 1, "last_page": 5, "per_page": 15, "total": 68 }
}
```

**Error validasi (422)** — format bawaan Laravel, mobile udah siap baca ini buat nampilin error per field:
```json
{
  "message": "Data yang dikirim tidak valid.",
  "errors": {
    "nama_alat": ["Nama alat wajib diisi."],
    "serial_number": ["Nomor seri sudah dipakai alat lain."]
  }
}
```

**Error lain**: `401` token invalid/kadaluarsa · `403` role nggak punya akses · `404` nggak ketemu · `500` error server. Selalu ada field `message` yang layak ditampilin ke user.

---

## 1. PALING PERTAMA — Health Check

Bikin ini duluan, hari ini juga kalau bisa. Kecil, tapi begitu ada, mobile bisa buktiin sambungannya jalan sebelum fitur beneran dibangun di atasnya.

**`GET /api/health`** — tanpa auth.
```json
{ "status": "ok", "app": "sidik-calibration-api", "time": "2026-07-14T09:30:00Z" }
```

---

## 2. Auth (dibutuhin Minggu 2)

### `POST /api/login`
Request:
```json
{ "email": "admin@asmo.test", "password": "rahasia123" }
```
Response `200`:
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "nama": "Budi Santoso",
      "email": "admin@asmo.test",
      "role": "admin",
      "organization_id": 1
    }
  }
}
```
Kredensial salah → `401` dengan `{ "message": "Email atau password salah." }`

> **`role` wajib salah satu dari: `admin` / `teknisi` / `viewer`** — persis string itu, huruf kecil. Mobile pakai ini buat nentuin menu mana yang dirender. Kalau nanti ada role baru, kabarin dulu.

### `GET /api/me`
Buat validasi token yang tersimpan waktu app dibuka (splash screen). Response: objek `user` yang sama kayak di atas.

### `POST /api/logout`
Response `200`: `{ "message": "Berhasil logout." }`

---

## 3. Data Alat (dibutuhin Minggu 3)

### `GET /api/equipments`
Query params yang mobile pakai: `?search=kaliper&category=panjang&status=overdue&page=1`

```json
{
  "data": [
    {
      "id": 12,
      "nama_alat": "Jangka Sorong Mitutoyo",
      "serial_number": "MT-500-196-30",
      "kategori": "panjang",
      "merk": "Mitutoyo",
      "pelanggan": { "id": 3, "nama": "PT Maju Jaya" },
      "tanggal_kalibrasi_terakhir": "2026-01-15T00:00:00Z",
      "tanggal_jatuh_tempo": "2027-01-15T00:00:00Z",
      "status": "aktif"
    }
  ],
  "meta": { "current_page": 1, "last_page": 3, "per_page": 15, "total": 42 }
}
```

> **`status` wajib salah satu dari: `aktif` / `overdue` / `nonaktif`.**
> **`kategori`** ngikutin kelompok pengukuran di `data-kemampuan-kalibrasi.json` (panjang, massa, suhu, tekanan, volume, dst) — pakai **string huruf kecil** yang konsisten, jangan campur "Panjang" dan "panjang".

### `GET /api/equipments/{id}` — 1 objek, bentuk sama.
### `POST /api/equipments` · `PUT /api/equipments/{id}` · `DELETE /api/equipments/{id}`
Body sama seperti field di atas (tanpa `id`). Teknisi & admin boleh; **viewer harus ditolak `403`.**

### `GET /api/categories`
Mobile butuh ini buat isi dropdown kategori + nyiapin worksheet dinamis (kolom tiap kategori beda-beda):
```json
{
  "data": [
    {
      "kode": "panjang",
      "nama": "Panjang",
      "rentang_ukur": "0 – 300 mm",
      "ketidakpastian_terbaik": 0.005,
      "satuan": "mm"
    }
  ]
}
```

---

## 4. Kalibrasi (dibutuhin Minggu 4, jalur kamera Minggu 5)

### `POST /api/calibrations`
Bikin sesi kalibrasi + kirim data mentah sekaligus. **Data dari input manual dan dari hasil scan kamera masuk ke endpoint yang sama persis** — nggak usah bikin endpoint terpisah buat OCR. Bedanya cuma di field `input_method` (buat statistik, bukan buat logic beda).

```json
{
  "equipment_id": 12,
  "kategori": "panjang",
  "input_method": "manual",
  "tanggal_kalibrasi": "2026-07-14T09:00:00Z",
  "suhu_ruang": 23.5,
  "kelembaban": 55.0,
  "measurements": [
    { "titik_ukur": 50.0, "pembacaan": [50.02, 50.01, 50.03], "satuan": "mm" },
    { "titik_ukur": 100.0, "pembacaan": [100.05, 100.04, 100.05], "satuan": "mm" }
  ]
}
```
`input_method`: `manual` atau `ocr`.

Response `201` — balikin sesi yang udah kehitung (lihat bentuknya di bawah).

### `GET /api/calibrations` · `GET /api/calibrations/{id}`
```json
{
  "data": {
    "id": 88,
    "equipment": { "id": 12, "nama_alat": "Jangka Sorong Mitutoyo" },
    "teknisi": { "id": 4, "nama": "Andi" },
    "tanggal_kalibrasi": "2026-07-14T09:00:00Z",
    "status": "menunggu_approval",
    "hasil": {
      "rata_rata": 50.02,
      "error": 0.02,
      "ketidakpastian_gabungan": 0.0031,
      "faktor_cakupan_k": 2.0,
      "ketidakpastian_diperluas": 0.0062,
      "keputusan": "PASS"
    },
    "catatan_revisi": null,
    "certificate_id": null
  }
}
```

> **`status` wajib salah satu dari: `draft` / `menunggu_approval` / `disetujui` / `perlu_revisi`.**
> **`keputusan`: `PASS` atau `FAIL`** (huruf besar). Ingat: **FAIL tetap boleh terbit sertifikat**, statusnya aja beda — jangan diblokir di backend.
> Perhitungan GUM (Type A + Type B → gabungan → `U = k × u_c`) dan keputusan ILAC-G8 **dihitung di backend**, mobile cuma nampilin. Mobile nggak ngitung apa pun.

### Riwayat
`GET /api/calibrations?mine=true` — teknisi cuma lihat kalibrasi miliknya sendiri; **admin lihat semua**. Filter ini penting, jangan sampai teknisi bisa lihat punya orang lain.

---

## 5. Approval & Sertifikat (dibutuhin Minggu 8)

### `POST /api/calibrations/{id}/approve` — **admin doang**, teknisi/viewer → `403`.
Response: sesi dengan `status: "disetujui"`. Generate sertifikat jalan di **queue** (async), jadi `certificate_id` boleh masih `null` sesaat.

### `POST /api/calibrations/{id}/reject`
```json
{ "catatan_revisi": "Titik ukur 100mm cuma 2 pembacaan, minimal 3." }
```
Response: status jadi `perlu_revisi` + `catatan_revisi` keisi. Mobile bakal nampilin catatan ini ke teknisi.

### `GET /api/certificates/{id}`
```json
{
  "data": {
    "id": 21,
    "nomor": "CAL/2026/07/0001",
    "calibration_id": 88,
    "status": "terbit",
    "pdf_url": "https://.../certificates/CAL-2026-07-0001.pdf",
    "qr_token": "a1b2c3d4e5",
    "revision_of": null,
    "diterbitkan_pada": "2026-07-14T10:15:00Z"
  }
}
```
> **`status`: `menunggu_generate` / `terbit` / `gagal`.** Kalau `gagal`, mobile nampilin tombol retry — jadi tolong sediain `POST /api/certificates/{id}/retry`.
> `pdf_url` idealnya URL yang bisa langsung diunduh mobile (signed URL / route yang nerima Bearer token).

### `GET /api/verify/{qr_token}` — **tanpa auth** (dipakai orang luar yang scan QR).

---

## 6. Notifikasi (dibutuhin Minggu 9)

### `GET /api/notifications`
```json
{
  "data": [
    {
      "id": 5,
      "tipe": "jatuh_tempo",
      "judul": "3 alat mendekati jatuh tempo",
      "pesan": "Jangka Sorong Mitutoyo jatuh tempo 20 Jul 2026.",
      "dibaca": false,
      "created_at": "2026-07-14T08:00:00Z"
    }
  ]
}
```
`tipe`: `jatuh_tempo` / `approval` / `revisi`.

### `POST /api/notifications/{id}/read`

---

## 7. Dashboard (biar nggak ngambil 5 endpoint sekaligus)

### `GET /api/dashboard`
Isinya beda tergantung role — teknisi dapat ringkasan miliknya, admin dapat lintas-teknisi. Backend yang nentuin dari token, mobile nggak ngirim role.
```json
{
  "data": {
    "total_alat": 42,
    "alat_overdue": 3,
    "kalibrasi_draft": 2,
    "menunggu_approval": 5,
    "sertifikat_bulan_ini": 12
  }
}
```

---

## Yang paling penting buat disepakati sekarang

1. **`GET /api/health`** — bikin duluan, biar sambungan mobile ↔ API bisa dites minggu ini.
2. **Nama field**: dokumen ini pakai **bahasa Indonesia** (`nama_alat`, `tanggal_jatuh_tempo`). Kalau kamu lebih milih Inggris (`name`, `due_date`), **nggak masalah — tapi putusin sekarang**, jangan setengah jalan. Yang mahal itu ganti nama field pas dua sisi udah kadung dikoding.
3. **Nilai enum** (`role`, `status`, `keputusan`, `kategori`) harus persis kayak di atas, termasuk besar-kecil hurufnya. Ini yang paling sering bikin bug diam-diam.
4. **CORS**: nggak perlu diapa-apain buat mobile (bukan browser), jadi jangan buang waktu di situ.

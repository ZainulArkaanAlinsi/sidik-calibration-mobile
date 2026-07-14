# Kontrak API — apa yang dibutuhin Mobile

Dokumen ini buat @raihannazhiif (backend, [`sidik-calibration-api`](https://github.com/ZainulArkaanAlinsi/sidik-calibration-api)). Isinya daftar endpoint yang app Flutter panggil, plus bentuk JSON yang diharapkan — biar nggak ada tebak-tebakan nama field.

**Kalau ada yang mau diubah, boleh banget** — tapi kabarin dulu, jangan diam-diam, karena mobile ngoding persis ngikutin bentuk di sini. Ubah namanya di dokumen ini juga biar tetap satu sumber kebenaran.

---

## 0. Aturan Umum (berlaku buat semua endpoint)

**Base URL**: `/api` — mobile nembak ke `http://10.0.2.2:8000/api` waktu dev (itu cara emulator Android manggil `localhost` laptop).

**Auth**: token Bearer lewat header. Semua endpoint butuh ini kecuali `/health`, `/login`, dan `/verify/{qr_token}`.
```
Authorization: Bearer <token>
Accept: application/json
```

> **Update 14 Jul — bukan JWT, tapi Laravel Sanctum.** Buat mobile caranya sama persis (tetap `Authorization: Bearer <token>`, tinggal simpan stringnya), cuma bentuk tokennya beda: `1|JpQDXLhSEz...`, bukan `eyJhbGci...`. Konsekuensinya: **token Sanctum nggak punya masa berlaku, jadi nggak ada endpoint `/refresh`** dan nggak perlu logic auto-refresh di app. Token cuma mati kalau dipanggil `/logout` atau dicabut admin.

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

> ✅ **Live sejak 14 Jul.** Satu bedanya: `app` isinya ambil dari `APP_NAME` backend, sekarang nilainya `"ASMO API"` (bukan `"sidik-calibration-api"`). Kalau mobile nggak nge-assert field itu, aman.

---

## 2. Auth (dibutuhin Minggu 2)

> ✅ **Semua endpoint di bagian ini udah live sejak 14 Jul** — login (ID pegawai & email dua-duanya jalan), register, `/me`, `/logout`, plus approval admin (`GET /api/users?status=pending`, `approve`, `reject`). Dites end-to-end, termasuk skenario daftar-sambil-ngaku-admin: role dari client diabaikan, akunnya tetap `teknisi` + `pending`.
>
> Yang belum ada di dokumen ini, tolong dicatat mobile:
> - **`429 Too Many Requests`** bisa muncul: login dibatesin **10 percobaan/menit per IP**, register **5/menit**. Siapin pesan "coba lagi sebentar" di UI.
> - Akun **`nonaktif`** ditolak `403` juga, pesannya `"Akun ini nonaktif. Hubungi admin."` (beda dari pesan `pending`).
> - **`organization_id` masih `null`** buat akun hasil register — tabel `organizations` belum ada (baru dirancang di ERD hari ini). Jangan dianggap wajib int dulu di sisi Dart, biar nggak crash pas parsing.
> - Akun dev buat nyoba: `ASM-0001` (admin) · `ASM-0002` (teknisi) · `ASM-0003` (viewer) · `ASM-0099` (sengaja `pending`, buat nyobain layar "belum disetujui"). Password semua `rahasia123`.

### `POST /api/login`

**Login nerima ID pegawai ATAU email** di satu field `identifier` — teknisi di lapangan hafal nomor pegawainya (`ASM-0001`), bukan emailnya. Backend yang nebak: kalau ada `@` anggap email, kalau nggak anggap `employee_id`.

Request:
```json
{ "identifier": "ASM-0001", "password": "rahasia123" }
```
(atau `{ "identifier": "admin@asmo.test", "password": "..." }` — dua-duanya harus jalan)

Response `200`:
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "nama": "Budi Santoso",
      "email": "admin@asmo.test",
      "employee_id": "ASM-0001",
      "role": "admin",
      "status": "aktif",
      "department": "Quality Control",
      "organization_id": 1
    }
  }
}
```
Kredensial salah → `401` `{ "message": "ID pegawai / email atau password salah." }`

> **`role` wajib: `admin` / `teknisi` / `viewer`** — persis, huruf kecil. Mobile pakai ini buat nentuin menu mana yang dirender.
> **`status` wajib: `aktif` / `pending` / `nonaktif`.**
> **`employee_id` wajib unik** (dipakai buat login).

**PENTING — akun `pending` WAJIB ditolak login di backend** dengan `403`:
```json
{ "message": "Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya." }
```
Mobile juga nolak di sisi UI, **tapi itu nggak cukup** — orang bisa nembak API langsung pakai curl, jadi backend harus jadi benteng aslinya.

### `POST /api/register`

Daftar mandiri buat teknisi. **Akun yang dibuat NGGAK boleh langsung aktif.**

Request:
```json
{
  "nama": "Eko Prasetyo",
  "employee_id": "ASM-0099",
  "department": "Kalibrasi",
  "email": "eko@ptasmo.com",
  "password": "rahasia123"
}
```
Response `201`:
```json
{ "message": "Pendaftaran terkirim. Akun menunggu persetujuan admin." }
```

Aturan yang wajib dipegang backend:
- Akun baru **selalu** `status: "pending"` dan `role: "teknisi"` (default)
- **User NGGAK boleh milih role sendiri** waktu daftar — kalau field `role` dikirim dari client, **abaikan**. Kalau nggak, siapa pun bisa daftar jadi `admin` dan langsung bisa approve dirinya sendiri
- `email` & `employee_id` dobel → `422` dengan pesan jelas ("Email ini sudah terdaftar." / "ID pegawai ini sudah terdaftar.")
- Password minimal 8 karakter

### `POST /api/forgot-password`
Request: `{ "email": "admin@asmo.test" }`
Response `200`: `{ "message": "Link reset password udah dikirim ke email kamu." }`
Email nggak terdaftar → `404` `{ "message": "Email ini nggak terdaftar." }`

> **Reset lewat email, bukan lewat `employee_id`** — biar yang bisa ganti password cuma orang yang megang emailnya. Kalau reset bisa pakai ID pegawai doang, siapa pun yang tahu nomor pegawai orang lain bisa reset password dia.
>
> ⚠️ **Catatan keamanan yang perlu kita omongin.** Balikin `404 "Email ini nggak terdaftar"` itu **ngebocorin email mana yang punya akun** (namanya *user enumeration*) — orang bisa nebak-nebak email buat tahu siapa aja karyawan yang punya akun. Praktik yang lebih aman: **selalu** jawab `200 "Kalau emailnya terdaftar, link udah dikirim"`, tanpa ngasih tahu ada atau nggak.
>
> Buat sekarang mobile ngikutin catatan harian (yang minta state "error email nggak terdaftar"), tapi kalau kamu setuju, kita ganti dua-duanya ke pola yang aman. **Ini keputusan yang perlu diambil bareng, bukan diam-diam.**

> ### ✅ Keputusan (backend, 14 Jul): **pakai pola yang aman.**
> Kamu bener, jadi backend ngikutin usulan kamu. `POST /api/forgot-password` **selalu** balikin `200` dengan pesan yang sama, mau emailnya terdaftar atau nggak — **nggak ada `404`**:
> ```json
> { "message": "Kalau email itu terdaftar, link reset password udah dikirim ke sana." }
> ```
> **Efeknya buat mobile: layar Reset Password cuma butuh 2 state, bukan 3.** State "error email nggak terdaftar" nggak bisa dibikin (backend emang nggak ngasih tahu), jadi ganti aja jadi layar "cek email kamu". Catatan harian [[2026-07-20]] udah dikoreksi.
>
> Rate limit: **5 percobaan/menit per IP**, jatahnya sendiri — nggak nyampur sama jatah login.

### `POST /api/reset-password`
Dipakai dari link di email (deep link ke app).

Request — **`email` ikut dikirim**, ya:
```json
{ "token": "...", "email": "teknisi@asmo.test", "password": "passwordbaru123" }
```

> ✅ **Live sejak 14 Jul.** Tiga catatan:
> - **`email` wajib ada.** Token reset itu nempel ke email, jadi backend butuh dua-duanya buat nyocokin. Mobile udah punya nilainya: link di email bentuknya `asmo://reset-password?token=...&email=...` — tinggal dibaca dari deep link-nya.
> - **Deep link `asmo://`** — tolong daftarin scheme itu di Android manifest. Waktu dev backend pakai `MAIL_MAILER=log`, jadi link-nya nongol di `storage/logs/laravel.log` (bisa di-copy manual buat tes).
> - **`password_confirmation` opsional.** Kalau dikirim, dicek harus sama; kalau nggak, ya udah — konfirmasinya kamu cek di UI.
> - Sukses → `200 { "message": "Password berhasil diubah. Silakan login lagi." }`. Token ngawur/kadaluarsa → `422`.
> - **Semua token login lama otomatis dicabut** sesudah reset berhasil. Jadi kalau HP lama masih megang sesi, sesinya mati — justru itu alasan orang me-reset password.

### `GET /api/me`
Buat validasi token yang tersimpan waktu app dibuka (splash). Response: objek `user` yang sama kayak di atas.

### `POST /api/logout`
Response `200`: `{ "message": "Berhasil logout." }`

### Approval akun (admin-only) — dibutuhin biar register-nya ada gunanya
- **`GET /api/users?status=pending`** — daftar akun yang nunggu disetujui
- **`POST /api/users/{id}/approve`** — body `{ "role": "teknisi" }`. Admin yang nentuin role-nya di sini, bukan si pendaftar. Setelah ini `status` jadi `aktif` dan orangnya baru bisa login
- **`POST /api/users/{id}/reject`** — tolak pendaftaran

Kalau endpoint approve belum ada, **register jadi jebakan**: orang daftar, terus nggak pernah bisa masuk selamanya, dan nggak ada yang tahu. Jadi dua-duanya harus jalan bareng.

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

> ## ✅ Live sejak 14 Jul — tapi BACA INI DULU sebelum ngoding
>
> **1. Kode kategorinya bukan `"suhu"`.** Kelompok pengukuran di lampiran akreditasi ada 10, dan kodenya slug dari nama aslinya — jadi ada yang panjang. **Jangan di-hardcode dari ingatan**, ambil dari `GET /api/categories`. Daftar lengkapnya:
>
> `panjang` · `massa` · `volume` · `tekanan` · `gaya` · `aliran` · `densitas` · `instrumen-analitik` · **`suhu-dan-kelembapan`** · **`waktu-dan-frekuensi`**
>
> **2. Nulis alat pakai `pelanggan_id`, bukan objek `pelanggan`.** Responsnya tetap objek (`"pelanggan": {"id":3,"nama":"..."}`), tapi buat `POST`/`PUT` kirim `"pelanggan_id": 3`.
>
> **3. `status: "overdue"` NGGAK bisa dikirim.** Dia dihitung backend dari `tanggal_jatuh_tempo` — kalau dikirim di body, ditolak `422`. Yang bisa diset cuma `aktif`/`nonaktif`. Sebabnya: kalau `overdue` disimpen, nilainya basi tiap ganti hari.
>
> **4. Hak akses**: baca = semua role (termasuk viewer). Nulis (`POST`/`PUT`/`DELETE`) = **admin & teknisi**; viewer ditolak `403`. Sesuai permintaan kamu.
>
> **5. Field bonus di response** (di luar kontrak, aman diabaikan): `model`, `no_identifikasi`, `range_min`, `range_max`, `satuan`, `resolusi`, `toleransi`, `lokasi`. Ini dibutuhin nanti pas layar kalibrasi.
>
> **6. `meta` paginasinya lebih gemuk dari yang kamu tulis** — Laravel ikut ngirim `from`, `to`, `path`, `links`. Superset, jadi aman; abaikan aja yang nggak kepakai.

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

> ✅ **Live sejak 14 Jul**, isinya 10 kategori dari lampiran akreditasi (151 rentang kemampuan).
>
> ⚠️ **`rentang_ukur` / `ketidakpastian_terbaik` / `satuan` di sini cuma RINGKASAN, jangan dipakai buat validasi.** Satu kelompok pengukuran bisa punya banyak satuan sekaligus — "Panjang" isinya µm **dan** mm, "Instrumen Analitik" isinya pH, NTU, cP, µS. Angka yang ditampilin itu diambil dari satuan yang paling sering muncul di kelompok itu, jadi cocoknya buat dipajang sekilas doang.
>
> Buat validasi rentang & nyiapin worksheet, pakai **`GET /api/categories/{kode}`** — balikin semua rentang kemampuan (CMC) kategori itu satu per satu:
> ```json
> { "data": { "kode": "panjang", "nama": "Panjang", "kemampuan": [
>     { "nama_alat": "Micrometer", "parameter": null, "range_min": 0, "range_max": 25,
>       "range_note": null, "satuan": "mm", "ketidakpastian_terbaik": 0.00083,
>       "satuan_ketidakpastian": "mm", "faktor_cakupan": 2, "metode": "SIDIK-IK-CAL-0515_Rev.3" }
> ] } }
> ```
> **`range_min` bisa `null`** — 59 dari 151 kemampuan emang nggak punya batas bawah numerik: ada yang titik tunggal (buret "25 mL"), ada yang batasnya kata-kata (oven "ambient ~ 300 °C" → teks aslinya ada di `range_note`). Jangan diparse jadi `double` mentah-mentah, nanti crash.

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

> ✅ **Live sejak 14 Jul — dan ADA DUA VERSINYA, ini penting buat nentuin isi QR-nya.**
>
> **1. `GET /verify/{qr_token}` (halaman web, bukan `/api`).** Ini yang harus ditaruh di QR sertifikat. Alasannya: yang scan itu orang luar (auditor, pelanggan) pakai **kamera HP biasa** — yang kebuka **browser**, bukan app kita. Kalau QR-nya diisi URL `/api/...`, yang muncul di layar mereka JSON mentah. Halaman webnya nampilin nomor sertifikat, alat, pemilik, tanggal, dan hasil PASS/FAIL dengan rapi + kop lab & nomor akreditasi. QR ngawur → halaman "Sertifikat tidak ditemukan" (404), bukan error mentah.
>
> **2. `GET /api/verify/{qr_token}` (JSON).** Ini buat kalau **mobile** mau nampilin hasil scan di dalam app (misal teknisi scan sertifikat lama pakai fitur scan di app):
> ```json
> { "data": {
>     "nomor": "CAL/2026/07/0001", "status": "terbit", "keputusan": "PASS",
>     "diterbitkan_pada": "2026-06-15T00:00:00Z", "berlaku_sampai": "2027-06-14T00:00:00Z",
>     "kadaluarsa": false,
>     "alat": { "nama_alat": "Jangka Sorong Mitutoyo", "serial_number": "MT-500-196-30", "pemilik": "PT Maju Jaya" },
>     "tanggal_kalibrasi": "2026-06-14T00:00:00Z",
>     "diterbitkan_oleh": { "nama": "PT Sistem Dirgantara Inovasi Teknologi (PT Sidik)", "no_akreditasi": "LK-285-IDN" }
> } }
> ```
> QR nggak ketemu → `404 { "message": "Sertifikat dengan kode QR ini tidak terdaftar." }`
>
> Dua-duanya **cuma nampilin sertifikat yang statusnya `terbit`** — yang masih `menunggu_generate` dianggap nggak ada. Isinya sengaja dibatesin (nggak ada data mentah pengukuran, nggak ada nama/email teknisi), karena ini halaman publik.
>
> **Sertifikat contoh buat nyoba**: token `DEMOQR123` → `http://10.0.2.2:8000/verify/DEMOQR123` (udah ada di seeder).

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

> ✅ **Live sejak 14 Jul**, persis bentuk ini. Role diambil dari token (teknisi cuma ngitung kalibrasi miliknya sendiri; admin & viewer lintas-teknisi) — mobile nggak usah ngirim apa-apa.
>
> `kalibrasi_draft`, `menunggu_approval` & `sertifikat_bulan_ini` sekarang **selalu 0** — wajar, fitur kalibrasinya belum ada (Minggu 4). `total_alat` & `alat_overdue` udah keisi data beneran dari seeder.

---

## 8. Master Data PT & Pelanggan — **admin doang** (live 14 Jul)

Belum ada di kontrak versi kamu, tapi udah jalan di backend. Dibutuhin buat layar Pengaturan (admin).

- **`GET /api/organization`** · **`PUT /api/organization`** — data PT: `nama`, `alamat`, `telepon`, `email`, `no_akreditasi`. Ini yang bakal dicetak di kop sertifikat. *Nggak ada create/delete* — satu instalasi = satu PT.
- **`GET /api/customers?search=&page=`** · **`POST`** · **`GET/PUT/DELETE /api/customers/{id}`** — CRUD pelanggan. Field: `nama`, `alamat`, `contact_person`, `telepon`, `email` (+ `jumlah_alat` di response).
- **Pelanggan yang masih punya alat nggak bisa dihapus** → `422`. Kalau dipaksa, alat & riwayat kalibrasinya jadi yatim. Mobile: tampilin pesannya apa adanya.

Teknisi & viewer yang nembak endpoint ini dapat `403`.

---

## Akun buat nyoba (seeder)

| ID pegawai | Email | Role | Status |
|---|---|---|---|
| `ASM-0001` | admin@asmo.test | admin | aktif |
| `ASM-0002` | teknisi@asmo.test | teknisi | aktif |
| `ASM-0003` | viewer@asmo.test | viewer | aktif |
| `ASM-0099` | eko@asmo.test | teknisi | **pending** (buat nyoba layar "belum disetujui") |

Password semua `rahasia123`. Login boleh pakai ID pegawai **atau** email.

Datanya juga udah keisi: **5 alat** (2 di antaranya sengaja `overdue`), 2 pelanggan, 10 kategori, 151 rentang kemampuan kalibrasi. Jadi layar Dashboard & Daftar Alat bisa langsung nampilin data asli — nggak usah pakai dummy.

---

## Yang paling penting buat disepakati sekarang

1. ✅ **`GET /api/health`** — udah ada sejak 14 Jul.
2. ✅ **`POST /api/login` pakai `identifier`** (ID pegawai **atau** email) — udah jalan, dua-duanya.
3. ✅ **Akun `pending` ditolak login di backend** (403) — udah, dan diuji pakai curl langsung (bukan cuma lewat app).
4. ✅ **User nggak bisa milih role sendiri waktu daftar** — `role` dari client diabaikan; ada test yang khusus nyoba nyelipin `"role":"admin"` waktu register, hasilnya tetap `teknisi` + `pending`.
5. ✅ **Nama field: bahasa Indonesia** — diikutin, `nama` bukan `name`. Dikunci pakai test, jadi kalau ada yang ngubah diam-diam, testnya merah duluan sebelum app-nya rusak.
6. ✅ **Nilai enum persis** — diikutin, termasuk `PASS`/`FAIL` huruf besar. **Kecuali satu**: kode kategori nggak sesingkat contoh di dokumen ini (`suhu-dan-kelembapan`, bukan `suhu`) — ambil dari `GET /api/categories`, jangan di-hardcode.
7. ✅ **CORS** — nggak disentuh, sesuai saran kamu.

### Tiga lubang yang sempat kebuka — semuanya udah ditutup 14 Jul

**1. `POST /api/logout-all`** — auth, semua role.
```json
{ "message": "Berhasil keluar dari semua perangkat.", "data": { "sesi_dicabut": 2 } }
```
Token Sanctum nggak kadaluarsa sendiri, jadi tanpa ini sesi di HP yang ilang bakal hidup **selamanya**. Mobile: taruh tombol "Keluar dari semua perangkat" di layar Profil. Sesudah manggil ini, token yang lagi dipakai ikut mati juga — jadi langsung lempar ke layar login.

**2. `organization_id` pendaftar baru sekarang langsung keisi**, nggak nunggu approve. Satu instalasi = satu PT, jadi nggak ada yang perlu dipilih. Layar profil aman, nggak bakal dapat PT kosong.

**3. Admin bisa benerin akun & nyetel ulang password** — ini penting: reset password jalannya lewat **email**, tapi login pakai **ID pegawai**. Orang yang salah ketik emailnya waktu daftar (`eko@gmial.com`) bakal kekunci selamanya kalau nggak ada yang bisa benerin.

- **`PUT /api/users/{id}`** — admin-only. Body (semua opsional): `nama`, `email`, `employee_id`, `department`, `role`, `status`. Nyetel `status: "nonaktif"` langsung mutusin sesi orangnya.
- **`POST /api/users/{id}/reset-password`** — admin-only. Body: `{ "password": "passwordbaru123" }` (min 8). Semua sesi lama user itu dicabut. Password barunya admin kasih tahu langsung ke orangnya.

Teknisi/viewer yang nembak dua endpoint itu dapat `403` — udah dites, termasuk skenario teknisi nyoba nyetel ulang password admin.

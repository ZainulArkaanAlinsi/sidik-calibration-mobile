# Perubahan di repo backend — 29 Juli 2026

Buat @raihannazhiif. Hari ini alur pH → sertifikat diuji ujung ke ujung lawan
database asli (`sidik_db`), dan yang bikin macet ternyata di backend. Perbaikannya
dikerjakan langsung supaya app-nya bisa dites hari itu juga. Sekarang **udah
di-commit** di `asmo-api` branch `feat/penanda-tangan-objek-sertifikat` (4 commit:
migrasi, GUM, vision, pH). Silakan diperiksa, diubah, atau di-revert; yang penting
jangan kaget ada perubahan yang bukan dari kamu.

Semua yang ditulis di sini sudah diverifikasi jalan (lihat "Cara ngetes ulang").

---

## 1. Database dev ketinggalan 19 migrasi — dan sebagian tabelnya sudah ada duluan

`migrate:status` nunjukin 19 migrasi Pending sejak 23 Juli. Waktu dijalanin,
berhenti di tengah: kolom/tabelnya **sudah ada** di database padahal tabel
`migrations` nggak nyatet. Jadi skema database lebih maju daripada catatannya.

Yang diubah — lima migrasi dikasih penjaga `hasTable` / `hasColumn`:

- `2026_07_23_110150_add_room_id_to_calibration_sessions_table`
- `2026_07_23_110400_create_folders_table`
- `2026_07_23_120000_add_lembar_kerja_fields_to_calibration_sessions_table`
- `2026_07_23_120100_add_suhu_to_raw_measurements_table`
- `2026_07_23_130000_add_data_sertifikat_to_standards_table`
- `2026_07_25_100000_add_cache_tokens_to_worksheet_extraction_logs_table`
- `2026_07_27_130000_add_tanda_tangan_to_organizations_table`

Penjagaannya **per kolom**, bukan per migrasi: sebagian kolom di satu migrasi
udah ada dan sebagian belum, jadi kalau seluruh migrasi diloncati, yang belum ada
nggak akan pernah kebikin.

> Catatan: di CI & database bersih, penjaga ini nggak ngapa-ngapain. Dia cuma
> bekerja di database yang terlanjur kena.

## 2. Kolom `thermohygro` nyasar — `GET /calibrations` mati 500 buat semua orang

Ini yang paling parah dan paling sunyi.

Tabel `calibration_sessions` punya kolom teks `thermohygro` yang **nggak ada di
migrasi mana pun** — sisa skema lama, sebelum thermohygro jadi relasi. Di Eloquent
atribut menang atas relasi kalau namanya sama, jadi `$sesi->thermohygro` balikin
`"TH-3"` (string), bukan model `Standard`. Akibatnya:

- `CalibrationResource:138` → "Attempt to read property id on string" → **500**
- `CalibrationSession::statusStandar()` → `TypeError` di closure `fn (Standard $s)`
- `PerhitunganBuilder:55` → `$sesi->thermohygro?->nama` di atas string

Dan **semua test tetap hijau**, karena database test dibangun dari migrasi yang
memang nggak punya kolom itu.

Yang diubah:

- Migrasi baru `2026_07_29_090000_drop_kolom_thermohygro_lama_di_calibration_sessions_table`
  — dijaga `hasColumn`; nilai lamanya dicocokkan dulu ke `standards.nama` dan
  disimpan ke `thermohygro_standard_id`, baru kolomnya dibuang. Yang nggak ketemu
  pasangannya ditinggal null (lebih baik kosong daripada nunjuk standar salah).
- `CalibrationSession::statusStandar()` — `->filter()` polos diganti
  `->filter(fn (mixed $s) => $s instanceof Standard)`. Bukan tambalan buat bug di
  atas (itu udah beres sama migrasinya), tapi karena `map(fn (Standard $s))` di
  bawahnya bertipe keras: satu isian nyeleneh mestinya bikin satu baris kosong,
  bukan seluruh daftar sesi mati.

## 3. Seeder belum pernah jalan di database ini

`standards` cuma 5 baris — `TH-1..TH-7` dari `ThermohygroSeeder` nggak ada, itu
sebabnya `TH-3` masih nyangkut sebagai teks. `calibration_methods`, `rooms`,
`formulas` juga 0 baris.

`php artisan db:seed` udah dijalanin. Semua seeder pakai `updateOrCreate`, jadi
3 sesi + 45 pembacaan + 3 sertifikat yang udah ada nggak kembar dan nggak hilang.

**`rooms` masih 0** — belum ada seeder-nya, dan di mobile juga belum ada layar
master data Ruangan (celah yang udah tercatat di audit paritas). Belum nahan apa-apa
sekarang: sesi lab jalan pakai `lokasi=lab` tanpa `room_id`.

## 3b. Tabel `folders` bentuk lama — sertifikat nggak pernah nyampe Folder Manager

Ketahuan gara-gara nyoba pakai app: folder pelanggan kelihatan kosong terus
padahal sertifikat udah terbit.

Ini **efek samping penjaga `hasTable` di §1**. Tabel `folders` yang udah ada
duluan bentuknya lebih tua: punya `is_root`, **nggak punya `tipe` & `keterangan`**
— dua kolom yang ada di `Folder::$fillable`. Waktu `FolderOrganizer` bikin
subfolder tahun, insert-nya kena:

```
SQLSTATE[42S22]: Unknown column 'tipe' in 'field list'
```

Dan itu ketangkep `try/catch` di `GenerateCertificate` yang cuma nulis
`Log::warning` — jadi **sertifikat tetap terbit, PDF-nya ada, tapi nggak pernah
ketaut ke folder**, tanpa error yang kelihatan di mana pun. Buat admin efeknya
fatal-diam: Folder Manager satu-satunya jalan dia nyampe ke sertifikat (Riwayat
& Alur Kerja pakai `mine=true`, dan admin nggak punya sesi sendiri).

Migrasi baru `2026_07_29_110000_selaraskan_kolom_folders_yang_ketinggalan`:
nambahin `tipe` + `keterangan` kalau belum ada, lalu backfill `tipe='sistem'`
buat folder akar (kalau `manual`, folder bikinan sistem jadi bisa dihapus/direname
sembarangan padahal isinya sertifikat resmi). `is_root` sengaja dibiarin.

Sesudah migrasi + `tautkanSertifikat()` diulang: subfolder `2026` kebentuk di
bawah PT Maju Jaya, `folder_files` = 1. Kebukti juga di layar Folder Manager.

> **Pelajarannya buat penjaga `hasTable` di §1:** dia bikin `migrate` nggak mati,
> tapi dia NGGAK bikin tabel lamanya jadi bener. Tiap tabel yang keskip mesti
> dicocokin kolomnya satu-satu — `folders` ini yang pertama ketemu, dan cuma
> ketemu karena app-nya beneran dipakai.

## 4. Sertifikat: QR dicabut dari PDF, halaman verifikasi jadi mirip PDF

Permintaan langsung dari Zain.

- **QR nggak dicetak lagi di PDF.** Nggak ada kode yang dihapus — dimatikan lewat
  pengaturan organisasi `tampilkan_qr_di_pdf = false` yang emang udah kamu
  sediain. Objek gambar di PDF turun dari 2 (logo + QR) jadi 1.
- **`GET /verify/{qr_token}` sekarang ngerender `sertifikat/pdf.blade.php`**,
  bukan kartu ringkas `verifikasi/sertifikat.blade.php` lagi. Alasannya: orang
  yang nyecan QR lagi **mencocokkan** lembar di tangannya. Kalau bentuknya beda,
  nggak ada yang bisa dicocokin.
  - Sertifikat lama yang `snapshot`-nya kosong tetap pakai kartu ringkas —
    blade PDF nggak bisa dirender tanpa snapshot.
  - Ini **nggak nambah data yang kebuka**: tombol unduh PDF di halaman itu udah
    tanpa auth dari dulu (spesifikasi poin 13).
- **Service baru `App\Services\DataTampilanSertifikat`** — bahan render (logo,
  tanda tangan, QR, posisi TTD, keputusan) dipindah ke sini dari
  `GenerateCertificate`. Job dan `VerificationController` sekarang manggil yang
  sama, jadi dua jalur itu nggak bisa pelan-pelan beda. Empat method privat di
  job (`qrDataUri`, `tampilkanKeputusan`, `logoDataUri`, `tandaTanganDataUri`)
  pindah ke service, isinya nggak diubah.
- `sertifikat/pdf.blade.php` dikasih mode `$web` — cuma nambah CSS layar
  (latar abu, lembar putih, tabel bisa digeser di HP) + bilah "Terverifikasi"
  dengan tombol unduh. **Dompdf nggak pernah kena blok itu**, jadi PDF-nya
  nggak mungkin ikut berubah.

## 5. Kirim sertifikat: tiga format

`POST /certificates/{id}/kirim-email` sekarang nerima `format`: `pdf` (default),
`xlsx`, atau `tautan`.

- Migrasi `2026_07_29_100000_add_format_to_certificate_email_logs_table` — kolom
  `format` default `pdf`. Ikut dicatat karena catatan pengiriman itu bukti:
  "sudah kami kirim" beda artinya kalau yang dikirim ternyata cuma tautan.
- `xlsx` dirakit on-the-fly lewat `CertificateExcelExporter`, berkas sementaranya
  dihapus di `finally` (termasuk waktu kirim gagal).
- `tautan` sengaja tanpa lampiran; badan emailnya ganti kalimat, jadi nggak ada
  kata "terlampir" di email yang nggak punya lampiran.
- Syarat berkas dicek per format, dan pesan gagalnya spesifik (PDF belum jadi vs
  snapshot belum ada vs belum punya `qr_token`).
- Field `format` ikut di respons `riwayat-email`.

Sisi mobile-nya udah nyusul: pemilih PDF / Excel / Tautan di layar Kirim
Sertifikat, plus formatnya kelihatan di tiap baris riwayat.

## 6. `.env` lokal (nggak ikut ke repo)

`APP_URL` masih `http://192.168.1.48:8000` — IP mesin ini sekarang `192.168.1.34`.
Efeknya: `qr_payload` yang dibekukan di sertifikat nunjuk alamat yang nggak ada,
karena job jalan di CLI dan `route()` di sana jatuh ke `APP_URL`. Diubah ke
`http://192.168.1.34:8001`.

Nggak perlu ditindaklanjuti di repo — cuma catatan kalau nanti QR-nya kelihatan
salah alamat lagi di mesin lain.

---

## Cara ngetes ulang

Skrip uji rantai penuhnya ada di **repo mobile** —
`asmo_mobile/docs/skrip/e2e-ph.py`, bukan di `asmo-api/`.

> Versi pertama dokumen ini cuma nulis `docs/skrip/e2e-ph.py` tanpa nyebut repo.
> Karena dokumennya soal backend, wajar dicarinya di `asmo-api/docs/skrip/` —
> dan di situ emang nggak ada. Skripnya nembak API lewat HTTP, jadi dia nggak
> peduli dijalanin dari mana; yang perlu jelas cuma jalurnya.

```
python asmo_mobile/docs/skrip/e2e-ph.py http://127.0.0.1:8000/api sertifikat.pdf
```

**`queue:listen` nggak dibutuhin buat skrip ini lagi** — sejak approve nerbitin
sertifikat langsung (§8), rantai login→kirim→validasi→approve→unduh jalan tanpa
worker. Tapi worker **masih wajib buat panel admin Filament**: `dispatch()` masih
dipakai di `CalibrationSessionsTable:180` dan `CertificatesTable:119`.

```
php artisan queue:listen          # cuma kalau lewat panel admin Filament
```

Yang diuji berurutan: login teknisi & admin → kirim lembar kerja pH 3 titik →
cek ketidakpastian tersimpan → buka lembar perhitungan → validasi → approve →
tunggu antrean nerbitin → unduh PDF-nya. Keluarnya "SEMUA MATA RANTAI TERSAMBUNG"
atau "PUTUS DI: ...".

Hasil jalan terakhir (29 Juli, 10:0x): semua tersambung. Sertifikat
`CAL/2026/07/0003`, PDF 1,33 MB, QR verifikasi 200.

## Yang belum & bukan urusan mobile

- `QUEUE_CONNECTION=database` tapi nggak ada pekerja antrean yang jalan sebagai
  service. Kalau `queue:listen` nggak idup, **approve berhasil tapi sertifikat
  nggak pernah terbit** — dan dari sisi app kelihatannya cuma "lagi diproses"
  selamanya. Ini yang paling gampang kejadian lagi di mesin lain.
- `rooms` belum ada seeder-nya (lihat §3).

---

# Bagian 2 — sore hari (lembar kerja, perhitungan, sertifikat)

## 7. U95% NGGAK PERNAH IKUT SEBARAN PEMBACAAN — bug metrologi

Yang paling penting di dokumen ini. `GumCalculator::hitungDariKemampuan()`
ngelaporin CMC apa adanya dan **membuang Type A sepenuhnya** — komentarnya
bilang "Type A sesi cuma buat QC internal".

Efeknya: U95 di sertifikat SELALU angka yang sama buat titik yang sama,
berapa pun sebaran pembacaan teknisi. Data nyata di DB sebelum diperbaiki:

```
sesi=10 titik=4  | A=0.143527  B=0.01171611 | uc=0.01171611  U95=0.02343
sesi=10 titik=7  | A=0.101980  B=0.01055448 | uc=0.01055448  U95=0.02111
sesi=9  titik=7  | A=0.005774  B=0.01055448 | uc=0.01055448  U95=0.02111
```

Perhatikan `uc` selalu **sama persis** dengan `type_b`, dan di sesi 10 titik 4
Type A dua belas kali lebih besar dari Type B tapi nggak ngaruh sama sekali.

**Kenapa ini salah:** CMC itu ketidakpastian TERBAIK yang bisa dicapai lab pada
kondisi optimal dengan alat yang berperilaku normal (ILAC-P14). Dia nggak
nyakup perilaku alat PELANGGAN yang lagi dikalibrasi. Waktu pembacaan alat itu
berserak jauh lebih besar dari CMC — elektroda mau mati, larutan kotor —
ngelaporin ±CMC berarti nyatain presisi yang nggak pernah terjadi.

**Yang diubah:** `u_c = sqrt(u_cmc² + u_A²)`, `U = k · u_c`, **dilantai ke CMC**
supaya nggak pernah ngeklaim lebih baik dari kemampuan terakreditasi lab.

Sesudah perbaikan (titik 4.00, CMC 0.02343):

```
rapat    4.01/4.01/4.01  → A=0.00000  U95=0.02343  PASS   (= lantai CMC)
sedang   4.01/4.03/4.00  → A=0.00882  U95=0.02933  PASS
berserak 4.04/5.00/4.04  → A=0.32000  U95=0.64043  FAIL
```

Sebaran yang rapat keluar angka praktis sama kayak dulu; yang berantakan
sekarang kelihatan berantakan.

> ⚠️ **Sertifikat yang udah terbit nggak ikut berubah** — snapshot-nya beku.
> Kalau ada sertifikat yang perlu dihitung ulang, itu keputusan mutu, bukan
> keputusan teknis. Tolong diputuskan bareng sebelum ada yang nerbitin ulang.

Tiga test di `GumCalculatorTest` diperbarui (satu di antaranya dulu ngunci
perilaku yang salah dengan pembacaan `4.04, 4.04, 4.04, 5.0, 4.04`); dua test
lain (`CalibrationTest`, `GumCalculatorTest`) diarahkan ulang ke maksud
aslinya — baris CMC mana yang kepilih — bukan ke besaran U95.

## 8. Approve nerbitin sertifikat LANGSUNG, bukan lewat antrean

`CalibrationController::approve()` dulu `GenerateCertificate::dispatch()`.
Tanpa `queue:work` yang jalan, approve-nya sukses tapi sertifikatnya nggak
pernah terbit — dan dari layar admin itu kelihatan "lagi diproses" selamanya,
tanpa error di mana pun. Satu proses yang lupa dinyalain bikin seluruh alur
mati diam.

Sekarang `$job->handle()` dipanggil langsung (~1-2 detik), dibungkus `try` —
kalau gagal, job-nya sendiri udah nandain sertifikat `gagal` + ngabarin admin,
dan **approve-nya tetap sah** (mbatalin approve gara-gara PDF gagal cuma maksa
admin ngulang pemeriksaan yang udah bener).

Job-nya idempoten, jadi kalau nanti volumenya naik dan ada pekerja antrean yang
beneran diawasi, tinggal balikin ke `dispatch()`.

Empat test yang ngunci `Queue::assertPushed` diperbarui ke hasilnya
(`CertificateGenerationTest`, `MasaBerlakuSertifikatTest` ×2, `OcrMeasurementTest`).

## 9. Lembar kerja pH — `LembarKerjaTemplate` dirombak ngikut kertasnya

| Yang berubah | Dari | Jadi |
|---|---|---|
| Type/Model, Serial Number, Merk | `sumber: otomatis` (salinan master alat) | `alat_model`, `alat_serial_number`, `alat_merk` — diketik teknisi |
| OWNER Name & Address | `sumber: otomatis` (salinan master pelanggan) | `pemilik_nama`, `pemilik_alamat` — diketik teknisi |
| Thermohygro used | `hanya_admin: true` | hak teknisi, pilihan berkelompok Insitu (TH-2/6/7) & Inlab (TH-4) |
| Tabel STANDARD | `sumber: master_standar` (SELURUH katalog) | 5 baris TERCETAK, dicocokkan ke master |
| Env. Condition | di CALIBRATION DATA | pindah ke CALIBRATION RESULT (ngikut kertas) |
| Urutan bagian | identitas → owner → data → standar | identitas → owner → **STANDARD** → CALIBRATION DATA |
| — | — | tiap bagian bawa `halaman` (1 atau 2) |

Migrasi `2026_07_29_120000` nambah 5 kolom di `calibration_sessions`. Sengaja
nggak numpang ke `equipments`/`customers`: master itu punya admin dan sering
beda sama unit fisik yang beneran datang. `CertificateSnapshotBuilder`
ngutamain isian teknisi, master cuma cadangan (`??` per field).

`thermohygro_standard_id` dikeluarkan dari `CalibrationSession::fieldAdmin()`.
**Perhatikan jebakannya:** waktu dikeluarkan dari situ, dia ikut hilang dari
daftar `$opsional` di `atributDariRequest()` — kolomnya lolos validasi tapi
nggak pernah nyampe database. Sekarang disebut eksplisit.

`CalibrationResource` ikut ngirim balik kelima kolom itu — mobile ngisi ulang
formulirnya dari sini waktu sesi dikembalikan buat revisi. Tanpa itu teknisi
ngetik ulang semuanya cuma buat mbenerin satu hal.

## 10. Kirim sertifikat lewat WhatsApp

`POST /certificates/{id}/catat-whatsapp` — **server nggak ngirim apa-apa**.
Pesannya dikirim dari HP admin lewat `wa.me`; endpoint ini cuma nyatet jejaknya
(`format: whatsapp`, status selalu `terkirim`).

Kenapa tetap dicatat: waktu pelanggan ngaku nggak nerima, yang ditanya "kapan
dikirim, ke nomor mana, sama siapa" — dan itu nggak bisa dijawab kalau jejaknya
cuma ada di HP satu orang.

`CertificateResource` sekarang ikut ngirim blok `pelanggan` (nama, email,
telepon) biar layar bisa nampilin tombol yang tepat tanpa nebak nomor sendiri.
`RELASI`-nya jadi `session.equipment.customer`.

## Status test sesudah semua ini

**595 dari 597 lolos.** Dua yang gagal (`DashboardTrenTest`) **udah gagal
sebelum semua perubahan ini** — dibuktikan dengan `git stash`. Bug tanggal di
grafik tren: bawaannya 6 bulan tapi yang kebentuk 5.

## 11. Nolak lembar kerja: catatan + kode kolom

Migrasi `2026_07_29_130000` nambah `revisi_field` (JSON, nullable) di
`calibration_sessions`. `POST /calibrations/{id}/reject` sekarang nerima
`revisi_field: ["alat_serial_number", "suhu_awal"]` di samping
`catatan_revisi` yang udah ada.

Kenapa dua-duanya, bukan salah satu: prosa bagus buat manusia tapi nggak bisa
dipakai mesin — teknisi yang nerima "serial number nggak kebaca, env condition
juga kosong" tetap harus nyisir sendiri formulirnya nyari dua kolom itu di
antara puluhan kolom lain. Kode doang kehilangan alasannya, dan "kenapa" itu
yang bikin teknisi nggak ngulang kesalahan yang sama minggu depan.

`revisi_field` **sengaja nggak divalidasi terhadap daftar kolom yang ada**.
Yang ngirim itu layar admin yang bentuk formulirnya juga dari backend, jadi kode
asing artinya formulirnya berubah — dan kalau itu bikin 422, admin keblokir
nolak gara-gara hal yang bukan urusannya. Efek terburuk dari kode yang nggak
dikenal cuma: nggak ada kolom yang kesorot, prosanya tetap kebaca.

`CalibrationResource` ngirim balik `revisi_field` (array, `[]` kalau kosong).

---

# Bagian 3 — kamera, antrean, sertifikat

## 12. Kamera jalan — lewat Gemini

Penyedia AI-nya sekarang bisa diganti: `VISION_DRIVER=anthropic|gemini` di
`.env`. Prompt, few-shot, skema, dan normalisasi barisnya **dipakai bareng** —
yang beda cuma cara ngomong ke servernya. Ganti penyedia nggak ngubah apa pun
yang nyampe ke lembar kerja teknisi, dan lab nggak kekunci ke satu vendor.

Sekarang jalan pakai `gemini-3.6-flash`. Diuji dengan gambar tabel 3 titik ×
3 Repeat — semua 18 angka kebaca persis.

**Dua bug ketemu waktu nyambungin, dua-duanya bisa ngerusak sertifikat:**

1. **Parser cuma nyari `{`...`}`.** Gemini sering balikin array telanjang
   `[...]`. Hasil yang isinya SUDAH BENAR kebuang sebagai "tidak bisa dibaca",
   dan teknisi disuruh ngetik ulang tabel yang barusan kebaca sempurna.
   Sekarang objek maupun array dua-duanya kebaca; array dibungkus balik ke
   bentuk yang sama sebelum masuk normalisasi.

2. **Prompt-nya nyuruh baris kosong DIHAPUS** ("If a whole Repeat row is
   missing from the photo, omit it") — padahal posisi array dipakai sebagai
   nomor Repeat di hilir. Satu baris yang kelewat bikin pembacaan Repeat 3
   mendarat di slot Repeat 2, di dokumen kalibrasi, tanpa ada yang kelihatan
   salah. Sekarang: baris kosong tetap dikirim dengan nilai null, plus nomor
   `repeat` eksplisit yang dipakai buat ngurutin.

`phpunit.xml` matok `VISION_DRIVER=anthropic` — waktu `.env` dev dipindah ke
Gemini, delapan test Anthropic langsung pecah karena nembak host yang nggak
difake. Test nggak boleh ikut berubah tiap ada yang ganti setelan lokal.

Test baru: `WorksheetExtractionGeminiTest` (7 test).

> ⚠️ Kunci Gemini-nya sempat lewat chat waktu dikasih ke saya — Zain diminta
> muter/ganti kuncinya di Google Cloud Console. Kuncinya ada di `.env`, bukan
> di kode.

## 13. Antrean approval dikelompokkan per PT

`CalibrationResource` sekarang ikut ngirim blok `pelanggan` (id + nama).
`pemilik_nama` isian teknisi menang atas master — sama kayak di sertifikat,
biar nama yang dilihat admin di antrean sama dengan yang bakal kecetak. Kalau
beda, admin mikir itu dua PT.

`RELASI` di `CalibrationController` jadi `equipment.customer` (bukan
`equipment`) supaya nggak N+1 per baris antrean.

## 14. Sertifikat: label ditebalkan, nama & departemen dibenerin

- Label di header sertifikat (`table.info td.lbl`) jadi tebal & lebih gelap.
  Label abu tipis bikin mata balik-balik nyari mana nama kolom mana isinya.
- `DatabaseSeeder`: nama akun dev diganti jadi nama orang (`Rina Kartika`,
  `Dimas Rahardjo`, `Sari Wijaya`) — "Admin SIDIK" kecetak sebagai
  penandatangan sertifikat dan itu kelihatan kayak placeholder.
- Departemen `Kalibrasi` → `Calibration`, biar seluruh footer sertifikat satu
  bahasa.

Buat produksi, `penandatangan_nama` & `penandatangan_jabatan` di pengaturan
organisasi tetap yang menang — nama di seeder ini cuma cadangan buat dev.

## 15. Halaman QR: tabel nyusut gara-gara `display: block`

Waktu bikin mode `$web` (§4), tabel hasil & standar dikasih
`display: block; overflow-x: auto` biar bisa digeser di HP. Efek sampingnya
nggak kelihatan sampai dilihat di layar lebar: `display: block` bikin
`width: 100%`-nya tabel nggak berlaku lagi, jadi tabelnya nyusut selebar
isinya doang dan nyempil di kiri.

Sekarang: lebar penuh di layar lebar, geser-horizontal cuma di `@media
(max-width: 720px)`. Di layar sempit, header info (16 field, dua pasang
label→nilai bersebelahan) juga dilipat jadi SATU kolom — dipaksa muat di 360px
tiap sel jadi setumpuk kata terpotong.

## 16. Kirim sertifikat lewat WhatsApp: PDF, Excel, atau tautan

`POST /certificates/{id}/catat-whatsapp` sekarang nerima `format` dan balikin
`pesan` — teks siap-tempel yang isinya tautan sesuai format:

| format | tautan |
|---|---|
| `pdf` | `/verify/{token}/download` |
| `xlsx` | `/verify/{token}/download?format=xlsx` |
| `tautan` | `/verify/{token}` (halaman verifikasi) |

Pesannya disusun DI BACKEND, bukan di mobile: tautannya nempel ke `qr_token`
dan skema URL yang cuma backend yang tahu. Kalau mobile nyusun sendiri, satu
perubahan rute bikin pelanggan nerima tautan mati — dan ketahuannya sesudah
pesannya kekirim.

Ketiga tautan itu tanpa auth (pelanggan nggak punya akun); yang jagain tetap
`qr_token` — 10 karakter acak, bukan id berurutan.

Di `certificate_email_logs`, formatnya tetap dicatat `whatsapp`: yang perlu
bisa dijawab waktu pelanggan ngaku nggak nerima itu "lewat mana", dan itu yang
paling ngebedain.

## Yang SUDAH ada dan diverifikasi (bukan pekerjaan baru)

- **Folder teknisi terbatas** — `ScopesFolderAccess` udah bener: teknisi cuma
  lihat file dari sesinya sendiri + yang dia unggah, dan folder yang isinya
  kosong buat dia nggak ditampilin. Dibuktikan: admin lihat 3 folder PT,
  teknisi lihat 2 (PT Karya Logam disembunyiin karena nggak ada kerjaannya).

## Yang BELUM

- **Alat & berkas lain milik PT masuk ke folder PT-nya.** Sekarang baru
  sertifikat yang otomatis ketaut. Ini fitur baru, bukan perbaikan — perlu
  diputuskan dulu bentuknya (subfolder per alat? berkas apa aja yang masuk?).

---

## Adendum backend 29 Juli — hasil cek di sisi mobile

Tiga hal yang adendum backend minta dicek di frontend. **Dua nggak butuh
perubahan kode**, dan alasannya di bawah — bukan "kelihatannya aman", tapi dicek
ke kodenya.

### 1. Grafik tren 5 → 6 bulan: aman, nol perubahan

Penyebabnya `subMonths()` yang overflow dari tanggal ujung bulan, diperbaiki di
`DashboardController::awalDefault()`. Sisi mobile nggak kena karena
`WorkChart` **nggak pernah tau ada angka 6**:

```dart
final lebarSlot = size.width / titik.length;   // lib/widgets/work_chart.dart:132
for (var i = 0; i < titik.length; i++) { ... }
```

Lebar batang, jumlah batang, dan posisi label semuanya turunan `titik.length`.
Dikasih 5 titik dia gambar 5, dikasih 6 dia gambar 6 — nggak ada konstanta
jumlah bulan di sisi mobile, dan nggak ada golden test yang ngunci 5 batang.

Jadi kalau dulu grafiknya kelihatan cuma 5 bulan, itu **beneran datanya cuma 5**,
bukan batang keenam yang kepotong layout. Nggak ada yang perlu disesuaikan.

### 2. Retry sertifikat: udah bener, dan tambalannya yang nyelametin

Kondisi tombolnya:

```dart
} else if (sertifikat.status == 'gagal') ...[   // certificate_screen.dart:176
```

Ini **cuma jalan** karena tambalan retry di adendum §3. Sebelum ditambal,
`retry()` nge-set status ke `menunggu_generate` sebelum dispatch — dan dari sisi
mobile itu berarti tombolnya ilang selamanya begitu dipencet tanpa worker,
karena `menunggu_generate` nggak masuk cabang `== 'gagal'`. Sertifikat yang
gagal jadi nggak bisa disentuh lagi dari aplikasi.

Sekarang statusnya selalu mendarat di keadaan akhir, jadi gagal-dua-kali tetap
munculin tombolnya. **Nggak ada perubahan mobile yang dibutuhin** — yang rusak
tadinya di backend, dan udah beres di sana.

Soal polling: `_retryGenerate()` nggak nge-poll, cuma sekali
`ref.invalidate(calibrationDetailProvider(...))` sesudah requestnya balik. Bisa
memang dihemat jadi baca `data.status` langsung dari respons retry, tapi
`invalidate` sekalian nyegerin `pdf_url` dan field lain di layar itu — nuker satu
request hemat sama kemungkinan layar nampilin data campur baru-lama itu nggak
sepadan. **Sengaja dibiarin.**

### 3. Skrip e2e: kesalahan dokumen ini, udah diperbaiki

Lihat "Cara ngetes ulang" di atas. Skripnya nggak hilang — ada di repo mobile
sejak awal, dokumennya yang nggak nyebut repo mana. Sekarang jalurnya ditulis
lengkap.

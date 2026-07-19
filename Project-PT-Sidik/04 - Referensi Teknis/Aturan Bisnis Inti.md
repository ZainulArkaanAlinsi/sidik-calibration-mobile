# Aturan Bisnis Inti

🏠 [[Dashboard]]

Ringkasan aturan yang wajib dipegang selama coding. Diadaptasi dari fondasi teknis project kalibrasi sebelumnya (CertiCal) yang domainnya sama.

## Penomoran & Penerbitan Sertifikat
- Format nomor: `CAL/{tahun}/{bulan}/{urutan 4 digit}`, unik per organisasi
- Nomor dijamin nggak dobel lewat **database transaction locking**, bukan cuma unique constraint doang
- Sertifikat yang sudah terbit **tidak bisa diedit langsung** — revisi harus lewat entry baru yang terhubung ke sertifikat asal
- Tiap sertifikat punya QR code berisi payload terenkripsi AES-256, dipakai buat endpoint verifikasi publik (tanpa login)

## Perhitungan & Validasi Hasil Kalibrasi
- Ketidakpastian pengukuran dihitung pakai metodologi **GUM**: Type A + Type B uncertainty → combined uncertainty → dikali faktor cakupan k → expanded uncertainty (`U = k × u_c`)
- Setiap sesi kalibrasi **wajib** memilih **Standar Acuan** (`standard_id`) — ketidakpastiannya jadi komponen Type B terbesar. Sesi tanpa ini ditolak backend (`422`)
- Standar yang sertifikatnya sudah kadaluarsa (`masih_berlaku: false`) **tidak boleh** dipakai buat kalibrasi baru — ketertelusurannya putus
- Alat yang `toleransi`-nya masih kosong ditolak — tanpa batas keberterimaan, PASS/FAIL nggak ada artinya. Harus diisi dulu lewat edit alat
- Tiap titik ukur **minimal 2 pembacaan** — Type A butuh sebaran nilai antar-pengulangan, dari satu angka nggak ada standar deviasi yang bisa dihitung
- Keputusan PASS/FAIL mengacu ke decision rule **ILAC-G8** dengan *guarded acceptance*, **bukan** sekadar `|error| ≤ toleransi`:
  ```
  PASS  jika  |error| + U ≤ toleransi
  FAIL  jika  |error| + U >  toleransi
  ```
  Ketidakpastian pengukuran ikut diperhitungkan — alat yang errornya mepet batas toleransi bisa tetap FAIL walau kelihatannya "masih masuk toleransi" kalau dihitung pakai rumus sederhana
- **Satu titik ukur FAIL membuat seluruh sesi kalibrasi FAIL** — hasil yang ditampilkan di sertifikat adalah titik yang paling mepet ke batas (`|error| + U` terbesar), bukan titik pertama
- Semua perhitungan ini **dihitung di backend** — mobile cuma menampilkan hasil (`hasil`, `titik`), tidak menghitung ulang apa pun
- Hasil kalibrasi yang gagal (FAIL) tetap tersimpan dan tetap bisa diterbitkan sertifikatnya — statusnya aja beda, bukan berarti nggak boleh ada sertifikat

## Peran & Akses
- 3 role: **admin** (semua akses), **teknisi** (input alat & kalibrasi, no user management), **viewer** (read-only)
- Cuma admin yang bisa: kelola pengguna, kustomisasi template sertifikat, pengaturan aplikasi

## Input Kalibrasi via Kamera (OCR)
- Kamera **mempercepat input**, bukan menggantikan verifikasi manusia
- Selalu ada layar **review & edit** sebelum data final tersimpan — field yang gagal terbaca/kosong wajib dilengkapi (manual atau retake foto) sebelum bisa lanjut
- Data yang sudah dikonfirmasi masuk ke pipeline yang **sama persis** dengan input manual — nggak ada jalur terpisah

## Data & Retensi
- Data kalibrasi & sertifikat sebaiknya disimpan minimal 5 tahun (kebutuhan audit)

---
Lihat juga: [[Data Kemampuan Kalibrasi]] untuk batas rentang ukur & ketidakpastian per kategori alat, dan `docs/kontrak-api.md` (repo mobile) §4 untuk contoh angka & bentuk JSON lengkapnya.

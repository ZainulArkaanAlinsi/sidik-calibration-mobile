# Panduan Mengisi Lembar Kerja Viscometer

Untuk teknisi & admin yang memakai aplikasi di lapangan. Formulir
`SIDIK-FM-CAL-0524_Rev.3`, metode `SIDIK-IK-CAL-0517_Rev.3`.

Alat ini berbeda dari enam alat sebelumnya dalam tiga hal yang semuanya masuk ke
angka sertifikat. Membacanya sekali di awal menghemat pengulangan kerja nanti.

---

## 1. Dua tombol kamera, dan keduanya bukan hal yang sama

Ini sumber kebingungan yang paling sering. Aplikasi punya dua jalur foto:

| Tombol | Yang difoto | Kapan dipakai |
|---|---|---|
| **FOTO TABEL INI** | Satu tabel saja (Before / After), dari formulir apa pun — termasuk kertas lab yang sudah biasa dipakai | Jalur harian. Tersedia sekarang. |
| **Pindai Lembar** | Satu lembar penuh bermarker, hasil cetak `ocr:cetak-lembar` | Belum aktif untuk Viscometer — lihat bagian 6 |

Kalau tombol "Pindai Lembar" mati atau menolak, itu **bukan** kerusakan: geometri
lembar Viscometer belum diukur dari kertas cetak asli. Yang dipakai sehari-hari
sekarang **FOTO TABEL INI**.

---

## 2. Yang harus ikut masuk frame saat memotret tabel

Aplikasi tidak pernah menebak posisi angka dari urutan. Setiap angka wajib punya
dua penanda sebelum ditaruh, dan penandanya adalah tinta yang tercetak di tabel
itu sendiri. Kalau salah satu tidak ikut terfoto, seluruh tabel ditolak — bukan
diisi sebagian.

Yang **wajib** kelihatan dan tidak terpotong:

1. **Kolom Standard di kiri** — angka `100`, `1000`, `60000`. Ini penanda baris.
2. **Kepala kolom Repeat** — deretan `1 2 3 4 5` lengkap di bawah tulisan
   `UUT Reading`. Kurang satu nomor saja, seluruh tabel batal. Ini disengaja:
   empat kolom terjangkar dan satu tidak jauh lebih berbahaya daripada nol,
   karena angka kolom yang hilang akan tertarik ke kolom tetangga.
3. **Baris satuan** — `cP` dan `°C` di kepala tabel. Keduanya, bukan salah satu.
   Tanpa `cP`, seluruh pembacaan bisa mendarat di kolom suhu dengan rapi tanpa
   ada yang terlihat salah.

Kalau aplikasi menolak, pesannya menyebut yang hilang. Ikuti pesan itu — memotret
ulang dengan cara yang sama tidak akan menolong.

> Semua kolom tetap bisa diketik manual. Kamera itu jalan pintas, bukan syarat.

---

## 3. Mengisi tabel hasil

Setiap sel pembacaan **berpasangan dengan sel suhu**, dan sel suhu itu bukan
pelengkap. Nilai acuan larutan bergerak tajam mengikuti suhu: larutan 60000 cP
bernilai 95192 cP pada 20 °C dan 19259 cP pada 37,78 °C — turun 80 % dalam 18
derajat. Suhu yang tidak diisi berarti nilai acuannya jatuh ke nominal botol, dan
koreksinya salah.

- Isi `cP` dan `°C` berpasangan, per Repeat.
- Angka ditulis apa adanya sesuai yang terbaca di layar alat. Jangan dibulatkan
  sendiri, jangan digeser komanya.
- Kolom yang belum bisa diisi di lapangan boleh dikosongkan — lembar tetap bisa
  dikirim.

### Angka yang terbaca aneh

Kalau hasil foto menampilkan sesuatu seperti `631.74.2` (dua titik desimal),
aplikasi menandainya merah dan **tidak** menebaknya menjadi `631,74` atau
`63174,2`. Ketik ulang dari kertas. Menebak berarti memasukkan angka karangan ke
dokumen terakreditasi.

---

## 4. Spindle & RPM — dua kotak yang menentukan lulus atau tidak

Berbeda dari enam alat lain, Viscometer tidak punya satu angka toleransi di data
alat. Batas keberterimaannya dihitung per titik:

```
Fullscale = TK × SMC × 10000 / RPM
MPE       = 1 % × Fullscale + 1 % × rata-rata pembacaan
```

Artinya:

- **Model viscometer** (bagian "Model Viscometer") menentukan `TK`. Dipilih
  sekali per sesi. Tidak dipilih → MPE tidak ada → sertifikat terbit **tanpa
  vonis PASS/FAIL**.
- **Spindle** menentukan `SMC`, **RPM** menentukan kecepatan — keduanya **per
  titik**, bukan sekali untuk satu lembar. Sesi contoh master memakai tiga
  spindle berbeda dengan dua kecepatan dalam satu lembar.

Keduanya **dipilih dari daftar, bukan diketik dan bukan difoto**. Rentang SMC
0,327 sampai 1280 — satu salah pilih menggeser Fullscale ribuan kali. Kode
spindle berbentuk `HA7`, `CPE-51 or CPA-51Z`, `LV4 or 4B2`; pembaca angka
kamera hanya mengenal digit, jadi sel semacam itu akan selalu merah.

Titik yang Spindle atau RPM-nya kosong tetap dihitung `U95%`-nya, tapi tidak
mendapat vonis. Lembar tidak gagal karenanya — yang kosong dilaporkan sebagai
kosong.

---

## 5. Yang dihitung backend, bukan diisi tangan

Jangan menghitung apa pun sendiri lalu mengetikkan hasilnya. Semua ini datang
dari server setelah lembar dikirim:

- Rata-rata, STDEV, koreksi
- Nilai acuan pada suhu terukur (interpolasi tabel sertifikat larutan)
- Ketidakpastian `uc`, `veff`, faktor cakupan `k`, `U95%`
- MPE dan vonis PASS/FAIL

Nilai `Standard` yang tercetak di sertifikat **bukan** angka `100`/`1000`/`60000`
yang ada di lembar kerja. Yang di lembar kerja itu nominal botol; yang di
sertifikat hasil interpolasi pada suhu terukur titik itu. Keduanya benar, dan
keduanya bukan hal yang sama.

---

## 6. Yang belum selesai

**Pindai Lembar (lembar penuh bermarker) belum aktif.** Berkas geometrinya masih
`terverifikasi: false`, dan selama itu server menolak seluruh pindai untuk alat
ini. Ini penjaga yang disengaja: koordinat yang meleset sedikit membuat angka
mendarat di baris sebelah tanpa gejala apa pun.

Urutan menyelesaikannya:

1. `php artisan ocr:cetak-lembar viscometer` — cetak lembar bermarker
2. Isi dengan tangan, lalu foto dengan HP
3. Ukur koordinat sel sebenarnya dari foto itu, perbaiki angkanya di
   `database/ocr-templates/viscometer-v1.json`
4. Adu ulang ke beberapa foto nyata
5. Baru setel `"terverifikasi": true`

Sampai langkah itu selesai, pakai **FOTO TABEL INI**.

**Blok larutan 30000 cP tidak dibangun.** Tercetak di kertas Rev.3, tapi seluruh
budgetnya `#DIV/0!` di workbook master — sumber angkanya sudah hilang dari
workbook itu sendiri. Menurut `FORM VALIDASI` rev.18 larutan itu sudah diganti
1000 cP.

Lima hal lain yang menunggu jawaban lab tercatat di
`sidik-calibration-api/docs/pertanyaan-lab-viscometer.md`.

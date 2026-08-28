# Pengenal angka sel — model sendiri, ditanam di aplikasi

Melatih model kecil yang membaca angka tulisan tangan di sel lembar kerja,
lalu mengekspornya ke `.tflite` supaya bisa ditanam di aplikasi **tanpa API
key dan tanpa kirim citra ke mana pun**.

## Statusnya sekarang — baca ini dulu

**Belum ada model yang layak dipakai di lapangan, dan tidak akan ada sampai
data aslinya terkumpul.**

Yang sudah jadi di sini itu **pipeline**-nya: bentuk masukan, arsitektur,
pelatihan, ekspor TFLite, dan pengukuran. Semuanya sudah dibuktikan jalan
dari ujung ke ujung — memakai data **sintetis**, yaitu digit MNIST yang
dirangkai jadi angka bergaya lembar kerja (`9000,5`).

Buktinya, dari latihan 15 epoch atas 20 ribu contoh:

| yang diukur | skor |
|---|---|
| Keras, 2000 sel uji | 92,6% sama persis |
| **TFLite terkuantisasi, 500 sel segar** | **92,8% sama persis** |

Angka kedua yang berarti: itu **berkas 255 KB yang benar-benar ditanam di HP**,
sudah lewat kuantisasi, diuji pada sel yang goresannya belum pernah dilihat
sama sekali. Kuantisasi ternyata tidak memakan ketelitian.

> Angka ini pernah terbaca 96,2%. Itu salah, dan sebabnya layak diingat: data
> latih dan uji sama-sama menimba goresan dari belahan MNIST yang sama. Dua
> puluh ribu angka × ~3,5 karakter itu ~70 ribu tarikan dari 60 ribu gambar,
> jadi goresan yang sama pasti muncul di kedua sisi. Rangkaiannya beda,
> tulisannya tidak. Kebocoran itu menghadiahi 3,6 poin gratis.

### Salahnya di mana

Hampir semuanya **karakter yang hilang**, bukan karakter yang ketukar:

    761,6   -> 76,6        55,06 -> 5,06        2,5   -> ,5
    513,62  -> 51,62       32,8  -> 3,8        -52,4  -> -5,4

`55,06 -> 5,06` itu kegagalan CTC yang paling khas: karakter kembar yang
berdempetan butuh blank di antaranya, dan kalau modelnya tidak mengeluarkan
blank itu, keduanya melebur jadi satu. Makin panjang angkanya makin sering
salah — 4% di tiga karakter, 11% di tujuh.

Yang perlu digarisbawahi: sel yang salah baca begini **kelihatan wajar**.
`513,62` yang terbaca `51,62` bukan angka rusak, dia angka yang sah tapi keliru.
Itu sebabnya rencana di bawah menaruh ambang keyakinan yang MENGOSONGKAN sel
waktu ragu, bukan menebak.

Model dari data sintetis **tidak bisa membaca lembar kerja Anda.** MNIST itu
tulisan tangan orang lain, ditulis di kondisi lain, dengan gaya lain. 92,8% di
atas mengukur seberapa baik model membaca **digit MNIST yang dirangkai** — dan
itu bukan ramalan sama sekali buat angka tulisan teknisi di kertas berfoto.
Yang dibuktikan cuma bahwa jalurnya benar — bukan bahwa pembacaannya benar.

Karena itu tiap model membawa `asal_data` di `meta.json`, dan sisi aplikasi
**menolak memakai model bertanda `sintetis`** kecuali dinyalakan eksplisit.
Model bootstrap yang diam-diam sampai ke tangan teknisi lebih berbahaya
daripada tidak ada model sama sekali: angkanya kelihatan wajar, tidak ada yang
merah, dan tidak seorang pun tahu itu tebakan.

## Dari mana data aslinya datang

Aplikasi sudah mengumpulkannya sendiri. Tiap kali teknisi memotret tabel lalu
menekan **Simpan**, potongan tiap sel disimpan bersama angka yang akhirnya
dia ketik — lihat `lib/services/simpanan_contoh_sel.dart`.

Labelnya gratis: teknisi memang sudah mengetik angkanya. Yang paling berharga
justru sel yang OCR-nya **salah atau kosong**, karena di situlah model
sekarang gagal.

Simpanannya ada di folder privat aplikasi (`contoh_sel/`), berisi PNG per sel
plus `indeks.jsonl`.

> **Mengeluarkannya dari HP butuh keputusan eksplisit pemilik lab.** Aturan
> privasi proyek ini menyatakan citra lembar kerja pelanggan tidak pernah
> keluar perangkat. Belum ada satu baris pun jalur ekspor yang dibangun.
>
> Yang meringankan keputusannya: potongan sel **bukan** lembar kerja. Kotaknya
> diturunkan dari jangkar baris & kolom, jadi yang tersimpan cuma sel
> pengukuran — kop surat, nama pelanggan, dan nomor sertifikat tidak pernah
> ikut terpotong. Indeksnya pun sengaja tidak menyimpan id sesi maupun
> identitas apa pun.

## Cara pakai

```bash
python3 -m venv venv && ./venv/bin/pip install tensorflow-cpu pillow

# Bootstrap — membuktikan pipeline-nya jalan, BUKAN buat produksi
./venv/bin/python latih.py --sintetis --epoch 15

# Kalau data asli sudah ada
./venv/bin/python latih.py --dari /path/ke/contoh_sel --epoch 30
```

Keluarannya di `keluaran/`:

| berkas | isinya |
|---|---|
| `pengenal_angka.tflite` | modelnya, siap ditanam (~255 KB) |
| `meta.json` | alfabet, ukuran masukan, `asal_data`, dan skor ujinya |

Uji penguraian CTC-nya jalan sendiri, tanpa TensorFlow, dalam hitungan detik:

```bash
python3 uji_pecahkan.py
```

Selama dia hijau, skor 0% berarti modelnya yang belum belajar — bukan
pembacanya yang rusak. Dua gejala itu kelihatan sama persis dari luar.

## Bentuk modelnya, dan kenapa begitu

**CTC, bukan klasifikasi per digit.** Sel berisi angka multi-digit yang
ditulis rapat; memisahkannya jadi karakter satu-satu justru bagian yang paling
sering gagal. CTC membuat pemisahan tidak pernah perlu dilakukan.

**Konvolusi saja, tanpa LSTM.** LSTM sering rewel waktu dikonversi ke TFLite,
dan kegagalannya muncul di ujung — sesudah semuanya kelihatan jalan. Model
konvolusi murni juga jauh lebih ringan di HP. Yang hilang cuma konteks jarak
jauh, dan angka enam karakter tidak membutuhkannya.

**Masukan 32×160 grayscale, keluaran 80 langkah waktu × 13 kelas** (12 huruf
`0123456789,-` plus blank milik CTC). Delapan puluh langkah untuk enam
karakter itu ruang yang lega buat CTC menyelaraskan.

## Yang diukur, dan kenapa bukan loss

`sama_persis` — berapa persen sel yang dibaca **persis benar**.

Sel kalibrasi itu benar atau salah, tidak ada nilai tengah. Angka yang "90%
mirip" tetap angka yang salah, dan di lembar kalibrasi angka yang salah lebih
berbahaya daripada sel kosong: yang kosong kelihatan.

## Rencana sesudah data asli ada

1. Latih dari data asli, ukur `sama_persis` per jenis lembar.
2. Pasang sebagai implementasi kedua `PembacaSel` di aplikasi — seam-nya sudah
   ada, `MlKitPembacaSel` implementasi pertama.
3. **Mode bayangan dulu:** model membaca, hasilnya **tidak dipakai**, cuma
   dibandingkan diam-diam dengan angka yang diketik teknisi.
4. Naikkan jadi pembaca sungguhan hanya kalau angkanya sudah pantas — dan
   dengan ambang keyakinan yang **mengosongkan** sel waktu ragu, bukan
   menebak.

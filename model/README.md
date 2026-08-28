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

Model dari data sintetis **tidak bisa membaca lembar kerja Anda.** MNIST itu
tulisan tangan orang lain, ditulis di kondisi lain, dengan gaya lain. Yang
dibuktikan cuma bahwa jalurnya benar — bukan bahwa pembacaannya benar.

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
| `pengenal_angka.tflite` | modelnya, siap ditanam |
| `meta.json` | alfabet, ukuran masukan, `asal_data`, dan skor ujinya |

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

# Pindai Lembar Kerja — sisi HP (OCR lokal, tanpa AI berbayar)

Kontrak lengkapnya `docs/SPEC-ocr-template-lokal.md` di repo `sidik-calibration-api`.
Berkas ini cuma peta sisi Flutter-nya: mana yang ngerjain apa, dan mana yang
**belum** selesai.

Jalur AI Vision yang lama (`worksheet_vision.dart` + tombol "FOTO TABEL INI —
DIBACA AI") **sudah dicabut dari aplikasi** per 14 Agustus 2026. Endpoint
`POST /api/raw-measurements/extract-from-photo` masih hidup di backend dan
sengaja tidak disentuh — keputusan mematikannya ada di lab.

## Alur foto LINEAR (18 Nov 2026 satu pintu, 19 Nov 2026 linear)

Foto lembar punya satu pintu: "Pindai lembar kerja" di beranda
(`lib/screens/pindai/pindai_lembar_flow.dart`). Urutannya:

1. Foto -> ML Kit membaca halaman di HP (putaran 0/90/180/270) ->
   `identifikasiLembar` (kode, judul, revisi). Teks halaman yang SAMA (elemen +
   kotaknya, putaran yang kertasnya tegak) dipakai membaca identitas kertas;
   tidak ada pembacaan kedua.
2. `putuskanPindaiLembar` (`lib/services/keputusan_pindai_lembar.dart`):
   - kode formulir UNIK + terbaca bersih + skor >= 0,90 + jenisnya boleh
     dipindai = lembar terbuka SENDIRI;
   - kandidat lebih dari satu (kode bersama 0504 dst., bacaan samar,
     kode-judul bertentangan) = lembar ringkas "Pilih salah satu", SATU ketukan;
   - tidak yakin / tidak terbaca / kode tak dikenal = pesan jujur (Foto ulang,
     Jenis lain, atau "Mulai kalibrasi"), tanpa tebakan.
3. TIDAK ADA alat yang dipilihkan (sejak 19 Nov 2026). Dulu alur memilih alat
   terdaftar dari daftar `GET /equipments?profil=` lalu menyalin identitas dan
   pemiliknya ke lembar SEBELUM kertas dibaca; sekarang yang berlaku yang
   TERTULIS di kertas.
4. `LembarKerjaScreen(dariFoto:)` membaca foto yang SAMA sendiri (tanpa kamera
   kedua, tanpa dialog, tanpa menunggu alat); kode formulir yang terbaca ikut
   ke server sebagai `kode_dokumen` (`GET /worksheet-templates/{kode}?kertas=asli`)
   supaya peta varian benar tanpa alat. Hasil lewat layar periksa, sel terisi
   KUNING (saran). Banner "Dikenali otomatis: ... Salah? Ganti jenis" selalu
   ada. Gagal baca = pesan saja; "Foto ulang" = satu tombol kecil di lembar.
5. Blok identitas di atas lembar (`blok_identitas_foto.dart`): identitas kertas
   (`identitas_kertas.dart`: Nama Alat, Merk, Type/Model, Serial Number/LPI,
   ID alat, Owner/Pelanggan, Address, Lokasi, tanggal; jangkar label cetak,
   layout-agnostik) masuk kotak lembar sebagai saran KUNING yang ikut gerbang
   wajib-cek; yang tidak yakin dikosongkan. Lalu dicocokkan lewat nomor seri
   (`cocokkan_alat.dart`, `GET /equipments?search=`):
   - cocok PERSIS: "Alat terdaftar: ..." + selisih terhadap kertas, menunggu
     "Pakai alat ini". Kertas MENANG atas master; master hanya mengisi kotak
     yang kosong; "Pakai yang terdaftar" per baris bila teknisi memilih master;
   - MIRIP (salah baca, O/0, I/1): "Maksud Anda?" (maks 3), satu ketukan;
   - tidak ada: panel inline "Alat baru" terisi dari kertas, tombol "Buat dan
     lanjut" (`buat_alat_dari_kertas.dart`: PT lalu alat, idempoten, seri dicek
     sebelum membuat, 422 seri kembar dijawab dengan alat yang ada, PT mirip
     tidak ditembus tanpa ketukan). Nomor seri WAJIB; tidak pernah membuat alat
     tanpa seri;
   - tidak terbaca / server tidak terjangkau: pesan jujur, lembar tetap bisa
     dipakai lewat pilihan alat manual. Tidak ada data master alat yang pernah
     ditulis ulang.

**Keputusan lama dibalik (19 Nov 2026).** `docs/PANDUAN-OCR-LEMBAR-KERJA.md` di
repo API (sec. 4, baris 137-138, status usulan) menulis identitas diambil dari
order, bukan dari OCR, dan nama pelanggan tidak pernah dibuat dari OCR. Arahan
pemilik 19 Nov 2026 membaliknya: semua data di kertas ditangkap; alat/PT baru
dibuat (setelah diperiksa teknisi), yang sudah ada dicocokkan. Batas yang tetap:
on-device saja, hasil baca = saran yang dikonfirmasi manusia, tulisan tangan
kata tidak pernah hijau, nilai teknisi tidak dihapus.

"Mulai kalibrasi" (kategori -> alat) tetap jalur manual: tanpa dialog foto,
dengan satu tombol foto kecil. Pintu foto per tabel ("Foto tabel ini", jalur ML
Kit lama) mati bawaan (`--dart-define=FOTO_PER_TABEL=true` menyalakannya).

Ambang identifikasi BELUM dikalibrasi dengan foto nyata (target 26 Nov 2026);
karena itu auto-buka hanya untuk kode bersih unik dan banner "Ganti jenis"
wajib. Skor, kode cetak, dan keputusan dicatat LOKAL di HP
(`identifikasi_lembar.jsonl` di folder dukungan aplikasi; tanpa citra, tidak
diunggah) sebagai bahan kalibrasi. Akurasi baca identitas (tulisan tangan) BELUM
terukur di foto nyata; parser diuji dengan teks sintetis.

## Aturan yang mengikat kode ini

1. **Bawaan: foto tidak keluar dari perangkat ke pihak ketiga.** OCR dan
   pembacaan QR jalan on-device (`google_mlkit_text_recognition`,
   `google_mlkit_barcode_scanning` — dua-duanya model bundled, tanpa API key).
   Tidak ada biaya per foto. **Satu pengecualian, sejak 23 Nov 2026 (keputusan
   pemilik):** OCR awan Google Cloud Vision (`DOCUMENT_TEXT_DETECTION`) boleh
   membaca SELURUH foto halaman, HANYA lewat backend `POST /api/ocr/halaman`,
   lewat sakelar developer yang bawaannya MATI. Tidak ada kunci, kredensial,
   atau URL Google di aplikasi/APK; gagal atau waktu habis = jatuh ke pembaca
   on-device tanpa crash dan sel ditandai perlu dicek. Jangan dinyalakan untuk
   teknisi sungguhan sebelum pemilik memastikan kontrak pelanggan dan ISO/IEC
   17025 §4.2 mengizinkan foto halaman (nama, nomor sertifikat) dikirim ke
   pihak ketiga. Hasilnya tetap USULAN.
2. **Yang naik ke server KITA (bukan pihak ketiga) bukan foto mentah, tapi hasil
   bacanya**: teks per sel, kotak koordinat, skor mutu, geometri. Citra hasil
   warp ikut naik ke server kita sebagai lampiran audit dan boleh gagal naik
   tanpa membatalkan hasil pindai. (Foto halaman yang diteruskan server ke
   Google hanya lewat jalur OCR awan di butir 1.)
3. **Frontend tidak menghitung apa pun.** Tidak ada rata-rata, tidak ada
   koreksi, dan **tidak ada tebakan koma**. `133659` dikirim `133659`.
4. **Bentuk lembar tidak pernah di-hardcode.** Jumlah titik, kolom, satuan,
   desimal, jumlah tabel — semuanya dari `GET /api/worksheet-templates/{kode}`.
5. **Hasil pindai itu usulan.** Data kalibrasi tetap lahir dari
   `POST`/`PUT /api/calibrations`.

## Peta berkas

| Berkas | Tugas |
|---|---|
| `lib/services/pindai_lembar.dart` | cari 4 marker sudut (ambang gelap + titik berat gumpalan, Dart murni — **tanpa OpenCV**), warp perspektif ke ruang template, potong per sel, hitung skor mutu |
| `lib/services/pembaca_qr.dart` | baca QR versi lembar (`{template_id}\|v{versi}`) dari citra hasil warp |
| `lib/services/pembaca_sel.dart` | ML Kit baca **tiap potongan sel** (bukan sehalaman), lalu `PayloadPindai` menyusun kiriman |
| `lib/services/jalankan_pindai.dart` | urutan wajibnya: marker → warp → QR → gerbang mutu → potong per sel → OCR → payload. `AmbangMutu` menyalin `config/ocr.php` |
| `lib/services/worksheet_scan_service.dart` | `POST /worksheet-scans` (multipart + `citra_warp`), crop sel, koreksi. 422 dilempar sebagai `PindaiDitolak` |
| `lib/screens/calibration/pindai_review_screen.dart` | tabel bervonis warna, crop sel di sebelah kotak isian, "Pakai Angka Ini" → `POST .../koreksi` |
| `lib/screens/calibration/lembar_kerja_state.dart` | `terapkanHasilPindai()` — menuang angka yang disetujui teknisi ke kotak isian |
| `lib/services/identitas_kertas.dart` | identitas kertas dari teks halaman lewat jangkar label cetak, parser tanggal, kunci/kemiripan nomor seri |
| `lib/services/cocokkan_alat.dart` | seri -> alat terdaftar: persis, mirip (maks 3), baru, seri kosong, galat jujur |
| `lib/services/buat_alat_dari_kertas.dart` | "Buat dan lanjut": PT lalu alat, idempoten, tanpa duplikat |
| `lib/screens/pindai/blok_identitas_foto.dart`, `identitas_foto_isian.dart` | blok identitas di lembar + penuangan saran kuning ke kotak lembar |

## Diuji di mana

| Yang dijaga | Di mana |
|---|---|
| marker, warp, tiap sel mendarat di dalam kotaknya, kotak jangkar menaungi tulisannya | `test/pindai_lembar_cetakan_test.dart` — diadu ke lembar cetak asli |
| urutan pipeline, QR, gerbang mutu, jangkar, semua sel terkirim | `test/jalankan_pindai_test.dart` |
| layar review: vonis warna, crop sel, koreksi dikirim semua | `test/pindai_review_test.dart` |
| **sambungan penuh**: tombol → server → review → angka masuk formulir → `input_method: ocr` + verifikasi pembacaan | `test/pindai_alur_layar_test.dart` |
| **ML Kit sungguhan** (QR & label Repeat) | `integration_test/pindai_hp_test.dart` — butuh HP: `flutter test integration_test/pindai_hp_test.dart -d <id>` |
| foto SATU tabel bentuk pH/spektro (Repeat berjajar ke kanan) | `test/peta_tabel_foto_test.dart` |
| foto SATU tabel bentuk Conductivity (Repeat turun ke bawah, slot larutan ke kanan) | `test/peta_tabel_foto_kebawah_test.dart` |
| identitas kertas (label, tanggal, seri) dengan teks sintetis | `test/identitas_kertas_test.dart` |
| pencocokan seri dan pembuatan PT/alat (tanpa duplikat) | `test/cocokkan_alat_test.dart`, `test/buat_alat_dari_kertas_test.dart` |
| blok identitas: cocok, mirip, baru, seri kosong, PT mirip, ganti akun, matriks ukuran | `test/blok_identitas_foto_test.dart` |
| alur linear foto -> lembar terisi tanpa kartu pilihan | `test/pindai_lembar_flow_test.dart`, `test/pindai_lembar_foto_awal_test.dart` |

Ambang mutu di `AmbangMutu` menyalin `config/ocr.php` persis. Kalau salah
satunya digeser, yang lain wajib ikut — gerbang yang lebih longgar cuma
memindahkan penolakan ke belakang, yang lebih ketat menolak foto yang sah.

## Yang belum selesai

- **`siap_pindai` masih `false` untuk keenam alat** (`geometri_belum_diverifikasi`).
  Tombol pindai mati dan alasannya ditampilkan apa adanya. Yang menutup ini lab:
  cetak ulang formulir dari `php artisan ocr:cetak-lembar {kode}`, adu ke foto
  nyata, lalu set `terverifikasi: true`.
- **Ketajaman ML Kit pada tulisan tangan belum terukur.** Yang sudah dibuktikan
  di HP cuma yang TERCETAK (QR & label Repeat). Angka tulisan tangan bukan
  soal lulus/gagal tapi akurasi per kolom — `php artisan ocr:akurasi` di sisi
  server, dan datanya baru ada sesudah teknisi memakainya.
- **Tulisan kepala Repeat di formulir LAMA lab belum dipastikan.** Ini
  menyangkut jalur kedua — "Foto tabel ini" (`PetaTabelFoto`), yang justru
  diarahkan ke formulir tak bermarker, jadi lembar hasil `ocr:cetak-lembar`
  bukan acuannya. Jangkar kolomnya dicocokkan ke tulisan yang tercetak, dan
  yang dikirim layar sekarang ikut `prefiks_pengulangan` dari backend (`X`
  membuat `X1`); alat yang backend-nya diam jatuh ke bawaan `X1`..`Xn`. Kalau
  kertas lab ternyata mencetak `Repeat 1` atau nomor polos, satu-satunya yang
  perlu diubah `_TombolFotoTabelState._kepalaPengulangan` di
  `lembar_kerja_tabel.dart` — mesinnya sendiri sudah menerima daftar tulisan
  apa pun. Sampai itu dipastikan, foto per tabel hanya terbukti jalan pada
  lembar yang mencetak `Xn`.
- **Blok non-tabel tidak lagi terisi otomatis.** Jalur AI dulu ikut mengisi
  kondisi lingkungan, catatan, dan tanggal terima dari foto yang sama.
  Template OCR cuma memetakan sel tabel, jadi kolom itu kembali diketik manual.
  Ini penyempitan yang disengaja: template OCR menaruh angka lewat kunci sel
  yang eksplisit, dan kolom non-tabel tidak punya kunci semacam itu.

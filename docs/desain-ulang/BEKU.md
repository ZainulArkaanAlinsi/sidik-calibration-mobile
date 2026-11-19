# BEKU — yang TIDAK BOLEH berubah tampilannya

Keputusan pemilik (14 Nov 2026): **UI lembar kerja sudah paten.** Tata letak,
warna, ukuran, huruf, keypad, jarak, dan perilakunya tetap persis seperti di
`main` hari ini, termasuk setelah token tema diganti ke Biru Awan.

## Daftar beku

Lembar kerja (`lib/screens/calibration/`):
`lembar_kerja_screen.dart`, `lembar_kerja_state.dart`, `kinerja_lembar.dart`,
`grid_sensor_state.dart`, `titik_sesi_state.dart`, `skema_dinamis_screen.dart`,
`temperatur_indikator_gerbang_screen.dart`, `calibration_input_screen.dart`,
`widgets/lembar_kerja_grid.dart`, `widgets/lembar_kerja_matriks.dart`,
`widgets/lembar_kerja_tabel.dart`, `widgets/lembar_kerja_kartu_baris.dart`,
`widgets/keypad_angka.dart`, `widgets/pengatur_titik.dart`,
`widgets/pengatur_titik_sesi.dart`, `widgets/tanda_lompat.dart`,
`widgets/dropdown_gagal.dart`.

Lainnya (keputusan pemilik sebelumnya):
- `admin/widgets/tabel_perhitungan.dart`: cermin sheet PERHITUNGAN Master Olah Data.
- Pratinjau sertifikat (`widgets/sertifikat_pdf_view.dart`, area pratinjau di
  `certificate/sertifikat_screen.dart` dan `history/certificate_screen.dart`): cermin PDF.
- `auth/onboarding_screen.dart`, `widgets/scene3d/*`, `widgets/sakelar_tema.dart`:
  onboarding 3D, model 3D, sakelar tema matahari/bulan.

Widget bersama yang DIPAKAI lembar kerja, jadi isinya juga beku:
`widgets/app_button.dart`, `widgets/app_text_field.dart`,
`widgets/sidik_loader.dart`, `widgets/status_badge.dart`, dan
`lib/core/theme/app_spacing.dart` (nilai `AppSpacing.*`, 217 pemakaian di lembar kerja).
Gaya Biru Awan untuk tombol/isian/loader/stempel dibuat sebagai komponen BARU
(`lib/widgets/biru_awan/…`); layar lain pindah ke komponen baru.

## Kenapa perlu teknik khusus

Hasil ukur di repo: berkas lembar kerja membaca warna lewat `Theme.of(context)`
(80×), `colorScheme` (121×), `textTheme` (130×), `AppColors.*` (2×). Kalau token
tema diganti begitu saja, lembar kerja ikut berubah walau berkasnya tidak disentuh.

## Teknik pembekuan (urutan wajib)

1. **Golden dulu, sebelum token apa pun berubah** (prompt L0). Buat
   `test/beku/lembar_kerja_golden_test.dart`: render lembar kerja pH (tabel),
   autoclave (matriks), grid sensor, keypad terbuka, dan calibration_input, di
   tema terang DAN gelap, 390 × 844 dan 1024 × 768, dengan data contoh yang
   sudah dipakai tes yang ada. Simpan gambarnya di `test/beku/goldens/`. Buat di
   OS yang sama dengan CI (lihat workflow), bukan di laptop pemilik.
2. **Palet beku**: salin nilai `PaletLab` HARI INI ke
   `lib/core/theme/palet_beku.dart` (`PaletBeku`, nilai mentah, tidak merujuk
   `PaletLab`). Ini satu-satunya berkas selain `palet_lab.dart` yang boleh
   menulis `Color(0x…)`; tambahkan ke pengecualian `token_only_test`.
3. **Tema beku**: `lib/core/theme/tema_beku.dart` membangun `ThemeData` terang
   dan gelap PERSIS seperti `sidik_theme.dart`/`app_theme.dart` hari ini, tetapi
   dari `PaletBeku`. Termasuk semua `ThemeExtension` (`SidikMaterial` dll.).
4. **`AppColors`** dialihkan ke `PaletBeku` (bukan `PaletLab`), karena pemakainya
   yang tersisa adalah layar beku. Layar yang didesain ulang berhenti memakai
   `AppColors`.
5. **Pembungkus**: `BekuLembarKerja(child: …)` (lihat `flutter/beku_lembar_kerja.dart`)
   memasang `Theme(data: TemaBeku.untuk(context))`. Satu-satunya perubahan yang
   boleh di berkas beku: membungkus widget akar layar beku dengan
   `BekuLembarKerja` (`LembarKerjaScreen`, `CalibrationInputScreen`,
   `SkemaDinamisScreen`, `TemperaturIndikatorGerbangScreen`). Dialog dan lembar
   bawah yang dibuka DARI lembar kerja ikut beku karena mewarisi tema.
6. **Penjaga**: tes `test/beku/berkas_beku_test.dart` menyimpan hash SHA-256
   tiap berkas beku; PR yang mengubah isinya (selain baris pembungkus di
   langkah 5, dicatat sekali) gagal. Golden dari langkah 1 harus tetap lolos di
   SETIAP PR berikutnya.

Kalau sebuah tugas terasa butuh mengubah berkas beku: BERHENTI dan tanya pemilik.

## Catatan implementasi L1a (14 Nov 2026) — kontrak pembungkus yang berlaku

Hasil pelaksanaan L1a menyimpang dari langkah 5 di atas, dan yang berlaku adalah ini:

- `BekuLembarKerja` dipasang di **setiap pemanggil route** yang membuka layar/area beku (`Navigator.push`, `MaterialPageRoute`, `showDialog`, `showModalBottomSheet`), BUKAN di akar `build` layar beku. Alasannya: pembungkus di dalam `build` tidak menjangkau `Theme.of(context)` dan `showDialog(context:)` yang dipanggil dari State (context di atas pembungkus), dan memaksa tema produksi pada 6 tes lama yang memasang layar langsung di bawah tema bawaan.
- Penjaganya `test/beku/tema_beku_terpasang_test.dart` (pemindai sumber + pemeriksaan `PenandaBeku`). Pemanggil baru yang membuka layar beku harus ikut dibungkus; jangan menambah pembungkus akar.
- Area pratinjau di `history/certificate_screen.dart` (`_IdentitasSesi`, `_TabelLaporan`, `_StandarDipakai`): dibungkus di L1b, SEBELUM token diganti (lihat bawah).

## Catatan implementasi L1b (15 Nov 2026)

Token tema app diganti ke Biru Awan; yang berubah untuk area beku hanya pembungkus:

- **"02 Pilih alat"** (`category_picker_screen.dart`, `instrument_picker_screen.dart`): keputusan pemilik 15 Nov, tampilannya tidak boleh berubah. Dibungkus `BekuLembarKerja` di semua pemanggil route (`kalibrasi_teknisi_screen`, `dashboard_screen` x2, `beranda_super_admin`, dan `category_picker_screen` ke `InstrumentPickerScreen`). Berkasnya TIDAK di-hash (bukan beku resmi) dan isinya tidak diubah kecuali satu pembungkus. Penjaga: `test/beku/picker_dan_sertifikat_beku_test.dart` (gambar sama piksel dengan tema beku langsung, warna kunci = `PaletBeku`) dan pemindai di `tema_beku_terpasang_test.dart`.
- **Pratinjau sertifikat** di `history/certificate_screen.dart`: tiga bagian di atas dibungkus dari luar di `_IsiState.build`. Ringkasan dan tombol di sekitarnya mengikuti tema app.
- `AppColors` tetap `PaletBeku` (nilai kobalt lama), jadi layar non-beku TAMPIL CAMPURAN sampai didesain ulang: `colorScheme`/`SidikMaterial` Biru Awan, `AppColors.*` lama. Disengaja dan diterima pemilik; daftar dan akibatnya di `docs/standar-kualitas-desain.md` bagian 8.
- Nilai tema beku dikunci literal di `test/tema/tema_beku_test.dart`.

## Addendum — buka-kunci `lembar_kerja_screen.dart` untuk foto awal (15 Nov 2026)

**Status persetujuan, apa adanya.** Buka-kunci ini diputuskan oleh orkestrator
berdasarkan rencana tombol "Pindai lembar kerja" (Opsi B, PR3) dan aturan
pemilik "lanjut aja gpp". Itu BUKAN persetujuan eksplisit pemilik untuk berkas
ini, padahal aturan di atas dan `test/beku/berkas_beku_test.dart` meminta
persetujuan pemilik. Perubahannya aditif (+41 baris, 0 baris dihapus; hanya
jalur data dan komentar) dan mudah di-revert: hapus parameter/field/baris di `_fotoLembar`
dan kembalikan hash. Pemilik meninjau lewat PR ini; bila tidak setuju, revert.

Satu berkas, satu kali: `lib/screens/calibration/lembar_kerja_screen.dart`.

**Apa yang berubah.** Hanya jalur data, nol widget, tata letak, warna, ukuran,
huruf, jarak, atau perilaku layar yang sudah ada:
- `LembarKerjaScreen` dan `_Form` menerima parameter opsional
  `Uint8List? fotoAwal` (bawaan `null` = perilaku sebelumnya persis).
  `import 'dart:typed_data'` ditambahkan.
- `_FormState._fotoAwalSisa` memegang salinan foto itu. `_fotoLembar` (yang sudah
  ada) menyerahkannya SEKALI ke `pindaiFormulirAsli(bitaAwal:)` lalu
  mengosongkan salinan itu sebelum pindai jalan, jadi percobaan ulang selalu
  lewat kamera. Jalur yang berhenti sebelum pindai (alat belum dipilih, formulir
  belum siap) TIDAK menghabiskannya. Tidak ada tombol, teks, atau dialog baru;
  kamera tetap dibuka lewat tombol/pintu yang sama bila `fotoAwal` null atau
  sudah terpakai.

**Kenapa.** Tombol "Pindai lembar kerja" di beranda memotret lembar untuk
mengenali jenisnya, tetapi lembar kerja baru boleh dipindai setelah alat dipilih
(titik ukur lahir dari alat). Tanpa parameter ini teknisi harus memotret DUA kali
(Opsi A, PR #244). Dengan ini foto yang sama (byte JPEG kamera, bukan citra hasil
decode) dipakai sebagai percobaan pertama "Foto lembar kerja", dan kamera hanya
dibuka sekali.

**Yang TIDAK berubah.** Aturan OCR: hanya di perangkat, hasil = saran, tanpa
"terima semua", sel kosong tetap kosong, tulisan tangan tidak pernah hijau,
`_kenali` tetap memeriksa ulang kode FM terhadap jenis yang dipilih, gerbang
wajib-cek (#241) dan pemisahan wewenang. Foto hanya di memori (tidak ke disk,
tidak diunggah), dipakai sekali, tidak dimulai sebelum alat dipilih dan tombol
ditekan.

**Catatan memori.** Yang dikosongkan sesudah dipakai hanya salinan di State.
Byte JPEG-nya (beberapa MB, bukan citra decode) tetap dipegang
`LembarKerjaScreen.fotoAwal`, `_Form.fotoAwal`, dan closure route pemanggil
selama lembar terbuka; baru lepas saat route ditutup. Melepasnya lebih awal
butuh pemegang sekali-ambil yang mengubah tipe parameter; ditunda.

**Bukti.** Hash baru ada di `test/beku/berkas_beku_test.dart` (PR yang sama).
Golden `test/beku/goldens/` lolos TANPA diperbarui (bawaan `null` = tampilan
identik). Tes perilaku: `test/pindai_lembar_foto_awal_test.dart`,
`test/pindai_lembar_flow_test.dart`.


## Addendum — buka-kunci `lembar_kerja_screen.dart` untuk foto OTOMATIS, satu pintu (18 Nov 2026)

**Persetujuan.** Keputusan pemilik 18 Nov 2026 (arahan eksplisit, setelah
mencoba di HP): foto -> jenis lembar dikenali otomatis -> lembar yang tepat
terbuka -> terisi sebagai saran kuning -> teknisi memeriksa; hanya SATU pintu
foto. Ini MEMBALIK aturan 12 Nov "pilih jenis manual selalu tampil" untuk kode
formulir yang unik, dan menggantikan addendum 15 Nov di atas.

**Yang berubah (hanya bagian foto).**

- `fotoAwal` (byte) diganti `dariFoto` (`DariFotoLembar`:
  `lib/screens/pindai/dari_foto_lembar.dart`) di `LembarKerjaScreen` dan
  `_Form`. `null` (bawaan, jalur "Mulai kalibrasi") = lembar manual.
- Dialog "Mau diisi bagaimana?" (`_tanyaCara`) DIHAPUS untuk semua lembar.
- Lembar dari foto: alat yang ditentukan alur ikut kunci bentuk sejak awal;
  begitu formulir terpasang, foto yang sama dibaca OTOMATIS lewat
  `_fotoLembar` yang sama (layar periksa yang sudah ada, sel terisi sebagai
  saran kuning, gerbang wajib-cek tetap). Tombol foto di lembar itu baru muncul
  SESUDAH percobaan pertama ("Foto ulang"), atau "Isi dari foto" bila alat belum
  ada. Lembar manual: tombol lama "Foto worksheet" apa adanya.
- Banner jenis di atas lembar (`banner_jenis_dari_foto.dart`) + "Ganti jenis"
  (`_gantiJenis`: pilihan jenis lain, lalu `pushReplacement` dengan foto yang
  sama; isian yang belum disimpan dijaga dialog keluar yang sudah ada).
- Pintu foto PER TABEL/BLOK ("Foto tabel ini", kamera grid, kamera matriks;
  jalur ML Kit lama) disembunyikan lewat saklar baru `FOTO_PER_TABEL`
  (`AppConfig.fotoPerTabelAktif`, bawaan mati). Kodenya utuh.

**Yang TIDAK berubah.** Aturan OCR: hanya di perangkat, hasil = saran, tanpa
"terima semua", sel kosong tetap kosong, tulisan tangan tidak pernah hijau,
`_kenali` tetap memeriksa ulang kode FM terhadap jenis yang dibuka, gerbang
wajib-cek (#241), pemisahan wewenang, `siap_pindai` / mode uji /
`perlu_konfirmasi_lab` / Temperatur Indikator. Mesin identifikasi dan
ambangnya tidak disentuh (hanya dicatat lokal, tanpa citra).

**Golden.** `test/beku/goldens/` TIDAK diperbarui. Lembar tanpa `dariFoto`
identik, tetapi pintu foto per tabel kini mati bawaan di produksi sementara
golden beku masih menggambarnya; tes golden mematok saklarnya NYALA supaya
gambar acuan tidak bergeser. Menurunkan patokan itu butuh golden baru lewat
`golden-baru.yml` dan keputusan pemilik.

**Bukti.** Hash baru di `test/beku/berkas_beku_test.dart` (PR yang sama). Tes:
`test/pindai_lembar_flow_test.dart`, `test/pindai_lembar_foto_awal_test.dart`,
`test/lembar_kerja_cara_isi_test.dart`, `test/keputusan_pindai_lembar_test.dart`,
`test/ocr_alur_perangkat_test.dart`.

## Addendum — buka-kunci `lembar_kerja_screen.dart` untuk alur foto LINEAR (19 Nov 2026)

**Persetujuan.** Arahan pemilik 19 Nov 2026 (eksplisit, dicatat di brief paket
OCR-LINEAR): setelah foto TIDAK ada kartu pilihan, lembar langsung terisi dari
yang TERTULIS di kertas, lalu diperiksa dan dikirim. Paket ini hanya sampai PNG
dan persetujuan pemilik; belum di-push dan belum di-merge. Bila pemilik tidak
setuju, revert cabang `feat/ocr-alur-linear`.

Satu berkas, satu kali lagi: `lib/screens/calibration/lembar_kerja_screen.dart`.
`lembar_kerja_state.dart` TIDAK disentuh (penuangan identitas ke kotak lembar
lewat ekstensi di `lib/screens/pindai/identitas_foto_isian.dart`, memakai
`isianDariFoto` + `cekIsian` yang sudah ada).

**Yang berubah (hanya jalur foto; jalur manual "Mulai kalibrasi" tidak).**

- `DariFotoLembar.alatAwal` dihapus. Lembar dari foto tidak pernah membawa alat:
  `_equipmentId` hanya dari salinan HP, dan `isiDariAlat()` tidak dipanggil dari
  `initState`. Alat dipasang HANYA oleh ketukan teknisi di blok identitas.
- Baca foto otomatis jalan untuk SEMUA lembar dari foto (syarat `alatAwal != null`
  dibuang), dan `_fotoLembar` tidak lagi menolak "Pilih alatnya dulu" bila
  `dariFoto != null`. Kunci peta formulir memuat `kodeDokumen` (kode formulir
  tercetak) supaya server memilih peta varian tanpa alat. Sebelum pembacaan,
  identitas kertas dituang sebagai saran kuning.
- Banner tanpa petunjuk "Pilih alat di bawah..."; tombol foto hanya SATU
  ("Foto ulang") dan baru muncul sesudah percobaan pertama ("Isi dari foto"
  dihapus). Gagal baca = pesan saja, tanpa dialog Tutup/Foto ulang
  (`tanpaDialogFotoUlang`, hanya jalur foto).
- Satu widget baru di atas lembar: `BlokIdentitasFoto` (di `Flexible`, menggulir
  di jatahnya sendiri). `_PilihAlat` memuat alat terpilih yang di luar halaman
  pertama daftar (agar Dropdown tidak melempar).

**Yang TIDAK berubah.** Aturan OCR (hanya di perangkat, hasil = saran, tanpa
"terima semua", sel kosong tetap kosong, tulisan tangan kata tidak pernah hijau),
gerbang wajib-cek (#241), pemisahan wewenang, `input_method` dan konfirmasi
pembacaan sesudah kirim, `siap_pindai` / mode uji / `perlu_konfirmasi_lab`,
tampilan lembar tanpa `dariFoto` (golden `test/beku/goldens/` TIDAK diperbarui).

**Bukti.** Hash baru di `test/beku/berkas_beku_test.dart` (cabang yang sama).
Tes: `test/blok_identitas_foto_test.dart`, `test/pindai_lembar_flow_test.dart`,
`test/pindai_lembar_foto_awal_test.dart`, `test/identitas_foto_isian_test.dart`.
PNG untuk persetujuan: lihat `DAFTAR.txt` di folder PNG paket ini.

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
- Belum dibungkus (dikerjakan sebelum token berubah di L1b): area pratinjau di `history/certificate_screen.dart` (`_IdentitasSesi`, `_TabelLaporan`, `_StandarDipakai`).

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

# Komponen Biru Awan (`lib/widgets/biru_awan/`)

Komponen dasar desain ulang SIDIK Lab (`docs/desain-ulang/`). Dibuat BARU; widget
lama (`app_button`, `app_text_field`, `sidik_loader`, `status_badge`, dan
`lib/widgets/sidik/*`) tidak diubah dan tetap dipakai area beku serta layar yang
belum didesain ulang. Layar pindah ke komponen ini satu per satu (L5 dst.).

**Status L3a + L3b + L2 (16 Nov 2026): semua komponen di bawah SUDAH ADA dan diuji.
Satu-satunya layar yang memakai elemen L2 adalah `LapisanKabarMasuk` (kartu kabar
navy); `SnackBar` dan `AlertDialog` di layar mana pun BELUM diganti.** Satu-satunya pemakai di `lib/` adalah galeri
pengembang `lib/screens/pengembang/galeri_biru_awan_screen.dart` (dibuka dari
`design_system_screen.dart`, hanya di build debug). L3b menambah HeroLangit,
UbinKpi, GrafikBatang, StepperTegak, GarisWaktu, AvatarInisial, Lencana (dan
`LoncengBerlencana`), BilahLangkah, KolomCari; token L3b ada di berkas terpisah
`lib/core/theme/token_komponen_biru_awan_lanjut.dart`.

## Daftar

| Komponen | Berkas | Dipakai untuk | Pengganti |
|---|---|---|---|
| `TombolSidik` | `tombol_sidik.dart` | Semua tombol berlabel. Ragam: `utama` (56, satu per layar), `tegas` (navy), `sekunder` (tepi kontrol), `teks`, `bahaya`. Mati dengan `alasanMati`, `sibuk` | `AppButton`, `FilledButton`/`OutlinedButton` polos |
| `TombolBulat` | `tombol_bulat.dart` | Tombol ikon: 44 (cari, tambah), 48 (kembali, lonceng, menu), 60 (Mulai di dock). `label` wajib; sentuh >= 48 | `IconButton`, FAB |
| `IsianSidik` | `isian_sidik.dart` | Isian teks: label di atas, kotak 56, keadaan biasa, fokus, galat, mati; `wajib`, `mono`, `akhir` | `AppTextField`, `TextFormField` polos |
| `StempelSidik` | `stempel_sidik.dart` | Status: pil 30, ikon + kata. Nada dari `StatusTampil` yang ada; FAIL navy pekat; `.keputusan(null)` netral | `StatusBadge`, `Stempel` lama |
| `ChipSaring` | `chip_saring.dart` | Saring dengan jumlah (pil 44, bulatan 32) | `FilterChip`, `ChoiceChip` |
| `SegmenPil<T>` | `segmen_pil.dart` | 2 sampai 3 pilihan saling meniadakan (peran, mode) | `SegmentedButton`, `TabBar` pendek |
| `KartuSidik24` | `kartu_sidik24.dart` | Wadah kartu sudut 24, datar; bisa diketuk, terpilih, galat | `Card`, `KartuGradien` |
| `PanelBaris` + `BarisMenu64` + `BarisDaftar72` | `panel_baris.dart` | Panel putih berisi baris menu (64, ubin bulat 44) atau baris daftar (72, ubin 48) dengan pemisah halus | `ListTile`, kartu per baris |
| `UbinIkon` | `ubin_ikon.dart` | Ubin berwarna berisi ikon atau gambar kecil (bulat 44 atau persegi 48) | `CircleAvatar` hias |
| `KepalaTab` + `KepalaAnak` | `kepala_layar.dart` | Kepala layar tab (logo, nama, peran, aksi bulat) dan layar anak (kembali, judul, nomor, aksi) | `AppBar` |
| `HeroLangit` | `hero_langit.dart` | Bidang langit sudut 28 dengan motif skala (BUKAN awan; digambar `PelukisMotifSkala`), min 212; isi bebas, teks navy | `KartuGradien` hero lama |
| `UbinKpi` | `ubin_kpi.dart` | Ubin angka 2 x 2 (min 112, sudut 24, angka 36/800); ragam putih, kabut, hijau, kuning, awan, koral, navy; bisa diketuk | `StatCard` |
| `GrafikBatang` | `grafik_batang.dart` | 7 batang (`BatangGrafik`) sudut 10, hari ini primer, lainnya awan, tumbuh 240 ms sekali | `WorkChart` |
| `StepperTegak` | `stepper_tegak.dart` | Alur tegak dari `LangkahStepper`: selesai (centang), sekarang (cincin awan), belum (tepi) | `Stepper` Material |
| `GarisWaktu` | `garis_waktu.dart` | Riwayat dari `ButirGarisWaktu`: simpul 12, garis halus, pelaku tebal, detail bebas | daftar riwayat ad hoc |
| `AvatarInisial` | `avatar_inisial.dart` | Bulatan inisial 36/48/52/84 (kabut, putih, langit) | `CircleAvatar` |
| `Lencana` + `LoncengBerlencana` | `lencana.dart` | Jumlah koral 22, kuning 26, titik 10; lonceng 48 dengan lencana di pojok | `Badge` Material |
| `BilahLangkah` | `bilah_langkah.dart` | 4 segmen tinggi 6 + label "1 Alat" (Pilih alat) | `LinearProgressIndicator` ad hoc |
| `KolomCari` | `kolom_cari.dart` | Pil 56 + tombol bulat cari 44; cincin fokus di luar | `SearchBar`, `TextField` cari |
| `ToastSidik` + `tampilkanToast` | `toast_sidik.dart` | Umpan balik singkat: kartu putih (sukses, info, peringatan, galat) atau navy + logo (`JenisToast.kabar`). `tampilkanToast` menampilkannya di overlay, SATU sekaligus; `ToastSidik` kartunya saja (dipakai `LapisanKabarMasuk`). Juga memuat `TombolTutupSidik`, `PilAksiSidik` (pil aksi 40, sasaran 48, cincin di luar) dan `UbinUmpanBalik` yang dipakai bersama | `SnackBar` (BELUM diganti di layar mana pun) |
| `DialogSidik` + `tampilkanDialogSidik` | `dialog_sidik.dart` | Konfirmasi: ubin ikon 56, judul, isi, Batal kiri dan aksi kanan (bahaya merah). Mengembalikan `true` bila aksi diketuk | `AlertDialog`, `showDialog` |
| `LembarBawahSidik` + `tampilkanLembarBawahSidik` | `lembar_bawah_sidik.dart` | Lembar bawah: sudut atas 32, pegangan, judul + tutup, isi bergulir (maks 80 % layar) | `showModalBottomSheet` polos |
| `BannerSidik` (`RagamBannerSidik`) | `banner_sidik.dart` | Banner di bawah kepala layar: tanpa koneksi (navy 48), pembaruan (langit 56 + tombol), peringatan data (kuning tipis) | `MaterialBanner`, pita ad hoc |
| `KeadaanMemuat` (`RagamMemuat`), `KeadaanKosong`, `KeadaanGalat` | `keadaan_sidik.dart` | Memuat (kerangka berdenyut terbatas atau spinner > 400 ms), kosong (ubin langit + satu aksi), galat (ubin koral tipis + "Coba lagi") | `CircularProgressIndicator` ad hoc, pesan kosong/galat buatan layar |

Gerak bersama ada di `lib/core/motion/gerak_bersama.dart` (`MasukBerurutan`,
`TekanSkala`); token di `lib/core/theme/token_komponen_biru_awan.dart` (huruf,
jarak, ukuran) dan `lib/core/theme/warna_biru_awan.dart` (isi dan tinta status).

## Aturan pakai

- Teks tampilan dari pemanggil (l10n); komponen hanya membawa kunci `biruAwan*`
  untuk kata bantu pembaca layar (kembali, sedang diproses, wajib, galat).
- Tanpa warna, ukuran, atau radius mentah (`test/tema/token_only_test.dart`).
  Kontras pasangan dijaga `test/tema/kontras_biru_awan_test.dart`.
- Sasaran sentuh >= 48 dp, semantik berlabel dengan aksi ketuk, "kurangi gerak"
  mematikan animasi, tanpa luapan di 320 dp x huruf 1,3 (tes di `test/biru_awan/`).
- Komponen tidak menghitung angka ukur dan tidak memvonis: nada stempel dan
  keputusan datang dari server lewat pemanggil. `keputusan == null` tampil netral,
  tidak pernah hijau.
- Satu tombol `utama` per layar. Aksi bahaya memakai kata kerja jelas.
- Berkas beku (`PETA-LAYAR.md`, `BEKU.md`) tidak memakai komponen ini.

## Penyimpangan dan batas yang dicatat (tinjauan L3a)

Tiga hal ini sengaja dibiarkan dan dicatat di sini supaya tidak ditemukan ulang
sebagai temuan baru. Tidak satu pun diubah di L3a.

- **Pemutar sibuk `TombolSidik` (20 dp) langsung berputar.** `ELEMEN.md`
  ("Memuat") menyebut spinner 36 dp yang baru tampil bila menunggu lebih dari
  400 ms dan menjadikannya satu-satunya gerak berulang. Implementasi sekarang
  menyimpang di dua hal: ukurannya 20 dp (sebaris dengan label di dalam
  tombol) dan berputar sejak `sibuk` menyala, tanpa tunda 400 ms. Dengan "kurangi
  gerak" busurnya diam. Ini penyimpangan yang dicatat, belum keputusan desain:
  TANYAKAN ke desain apakah tombol berlabel boleh memakai pemutar kecil
  langsung, atau harus menunda 400 ms (atau memakai spinner 36 di tempat lain).
- **`IsianSidik` API-nya lebih sempit dari `AppTextField`.** Belum didukung:
  `prefixIcon` dan `suffix` teks (satuan, mis. "mm", "kg"); yang ada hanya
  `akhir` (widget bebas di ujung kotak, setara `trailing`). Tidak ada tombol
  tampil/sembunyi sandi otomatis: `obscureText` saja, pemanggil memasang
  tombolnya lewat `akhir`. Juga belum ada `readOnly`, `maxLength`, `validator`
  (`Form`), dan `onEditingComplete`. Yang hanya ada di `IsianSidik`:
  `focusNode`, `textCapitalization`, `maxLines`, `mono`, `wajib`.
  Tambahkan yang dibutuhkan layar saat layar itu dipindahkan (L5 dst.), jangan
  sebelumnya.
- **`KepalaTab` belum memakai `LabProfile.logoAsset`.** Path logo masih ditulis
  langsung (`assets/images/logo_pt_sidik.png`) di `kepala_layar.dart`, padahal
  sudah ada `LabProfile.logoAsset` (`lib/core/config/lab_profile.dart`).
  Disambungkan di L5/L6, saat layar pertama memakai kepala ini dan sumber logo
  per lab menjadi relevan.

## Cincin fokus `TombolSidik`

Digambar di LUAR tombol, terpisah `UkuranKomponenBiruAwan.jarakCincinFokus` (2 dp)
dari tepinya, warna `tinta`. Cincin di dalam bentuk (rancangan pertama) sama
dengan isi pada ragam `tegas` (1,00:1) dan hanya 1,6 sampai 3,0:1 pada `utama`
dan `bahaya`. Di luar dan terpisah, yang bersebelahan dengan cincin adalah latar
halaman, jadi kontrasnya diukur terhadap `meja` dan `kertas` (>= 3:1, terang dan
gelap): `test/biru_awan/tombol_sidik_test.dart` dan
`test/tema/kontras_biru_awan_test.dart`. Cincin tidak memengaruhi tata letak;
beri ruang >= 4 dp di sekeliling tombol yang berada di tepi wadah yang memotong.

## Catatan L3b

- **Motif skala digambar dengan `CustomPainter`, bukan memuat SVG.** Repo tidak
  punya `flutter_svg`/`vector_graphics` dan `docs/desain-ulang/aset/motif_skala.svg`
  tidak terdaftar di `pubspec.yaml`; supaya paket dan daftar aset tidak berubah,
  `MotifSkala` (`token_komponen_biru_awan_lanjut.dart`) membawa koordinat yang
  sama dan `test/biru_awan/hero_langit_test.dart` membaca SVG aslinya lalu
  mengadu 37 garisnya (tik busur, jarum, penggaris) dan kedua busurnya.
- **Angka lencana 12/800, bukan 11/800 seperti artboard**: gerbang token-only
  melarang huruf di bawah 12.
- **Catatan `UbinKpi` memakai tinta penuh, bukan opasitas 0,8 artboard**, supaya
  kontras di atas koral dan kuning tidak turun.
- **Batang `awan` di `GrafikBatang` (1,6:1 terhadap kertas) di bawah 3:1** untuk
  objek grafis. Itu warna artboard; informasinya tidak hilang karena tiap batang
  membawa angka dan nama tertulis, dan batang sorot (primer) lolos 3:1. Tanyakan
  ke desain bila batang awan perlu tepi atau warna lebih pekat.
- **Penanda "belum" di `StepperTegak` (tepi `garisTegas`, 1,5:1)** juga warna
  artboard; keadaannya juga dibawa kata ("belum") dan judul tinta kedua.
- **`TombolBulat` (dipakai `KolomCari` dan `LoncengBerlencana`) belum bisa
  difokuskan papan ketik** (L3a memakai `GestureDetector`). Aman di HP; untuk
  Windows/Studio atau papan ketik fisik, bukan bagian L3b.
- Cincin fokus `KolomCari` memakai pola `TombolSidik` (di luar, jarak 2 dp,
  `tinta`, kontras >= 3:1 terhadap `meja` dan `kertas`, terang dan gelap).
- Komponen statis (`HeroLangit`, `UbinKpi`, `GarisWaktu`, `StepperTegak`,
  `BilahLangkah`, `Lencana`) tidak menganimasikan apa pun; masuk layar dibungkus
  pemanggil dengan `MasukBerurutan`. Satu-satunya gerak L3b adalah `GrafikBatang`
  (sekali, tanpa `repeat`).

## Catatan L2 (elemen umpan balik)

Token di `lib/core/theme/token_umpan_balik_biru_awan.dart` (huruf, ukuran, warna
turunan, bayangan toast dan dialog). Bayangan dibaca dari token itu, bukan
`BoxShadow` di widget (gerbang `pendaftaran_biru_awan_test` tetap melarang
`BoxShadow` di berkas komponen).

- **Pemakaian**: `tampilkanToast(context, jenis:, judul:, isi:, aksi:, onAksi:)`,
  `await tampilkanDialogSidik(context, ikon:, judul:, aksi:, batal:, bahaya:)`
  (hasil `bool`), `tampilkanLembarBawahSidik<T>(context, judul:, bangun:)`.
  Teks dari pemanggil (l10n); komponen membawa kunci `biruAwan*` untuk kata bantu
  ("Tutup", "Buka", jenis toast, "Memuat").
- **Satu toast sekaligus.** Hilang sendiri 4 detik (peringatan 6); galat dan toast
  beraksi tidak hilang sendiri (`ToastSidik.lamaTampil`). Tutup: tombol "x" atau
  usap ke atas. Diumumkan lewat `SemanticsService.sendAnnouncement`.
- **Tinggi kartu toast 72, bukan 68**, bila ada tombol tutup atau aksi: sasaran
  sentuh 48 + bantalan 12 x 2. Pil aksi tetap tampak 40.
- **Pil aksi dan tombol tutup bergambar 40 (44 di lembar bawah), sasaran 48,
  cincin fokus di luar gambar** (2 dp celah, 2 dp garis, warna lawan latar kartu:
  `tinta` di kartu putih, putih di kartu navy). `TombolBulat` L3a tidak dipakai di
  sini karena belum bisa difokuskan papan ketik.
- **Aksi dialog**: kata kerja jelas, "OK" dan "Ya" dilarang oleh aturan desain
  (tidak bisa ditegakkan kode). Ragam bahaya memakai `TombolSidik.bahaya` =
  `colorScheme.error` (`#A81B33`, utang desain), bukan `#A3261A` di `ELEMEN.md`.
  Tombol "Coba lagi" / "Mulai kalibrasi" 48, bukan 44 di artboard (sasaran 48).
- **Kerangka memuat berdenyut 5 siklus (6 dtk) lalu diam**, bukan tanpa akhir
  seperti artboard: `pumpAndSettle` harus selesai, dan gerak otomatis > 5 detik
  perlu bisa dihentikan (WCAG 2.2.2). Spinner tetap berputar selama menunggu.
  Dengan "kurangi gerak" keduanya diam dan toast, dialog, lembar tanpa animasi.
- Banner pembaruan hanya untuk pembaruan opsional; pembaruan WAJIB memakai dialog.
- `LapisanKabarMasuk` memakai `ToastSidik` varian kabar; dedup per id, hitung
  mundur 5 detik, dan ketukan tidak berubah (logikanya di `KabarMasukNotifier`).

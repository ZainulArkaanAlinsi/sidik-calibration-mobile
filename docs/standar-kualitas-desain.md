# Standar kualitas desain: app Lab (sidik-calibration-mobile)

Berlaku untuk setiap perubahan tampilan di app Lab (`lib/screens`, `lib/widgets`,
`lib/core/theme`). Ringkasan standar kualitas desain Sidik, disesuaikan untuk Lab.
Gerbang otomatis ada di bagian "Cara menjalankan gerbang".

## 1. Untuk siapa dan dalam kondisi apa

Lab dipakai teknisi dan admin di bengkel dan lab: HP dan tablet, tangan sibuk,
cahaya tak menentu, isian padat angka. Akibatnya:

- Aksi utama besar dan satu per layar. Angka ukur terbaca dari jarak lengan.
- Tidak ada yang hanya mengandalkan warna. Status = bentuk + ikon + kata.
- Tidak meluap di HP murah (320 dp, huruf 1,3x) dan memakai lebar tablet 1280 dp.
- Terbaca di terang maupun gelap.

Pelanggan (staf PT, baca-saja, tenang) dan Admin web punya standar yang sama
dalam keluarga yang sama; Lab lebih padat dan berorientasi tugas.

## 2. Arah visual

- **Satu warna merek**: kobalt `#043EA1` (logo PT SIDIK) dengan empat jenjang,
  di atas netral dingin. Sistem krem dan abu hangat ("Meja Kerja Lab") dan
  kobalt `#1D4292` sudah diganti.
- **Datar**: baris dan panel dipisah garis halus, bukan bayangan. Tanpa gradien,
  tanpa bayangan dalam, tanpa tekstur logam. Bayangan hanya untuk lembar bawah
  dan dialog.
- **Dua keluarga huruf**: Inter untuk seluruh antarmuka; IBM Plex Mono hanya
  untuk nilai ukur dan nomor (sertifikat, order, serial). Kedua font sudah ada
  di `assets/fonts`; tidak ada font atau paket baru.
- **Identitas dari dunia ukur**, bukan dari hiasan: angka ukur berlebar tetap,
  stempel status, skala (tik penggaris) hanya di tempat yang memang mengukur
  sesuatu. Satu momen khas yang fungsional (panel bacaan angka) menyusul di
  paket komponen; selebihnya tenang.
- **Tanda yang dihindari** (bawaan generik): gradien ungu-biru, semua kartu
  satu radius dan satu bayangan, semua rata tengah, teks abu di atas latar
  berwarna, emoji sebagai ikon, ilustrasi stok, lima warna aksen bersaing,
  label HURUF BESAR di atas tiap judul, "A · B · C" sebagai pemisah.

## 3. Token (satu sumber)

Nilai mentah hanya ditulis di `lib/core/theme/palet_lab.dart`. Layar membaca
lewat `SidikMaterial.of(context)`, `Theme.of(context).colorScheme`, `AppColors`
(nama lama, nilai baru), `BentukLab`, `UkuranLab`, dan `textTheme`.

### Warna

| Peran | Terang | Gelap |
|---|---|---|
| Kobalt (aksi, fokus, tautan) | `#043EA1` | `#8CB0FF` |
| Kobalt tipis (sel aktif, baris terpilih) | `#DCE6FA` | `#14306F` |
| Latar layar | `#F2F4F8` | `#0E1320` |
| Kertas (baris, lembar, sel) | `#FFFFFF` | `#171D2B` |
| Tinta | `#111827` | `#E6EAF2` |
| Tinta kedua | `#475467` | `#A9B2C3` |
| Garis tegas (tepi isian, sel, tombol sekunder, ikon penting) | `#6B7588` | `#7C879B` |
| Garis halus (pemisah, dekoratif) | `#DDE2EB` | `#2C3548` |

Status (tinta di atas latar tipis; sama dengan Pelanggan KECUALI amber, lihat bagian 7):

| Status | Terang | Gelap |
|---|---|---|
| Berlaku, PASS | `#125739` / `#E1F0E8` | `#6FD3A0` / `#12301F` |
| Segera, Perlu revisi | `#8C5C0A` / `#FBF0DA` | `#DB9A2B` / `#33260C` |
| Gagal, Lewat jadwal, FAIL | `#A81B33` / `#FBE4E8` | `#FF8FA0` / `#3A1720` |
| Menunggu | `#344054` / `#E6EAF2` | `#C3CAD8` / `#262E40` |

Nama lama dipertahankan sementara: `AppColors.*` dan `SidikMaterial.*` (`meja`,
`kertas`, `logam`, `kaca`, ...) kini memegang nilai di atas. Layar baru
sebaiknya memakai `colorScheme` dan `SidikMaterial.of(context)`.

### Bentuk (`BentukLab`)

Sel 4, stempel 4, panel data 8, kontrol 10 (tombol sekunder, isian, chip), tombol
utama 16, lembar bawah dan dialog 20, pil 999 hanya untuk lencana angka. Baris
daftar tanpa radius. `AppSpacing.radius{Sm,Md,Lg}` dipetakan ke set ini.

### Ukuran sentuh (`UkuranLab`)

- **Aksi utama 56 dp**: `FilledButton` (tema), `RagamTombol.utama`, FAB. Satu per
  layar.
- **Semua aksi lain 48 dp**: tombol sekunder, tombol teks, tombol ikon, baris yang
  diketuk.
- Desktop Windows 44 dp (alat tunjuk tetikus).
- Pengecualian terdokumentasi: tombol toolbar di app bar tetap 48 dp.
- **Aturan ini berlaku pada DEFAULT token.** Beberapa layar menimpanya, dan itu
  utang yang dicatat di baseline kategori `tinggi_tombol_kecil`:
  `alur_kerja_screen.dart:665,724,758` (44), `ringkasan_screen.dart:99` (44),
  `banner_pembaruan_windows.dart:114` (40). Yang sah dan tidak dihitung:
  `AppButton(ringkas: true)` 48 (`app_button.dart:65`), `SidikTombol(kecil: true)`
  42 untuk baris padat (di dalam widget, tidak terdeteksi pemindai).

### Tipografi (Inter; skala di `SidikTheme`)

| Tingkat | Ukuran/baris | Berat | Slot |
|---|---|---|---|
| tampilan | 28/34 | 700 | display* |
| judul layar | 20/26 | 600 | headline* |
| app bar | 18/24 | 600 | titleLarge |
| subjudul | 16/24 | 600 | titleMedium |
| judul bagian | 14/20 | 600, tinta kedua | titleSmall |
| isi | 15/22 | 400 (600 untuk nama) | bodyMedium |
| keterangan | 13/18 | 400, tinta kedua | bodySmall |
| tombol | 15/20 | 600 | labelLarge |
| label | 12/16 | 600 | labelMedium, labelSmall |

**Minimum 12 sp**, tanpa pengecualian (termasuk desktop yang diskala 0,9x dan
`SidikMaterial.gayaEtsa`). Angka ukur memakai `SidikTheme.gayaAngka` (Plex Mono,
digit lebar tetap).

### Spasi

Grid 4/8: 4, 8, 12, 16, 24, 32 (`AppSpacing`). Margin halaman 16 (24 di tablet).

## 4. Aturan kontras (WCAG 2.x)

- Teks dan ikon yang membawa makna: **>= 4,5:1** terhadap latarnya.
- Komponen UI (tepi isian dan sel, isi tombol terhadap latar, ikon penting,
  sakelar, kotak centang): **>= 3:1**.
- Garis halus (`kertasTepi`, `garis`) hanya pemisah dekoratif (sekitar 1,3:1).
  Jangan dipakai sebagai satu-satunya penanda sebuah kontrol.
- `colorScheme.outline` dipakai sebagai warna TEKS redup di banyak layar, jadi
  nilainya dijaga 4,5:1 di kertas dan baki (terang: `#5F6B7E`).
- Warna tidak boleh jadi satu-satunya pembawa makna: status selalu ikon + kata.

## 5. Aturan menulis tampilan

1. Satu aksi utama per layar. Aksi yang mati menjelaskan alasannya.
2. Rancang semua keadaan: memuat, kosong, galat, offline, tanpa izin. Teks
   keadaan kosong mengajak bertindak.
3. Tidak ada kartu di dalam kartu, tidak ada ubin ikon dekoratif di atas judul.
4. Teks Indonesia baku, pendek, aktif; sentence case (kapital hanya singkatan:
   PASS, FAIL, KAN); desimal dengan koma; istilah "Lewat jadwal" (bukan
   "Kedaluwarsa").
5. Tangguh: tanpa overflow di 320 dp x huruf 1,3, di tablet 1280 x 800, di
   terang dan gelap; label `Semantics` untuk ikon tanpa teks.
6. Hormati `MediaQuery.disableAnimations`; gerak pendek (120 sampai 200 ms).
7. OCR hanya mengusulkan. Sel kosong tetap kosong.

## 6. Cara menjalankan gerbang

Tiga tes deterministik. Ketiganya ikut `flutter test` (dan CI).

| Tes | Berkas | Gagal bila |
|---|---|---|
| Token-only (ratchet dua arah) | `test/tema/token_only_test.dart` + `token_only_baseline.json` | ada berkas BARU, hitungan NAIK, atau hitungan TURUN tanpa baseline diturunkan, untuk: hex mentah, `Color(0x`, konstruktor warna lain (`fromARGB/fromRGBO/from(`, `Color(<desimal>)`, HSL/HSV, Cupertino), `Colors.*`, `fontSize` < 12 (literal, ekspresi angka, variabel literal), radius angka, radius ekspresi campuran, tinggi tombol literal < 48 |
| Kontras | `test/tema/kontras_sidik_test.dart` | pasangan token, `ThemeData`, atau tombol utama di bawah 4,5:1 (teks) atau 3:1 (komponen), terang atau gelap |
| Render 3 ukuran | `test/tampilan/render_layar_lab_test.dart` | layar kunci meluap (RenderFlex) atau galat saat render pada HP 392, 320 dp x 1,3, tablet 1280 x 800, terang atau gelap |

```bash
flutter test test/tema/token_only_test.dart
flutter test test/tema/kontras_sidik_test.dart
flutter test test/tampilan/render_layar_lab_test.dart
```

**Ratchet dua arah.** Pelanggaran lama dibekukan per berkas di
`token_only_baseline.json`; hanya boleh mengecil. Hitungan NAIK atau berkas BARU
= gagal. Hitungan TURUN juga gagal ("turunkan baseline berkas X ke N"): sisa
angka di baseline adalah ruang kosong yang bisa dipakai PR lain untuk
menyelipkan pelanggaran baru. Setelah memperbaiki, turunkan:

```bash
SIDIK_TULIS_BASELINE=1 flutter test test/tema/token_only_test.dart
```

Perintah itu menolak menulis bila ada hitungan yang naik atau berkas baru
(kategori yang belum ada di baseline dibekukan apa adanya, sekali). Folder
`lib/core/theme/` bebas dari kategori warna (di sanalah warna ditulis), tetapi
tetap terkena aturan huruf, radius, dan tinggi tombol.

**Yang tidak bisa dijamin tes.** Tes tidak bisa membandingkan baseline dengan
`origin/main`, jadi menaikkan angka lewat suntingan tangan lolos tes. Aturannya:
kenaikan baseline harus disebut di deskripsi PR dan diperiksa peninjau (diff
`token_only_baseline.json` menampilkan `_ringkasan.total` per kategori). Pemindai
membaca teks, bukan pohon sintaks: ia menangkap literal, ekspresi angka murni,
dan variabel yang di berkas yang sama diisi literal angka; angka yang diselipkan
lewat pemanggilan fungsi atau berkas lain tidak terlihat.

**Cakupan dipatok.** Daftar berkas yang dilewati (`PemindaiToken.dilewati`:
hanya `lib/l10n/` dan `*.g.dart`, dengan alasan) harus sama dengan daftar di
`token_only_test.dart`, jumlah berkas terpindai harus >= 400, dan setiap berkas
di baseline harus ikut terpindai. Menyempitkan gerbang berarti mengubah dua
berkas dan terlihat di diff.

**Render ke PNG** (untuk dilihat mata; tidak ada golden dari mesin non-macOS):

```bash
SIDIK_PNG_DIR=/folder/di/luar/repo flutter test test/tampilan/render_layar_lab_test.dart
SIDIK_LAYAR=login SIDIK_PNG_DIR=... flutter test test/tampilan/render_layar_lab_test.dart
```

Nama berkas: `<layar>.<ukuran>[-gelap].png`. Layar kunci ada di
`_layarKunci` pada berkas harness; tambahkan layar baru di sana begitu ia punya
`Mock*Service`.

**Utang luapan.** Kombinasi yang sudah meluap sebelum gerbang ada dicatat di
`_utangLuapan` pada harness (nilai = batas px). Tidak boleh bertambah parah, dan
tes gagal bila utangnya sudah lunas supaya daftarnya dibersihkan.

**Golden macOS** (`test/screenshot_test.dart`, `test/screenshots/`) tetap dijaga CI
macOS (`periksa-pr.yml`). Perubahan token mengubah tampilan semua golden:
perbarui lewat jalur `golden-baru.yml`, jangan `--update-goldens` di Windows.

## 7. Keputusan dan penyimpangan dari brief

- **Material 3 + token tema terpusat, tanpa library UI baru.** Komponen tetap
  widget Material yang ditema di `SidikTheme`; tidak memakai forui, shadcn_ui,
  fossui, atau library komponen lain. Alasan: hampir semua layar sudah memakai
  widget Material, dan tujuan paket ini mengganti nilai di bawah nama lama tanpa
  menyunting layar.
- **Isian tetap garis bawah**, bukan kotak (brief 5.5 meminta kotak). Alasan:
  `NeuTextField` (login) dibangun di atas bentuk ini dan kotak menggandakan
  tepinya (terlihat di render pertama), dan ~100 isian lain ikut bergeser. Gaya
  isian tunggal (kotak) = paket lembar kerja 5b. Garisnya sudah garis tegas 3:1.
- **`colorScheme.outline` terang = `#5F6B7E`** (bukan garis tegas `#6B7588`).
  `outline` dipakai 22 tempat sebagai warna TEKS dan ikon redup, jadi harus 4,5:1
  di kertas dan baki; `#6B7588` hanya 4,41:1 di baki (`#F8F9FC`). Garis tegas
  komponen tetap `#6B7588`. Gelap memakai garis tegas apa adanya (4,65:1).
- **`AppSpacing.radiusLg` = 8** (dulu 16), `radiusMd` = 10, `radiusSm` = 8. Pemakai
  `radiusLg` semuanya kartu atau panel (19 tempat); tidak ada tombol atau lembar
  bawah yang memakainya.
- **Amber status berbeda dari Pelanggan**: terang `#8C5C0A` (Pelanggan
  `#7A4F08`), gelap `#DB9A2B` (Pelanggan `#F2B655`). Nilai Pelanggan hampir sama
  terangnya dengan merah (terang, beda 0,004) dan hijau (gelap, beda 0,005),
  sehingga gagal aturan "lulus, gagal, awas beda luminans >= 0,02" yang menjaga
  fotokopi hitam-putih dan mata buta warna. Nilai baru tetap >= 4,9:1 di semua
  permukaan teks dan 5,1:1 (terang) / 6,1:1 (gelap) di latar tipisnya. Kandidat
  untuk disamakan balik ke Pelanggan (pindah nilai itu ke sana).

### Utang yang tercatat (bukan lingkup paket ini)

- Radius di luar set di berkas jalur lain: `arsip_screen.dart:120`
  (`AppSpacing.radiusLg + 4` = 12). Kategori ekspresi lain ada di baseline
  (`radius_ekspresi`).
- Kontras mode gelap pada pasangan LITERAL yang tidak terlihat gerbang token
  (hanya token dan tema yang dijaga): `calibration_detail_screen.dart:196,213`
  (kotak catatan revisi `AppColors.cobaltSoft` tetap `#DCE6FA` dengan teks tema
  gelap `#E6EAF2` = 1,04:1) dan `batal_sertifikat_dialog.dart:190-193` (tombol
  bahaya `Colors.white` di `m.gagal` gelap `#FF8FA0` = 2,17:1). Sudah ada sebelum
  paket ini; perbaikan di paket layar (4/5), bukan lewat token.
- `AppColors.cobalt` itu konstanta (bukan sadar tema) dan dipakai apa adanya di
  tema gelap (`profile_screen.dart`, `technician_pulse_panel.dart`,
  `calibration_detail_screen.dart`): 1,77:1 terhadap permukaan gelap bila
  dipakai sebagai garis atau ikon.

## 8. Status migrasi

- Paket 0 (gerbang): ada. Paket 1 (fondasi token, nilai baru di bawah nama lama): ada.
- Berikutnya: komponen bersama (stempel status satu sumber, baris daftar, bilah
  aksi, panel bacaan angka), rangka dan navigasi, layar daftar satu per satu,
  lembar kerja.
- Yang masih memakai nilai lama sampai paketnya tiba: label HURUF BESAR
  (`toUpperCase`) di layar, ukuran huruf literal < 12 dan radius literal di
  layar (tercatat di baseline), dua sistem status (`StatusBadge` dan
  `StatusSidik`), skala huruf tablet yang lebih besar.

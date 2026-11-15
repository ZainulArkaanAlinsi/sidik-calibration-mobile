# Standar kualitas desain: app Lab (sidik-calibration-mobile)

Berlaku untuk setiap perubahan tampilan di app Lab (`lib/screens`, `lib/widgets`,
`lib/core/theme`). Ringkasan standar kualitas desain Sidik, disesuaikan untuk Lab.
Gerbang otomatis ada di bagian "Cara menjalankan gerbang".

Arah visual sejak L1b (15 Nov 2026): **Biru Awan** (`docs/desain-ulang/`). Lembar
kerja dan "02 Pilih alat" TIDAK memakainya: lihat bagian 10 "Area beku".

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

- **Biru Awan**: satu keluarga biru (primer `#1C6FC4`, primerTua `#0F4F94`, langit
  `#5BB4F5`, awan `#A9D8FB`, kabut `#E4F2FD`) di atas latar `#F3F7FB` dan tinta
  navy `#0B2545`. "Biru Awan" hanya nama palet: TIDAK ada gambar awan. Kobalt
  `#043EA1` tinggal untuk logo PT SIDIK (`kobaltLogo`) dan area beku.
- **Datar**: baris dan panel dipisah garis halus, bukan bayangan. Tanpa gradien,
  tanpa bayangan dalam, tanpa tekstur logam. Bayangan hanya untuk lembar bawah
  dan dialog.
- **Status = isi berwarna + tinta navy**: hijau (lulus, disetujui), kuning (perlu
  dicek, revisi), koral (ditolak, tak terbaca), awan (menunggu approval).
  Rancangan (`flutter/palet_lab_biru_awan.dart`): FAIL "Tidak memenuhi toleransi"
  = stempel navy pekat + teks putih, tidak dilunakkan. **Kode L1b BELUM
  mengikutinya**: stempel lama `NadaStempel.gagal` (`status_tampil.dart`) masih
  `m.gagal` `#A81B33` di atas `kabutGagal`; stempel FAIL baru dibangun di L3
  (bagian 11, butir 12).
- **Dua keluarga huruf**: Inter untuk seluruh antarmuka; IBM Plex Mono hanya
  untuk nilai ukur dan nomor (sertifikat, order, serial). Kedua font sudah ada
  di `assets/fonts`; tidak ada font atau paket baru.
- **Identitas dari dunia ukur**, bukan dari hiasan: angka ukur berlebar tetap,
  stempel status, dan motif skala (busur dengan tik dan jarum, `aset/motif_skala.svg`)
  satu per hero, diam. Itu satu-satunya hiasan.
- **Tanda yang dihindari** (bawaan generik): gradien ungu-biru, semua kartu
  satu radius dan satu bayangan, semua rata tengah, teks abu di atas latar
  berwarna, emoji sebagai ikon, ilustrasi stok, lima warna aksen bersaing,
  label HURUF BESAR di atas tiap judul, "A · B · C" sebagai pemisah.

## 3. Token (satu sumber)

Nilai mentah hanya ditulis di `lib/core/theme/palet_lab.dart` (nama sama dengan
`docs/desain-ulang/tokens.json`); area beku punya salinannya di `palet_beku.dart`.
Layar membaca lewat `SidikMaterial.of(context)`, `Theme.of(context).colorScheme`,
`AppColors` (nama lama; nilainya LAMA, lihat bagian 10), `BentukBiruAwan`,
`UkuranBiruAwan`, dan `textTheme`.

### Warna

| Peran | Nama | Terang | Gelap |
|---|---|---|---|
| Aksi, fokus, sel aktif | `primer` | `#1C6FC4` | `#7CC4F6` |
| Teks dan ikon biru | `primerTua` | `#0F4F94` | `#A9D8FB` |
| Permukaan sorot (hero, ubin) | `langit` | `#5BB4F5` | `#28649B` |
| Stempel "menunggu approval" | `awan` | `#A9D8FB` | (tidak ada) |
| Sel terisi, ubin terpilih | `kabut` | `#E4F2FD` | `#173452` |
| Latar halaman | `latar` | `#F3F7FB` | `#0B1626` |
| Kartu, panel, dock | `kertas` | `#FFFFFF` | `#13243A` |
| Tinta (juga "navy") | `tinta` | `#0B2545` | `#E6EEF7` |
| Keterangan | `tinta2` | `#4A5D78` | `#A9B9CC` |
| Pemisah, tepi kartu (hiasan) | `garisHalus` | `#E8EEF5` | `#2A4260` |
| Garis dekoratif (bidang tanda tangan) | `garisTegas` | `#C5D5E6` | (tidak ada) |
| **Tepi kontrol** (isian, tombol sekunder, chip, sakelar, centang) | `garisKontrol` | `#7C8FA8` | `#7C8FA8` (`garisTegasGelap`) |
| Teks di atas `primer` gelap | `teksDiAtasPrimerGelap` | | `#0B1626` |

Status terang (isi; tinta di atasnya SELALU navy `#0B2545`):

| Status | Isi | Kontras navy |
|---|---|---|
| Lulus, disetujui | `hijau` `#BFE6C4` | 11,23 |
| Perlu dicek, revisi | `kuning` `#F6D36B` | 10,59 |
| Ditolak, tak terbaca | `koral` `#F2957A` | 6,85 |
| Menunggu approval | `awan` `#A9D8FB` | 10,19 |
| Netral (draf) | `netralStempel` `#EEF2F6` | |
| Batang |kor|+U lewat toleransi, tepi isian galat | `koralBatang` `#E0684A` | |
| Latar tipis galat | `kabutGagal` `#FDE3DA` | |

Status tema gelap dan teks galat BELUM ada di `tokens.json`: lihat "Utang desain"
di bagian 11.

Pemetaan ke `SidikMaterial` (nama lama, isi Biru Awan): `meja` = `latar`,
`meja2` = `kabut`, `kertas` = `kertas`, `kertas2` = `latar` (isian dan baki
cekung), `kertasTepi` dan `garis` = `garisHalus`, `logamTepi` (= getter
`garisTegas`) = `garisKontrol`, `biru` = `primer`, `biruTipis` = `kabut`,
`biruTinta` = `primerTua`, `biruAtas` = `primerGelap` (biru di atas permukaan
gelap, Lajur Bacaan), `lulusTipis`/`awasTipis`/`tungguTipis` = `hijau`/`kuning`/
`awan` dengan `lulus`/`awas`/`tunggu` = navy.

Peta `ColorScheme` yang TIDAK disebut `tokens.json` (dipilih L1b, token terdekat):
`inverseSurface` = `tinta` navy (terang) / `kabutGelap` (gelap), `onInverseSurface`
= `latar` / `tintaGelap`, `inversePrimary` = `primerGelap` (dua tema; snack dan
tooltip), `outline` terang = `tinta2`, `onPrimaryContainer`/`secondary` = `primerTua`.

Teks biru di atas kabut memakai `primerTua` (7,18:1). `primer` di atas kabut
cuma 4,47:1 dan DILARANG sebagai teks, begitu pula teks putih di atas `langit`
(2,26:1). Keduanya dijaga tes negatif di `test/tema/kontras_sidik_test.dart`.

Nama lama dipertahankan sementara: `AppColors.*` dan `SidikMaterial.*` (`meja`,
`kertas`, `logam`, `kaca`, ...) dan alias `PaletLab.kobalt*`/`*Terang`. Layar baru
sebaiknya memakai `colorScheme` dan `SidikMaterial.of(context)`.

### Bentuk (`BentukBiruAwan`; `BentukLab` tetap untuk komponen lama)

| Token | dp | Dipakai |
|---|---|---|
| `isian` / `ikonUbin` | 16 | kotak isian; ikon ubin |
| `kartu` | 24 | kartu draf, baris-panel, antrean (layar yang didesain ulang) |
| `hero` / `dialog` | 28 | hero, panel besar, segmen; dialog |
| `lembarBawah` | 32 | sudut ATAS lembar bawah |
| `dock` | 40 | dock |
| `pil` | 999 | tombol, chip, stempel, kolom cari |

Tema app: tombol (utama, sekunder, teks), chip, dan FAB berbentuk pil; isian
kotak 16; dialog 28; lembar bawah 32. Kartu di tema TETAP `BentukLab.panel` (8):
kartu 24 dibawa layar yang didesain ulang, karena widget lama memotong riak
ketukan dengan radius 8 (`AppSpacing.radiusLg`). `BentukLab` (sel 4, panel 8,
kontrol 10, utama 16, lembar 20) tidak diubah; `AppSpacing.radius*` dan
`SidikMaterial.sudut*` masih membacanya.

### Ukuran sentuh (`UkuranBiruAwan`, `UkuranLab`)

- **Aksi utama 56 dp** (`UkuranBiruAwan.tombolUtama`): `FilledButton` (tema),
  `RagamTombol.utama`, FAB. Satu per layar.
- **Semua aksi lain 48 dp** (`tombolTegas`): tombol sekunder, tombol teks, tombol
  ikon, baris yang diketuk. Kolom cari 56, chip 44, stempel 30, baris daftar 72,
  baris menu 64 (angka lengkap di `UkuranBiruAwan`).
- Desktop Windows 44 dp (alat tunjuk tetikus; `UkuranLab.aksiMeja`, belum ada
  padanan di `UkuranBiruAwan`: keputusan L1b, minta konfirmasi desain).
- Pengecualian terdokumentasi: tombol toolbar di app bar tetap 48 dp.
- **Aturan ini berlaku pada DEFAULT token.** Beberapa layar menimpanya, dan itu
  utang yang dicatat di baseline kategori `tinggi_tombol_kecil`:
  `alur_kerja_screen.dart:665,724,758` (44), `ringkasan_screen.dart:99` (44),
  `banner_pembaruan_windows.dart:114` (40). Yang sah dan tidak dihitung:
  `AppButton(ringkas: true)` 48 (`app_button.dart:65`), `SidikTombol(kecil: true)`
  42 untuk baris padat (di dalam widget, tidak terdeteksi pemindai).

Tinggi isian: `ELEMEN.md` §Isian menulis "kotak 56", sedangkan isian tema ±48 dp
(`isDense` dengan padding vertikal 14, sengaja tidak diubah di L1b agar tidak ada
layar lama yang meluap). `tokens.json` punya `segmenTitik` 56, belum ada di
`UkuranBiruAwan` (komponen segmen L3). Keduanya di bagian 11.

### Tipografi (Inter; skala di `SidikTheme`)

Skala di bawah masih skala LAMA. Skala Biru Awan (`DESIGN.md` §Huruf: judul layar
28/34·800, judul anak 20/26·800, label 16/24·700, dst.) BELUM dipasang di tema:
mengganti berat dan ukuran di tema menggeser tata letak semua layar yang belum
didesain ulang. Dipasang per layar bersama komponennya (L3 dst.).

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
- **Tepi kontrol terang = `garisKontrol` `#7C8FA8`** (3,31:1 di putih, 3,07:1 di
  `latar`), BUKAN `garisTegas` `#C5D5E6`. `DESIGN.md` menulis tepi tombol sekunder
  `#C5D5E6`, tetapi itu cuma ±1,5:1 di putih. `#C5D5E6` tinggal untuk garis
  dekoratif. Gelap memakai `garisTegasGelap` `#7C8FA8` (tidak ada konflik).
- Garis halus (`kertasTepi`, `garis`) hanya pemisah dekoratif. Jangan dipakai
  sebagai satu-satunya penanda sebuah kontrol.
- `colorScheme.outline` dipakai sebagai warna TEKS redup di banyak layar, jadi
  nilainya dijaga 4,5:1 di kertas dan baki (terang: `tinta2`, gelap: garis tegas).
- Teks biru di atas kabut = `primerTua`; `primer` di atas kabut dilarang (4,47:1).
  Teks putih di atas `langit` dilarang (2,26:1).
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
macOS (`periksa-pr.yml`). Perubahan token mengubah tampilan golden layar yang
memakai tema app: perbarui lewat jalur `golden-baru.yml`, jangan
`--update-goldens` di Windows. Golden area beku (`test/beku/goldens/` dan enam
`lembar-kerja-*`/`lembar-chlorine-alat-kepilih` di `test/screenshots/`) TIDAK
boleh ikut berubah oleh perubahan token (bagian 10).

## 7. Keputusan dan penyimpangan dari brief

- **Material 3 + token tema terpusat, tanpa library UI baru.** Komponen tetap
  widget Material yang ditema di `SidikTheme`; tidak memakai forui, shadcn_ui,
  fossui, atau library komponen lain. Alasan: hampir semua layar sudah memakai
  widget Material, dan tujuan paket ini mengganti nilai di bawah nama lama tanpa
  menyunting layar.
- **Isian = kotak radius 16** sejak L1b (Biru Awan; sebelumnya garis bawah, karena
  kotak menggandakan tepi `NeuTextField` di login). Tepi 1 dp `garisKontrol`,
  fokus primer 2 dp, galat `koralBatang` 2 dp. Layar yang didesain ulang memakai
  komponen isian baru; layar lama ikut bentuk ini (campuran sementara).
- **`colorScheme.outline` terang = `tinta2`** (`#4A5D78`), bukan tepi kontrol
  (`#7C8FA8`, 3,3:1). `outline` dipakai 22 tempat sebagai warna TEKS dan ikon
  redup, jadi harus 4,5:1 di kertas dan baki. Gelap memakai garis tegas apa adanya.
- **`AppSpacing.radiusLg` = 8** (dulu 16), `radiusMd` = 10, `radiusSm` = 8; tidak
  diubah di L1b (`app_spacing.dart` beku).
- **Amber status berbeda dari Pelanggan** (kini berlaku untuk tema GELAP saja;
  status terang memakai `tokens.json`): gelap `#DB9A2B` (Pelanggan `#F2B655`). Nilai Pelanggan hampir sama
  terangnya dengan merah (terang, beda 0,004) dan hijau (gelap, beda 0,005),
  sehingga gagal aturan "lulus, gagal, awas beda luminans >= 0,02" yang menjaga
  fotokopi hitam-putih dan mata buta warna. Nilai baru tetap >= 4,9:1 di semua
  permukaan teks dan 5,1:1 (terang) / 6,1:1 (gelap) di latar tipisnya. Kandidat
  untuk disamakan balik ke Pelanggan (pindah nilai itu ke sana).

### Keputusan L1b "Token Biru Awan" (15 Nov 2026)

- **Tepi kontrol `garisKontrol`**, menyimpang dari `DESIGN.md` (bagian 4).
- **Tinta status terang = navy.** `SidikMaterial.lulus/awas/tunggu` = `tinta`,
  `*Tipis` = isi hijau/kuning/awan. Nilai amber lama `#8C5C0A` cuma 3,96:1 di atas
  `kuning`, jadi tidak bisa dipertahankan. Stempel lama (`SidikLencana`,
  `StatusTampil`) otomatis berpenampilan Biru Awan.
- **`SidikMaterial.gagal` terang tetap `#A81B33`** (teks galat, utang): koral
  `#F2957A` cuma 2,2:1 sebagai teks di atas putih, sedangkan `colorScheme.error`
  dipakai sebagai TEKS galat di banyak layar. `gagalTipis` = `kabutGagal`.
- **`pensil` (saran OCR) terang = `tinta2`**, bukan nilai lama `#5F6B7E`: nilai lama
  cuma 3,7:1 di atas `kuning` (dasar sel "dari foto, perlu dicek", 4,61:1 dengan
  `tinta2`).
- **Tombol mati terang** berisi `netralStempel`, bukan `tungguTipis` (sekarang
  `awan`, terbaca sebagai stempel "menunggu").
- **Desktop tetap 44 dp** untuk tombol (tetikus); `UkuranBiruAwan` tidak punya
  ukuran meja.
- **Kartu tema tetap 8**, skala huruf tema tetap lama, `AppSpacing`/`BentukLab`/
  `UkuranLab` tidak diubah.

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
- Paket 2 (komponen bersama, bagian 9): ada, belum dipakai layar mana pun.
- Desain ulang Biru Awan: L0 (golden lembar kerja) dan L1a (tema beku) ada;
  **L1b (token Biru Awan di tema app) ada**. Berikutnya: elemen dan komponen
  Biru Awan (L2, L3), lalu layar satu per satu (L5 dst.).
- **Layar campuran sementara** (sampai layar itu didesain ulang): layar non-beku
  membaca `colorScheme`/`SidikMaterial` yang SUDAH Biru Awan, tetapi `AppColors.*`
  (141 pemakaian di 37 berkas) masih nilai kobalt lama, jadi satu layar bisa
  memadukan keduanya (mis. teks `AppColors.ink` di kartu `kertas` Biru Awan).
- Yang masih memakai nilai lama sampai paketnya tiba: label HURUF BESAR
  (`toUpperCase`) di layar, ukuran huruf literal < 12 dan radius literal di
  layar (tercatat di baseline), dua sistem status (`StatusBadge` dan
  `StatusSidik`), skala huruf tablet yang lebih besar.

## 9. Komponen bersama (Paket 2)

Berkas baru di `lib/widgets/sidik/`, belum dipakai layar mana pun: Paket 3 sampai
5 menyambungkannya per layar. Semuanya dari token (`lib/core/theme/`:
`ukuran_komponen.dart` untuk ukuran, `warna_lajur.dart` untuk warna Lajur), tanpa
paket atau font baru.

| Berkas | Komponen | Menggantikan |
|---|---|---|
| `status_tampil.dart`, `stempel.dart` | `StatusTampil` (SATU pemetaan kode atau jadwal ke kata, nada, ikon) dan `Stempel` (persegi sudut 4, ikon + kata; draf bergaris tepi tanpa isi; `tenang` tanpa latar) | `StatusBadge` dan `StatusSidik`/`SidikLencana` |
| `baris_daftar.dart` | `BarisDaftar`: baris tanpa kartu, min 64 dp, pemisah garis halus, stempel di kanan (di bawah teks bila < 360 dp atau huruf > 1,15x) | kartu seragam di daftar |
| `tombol_utama.dart`, `bilah_aksi.dart` | `TombolUtama` (56 dp, alasan di atasnya saat mati) dan `BilahAksi` (utama 56 + sekunder 48; berdampingan 88 dp bila satu sekunder, >= 360 dp, huruf <= 1,15x, selain itu bertumpuk 144 dp; maks 560 dp) | tombol penuh lebar bertumpuk |
| `skala_tempo.dart` | `SkalaTempo`: batang berpenggaris (tik per 30 hari), tik jadwal, penanda hari ini, kata; batang HANYA untuk Segera (<= 30 hari), Lewat jadwal, dan detail alat | baris "Lewat 4 hari" |
| `skala_sel.dart` | `SkalaSel`: satu tik per sel (dikelompokkan di atas 60 sel), terisi penuh dan kosong bergaris tepi | teks "N dari M" |
| `navigasi_adaptif.dart` | `NavigasiAdaptif`, `BarNavigasi`, `RailNavigasi`, `TujuanLab`: 5 tab admin (Beranda, Persetujuan dengan lencana, Kalibrasi, Arsip, Lainnya), 2 tab teknisi, rail 80 dp mulai 900 dp, tanpa navigasi tetap untuk < 3 tujuan di layar lebar | `FloatingNavBar`, rail lama |
| `keadaan_kosong_galat_offline.dart` | `KeadaanKosongGalatOffline` (tiga ragam, satu tindakan, tanpa ilustrasi) dan `BannerOffline` | teks kosong buatan tiap layar |
| `lajur_bacaan.dart` | `LajurBacaan`: panel gelap untuk sel yang sedang diisi (angka Plex Mono 40/56 sp, keypad 52/64 dp, "Berikutnya" merentang 3 baris) | papan ketik sistem di sel |

Aturan yang dikunci tes (`test/komponen_sidik/`, `test/tema/kontras_komponen_test.dart`,
`test/tampilan/render_komponen_lab_test.dart`):

- Status = ikon + kata; "Lewat jadwal" dan "Masa berlaku berakhir", tidak ada
  "Kedaluwarsa"; kapital hanya PASS dan FAIL. Kata status dari ARB (`stempel*`,
  Indonesia dan English); `StatusTampil.dariKode` memetakan SEMUA kode yang
  dipakai app (enum sesi, alat, akun, label dokumen sertifikat, dan kode dua
  sistem lama), dan tesnya menurunkan daftar kode dari enum dan sumber itu:
  kode baru yang tak dipetakan membuat tes gagal.
- Komponen yang bisa diketuk memasang `onTap` pada `Semantics` pembungkusnya:
  `excludeSemantics` tanpa itu membuang aksi ketuk milik `InkWell`.
- **Lajur Bacaan tidak menghitung, tidak memvonis, tidak mewarnai hijau atau
  merah, dan tidak menampilkan selisih** (selisih mana yang bermakna per alat
  masih pertanyaan untuk lab). Ia memakai ulang `terapkanTombolKeypad` dan
  `bolehKeypadLayar` dari `lib/screens/calibration/widgets/keypad_angka.dart`
  apa adanya (aturan koma desimal tidak ditulis ulang); "Berikutnya" di sel
  kosong tidak mengisi apa pun; papan ketik sistem tetap bisa dipakai
  (`ModeLajur.ringkas`, `onPakaiPapanKetik`).
- Tab kedua admin bernama "Antrean" di SEMUA lebar (keputusan pemilik): tab
  tidak berganti nama menurut perangkat. Judul layarnya "Antrean persetujuan"
  (Paket 4) dan nama semantiknya "Antrean persetujuan, N menunggu" memuat kata
  yang terlihat (Voice Access, WCAG 2.5.3). Label navigasi tidak dipotong
  "Bera...": skala huruf label diturunkan dari skala sistem sampai kata muat,
  tetapi tidak pernah di bawah 12 sp. Konsekuensi yang disengaja: navigasi tidak
  sepenuhnya mengikuti pembesaran huruf pengguna (seperti NavigationBar Material
  yang membatasi skala labelnya); di bawah ±280 dp label bisa terpotong sebagai
  pilihan terakhir. Pantau di uji perangkat.
- Urutan baca keypad Lajur per baris (7 8 9 hapus, 4 5 6 Berikutnya, 1 2 3,
  minus 0 koma), bukan per kolom pohon widget.
- Pemeriksa berkas yatim (`tool/cek-berkas-yatim.sh`) menghitung berkas yang
  diimpor dari `test/` sebagai terpakai. Pengimpor sah komponen belum-terpakai
  adalah galeri render (`test/support/galeri_komponen.dart`, mengimpor semuanya)
  dan tes widget masing-masing; `test/komponen_sidik/pendaftaran_komponen_test.dart`
  memastikan berkas komponen baru tercatat di `test/support/daftar_komponen.dart`,
  diimpor galeri, dan punya tes. Pemeriksanya tidak diubah.

Render ke PNG:

```bash
SIDIK_PNG_DIR=/folder/di/luar/repo flutter test test/tampilan/render_komponen_lab_test.dart
SIDIK_HALAMAN=lajur,skala SIDIK_PNG_DIR=... flutter test test/tampilan/render_komponen_lab_test.dart
```

### Utang komponen (Paket 2, dicatat peninjau independen)

- Kalimat bawaan `SkalaTempo.kataTempo` dan `LabelLajur` hanya Indonesia
  (keduanya bisa disuntik: `kata`, `LabelLajur`); layar yang memakainya di Paket 3
  sampai 5 harus menyuntik terjemahan, atau kuncinya ditambah ke ARB saat itu.
  Kata status, label tab, dan hint tab sudah di ARB (`stempel*`, `navLab*`).
- Papan ketik sistem sebagai cadangan di mode keypad hanya tersedia bila layar
  mengirim `onPakaiPapanKetik` (opsional). Paket 5 WAJIB mengirimnya.
- `lajur_bacaan.dart` mengimpor `lib/screens/calibration/widgets/keypad_angka.dart`
  (arah impor terbalik, hanya dibaca). Pindahkan `terapkanTombolKeypad` dan
  `bolehKeypadLayar` ke `lib/widgets/sidik/` setelah PR kamera merge.
- Stempel sesi tampil "Menunggu"; brief 5.7 menulis "Menunggu persetujuan".
  Usul: teks "Menunggu", nama semantik "Menunggu persetujuan". Belum diputuskan.
- Peta lembar (kolom tablet) dan gerak 160/200 ms belum ada.
- Catatan desain mata: tik pengulangan Lajur (12 x 4 dp) kecil; baris daftar di
  320 dp x 1,3 bisa melebihi 150 dp (stempel pindah ke baris sendiri) sehingga
  kepadatan daftar hilang; baris "Lewat jadwal" mengulang sinyal yang sama
  (stempel, ekor merah, penanda, kalimat) tanpa hierarki; lencana merah di bar
  berwarna sama dengan "gagal". Nilai ulang di Paket 3 dengan data nyata.

## 10. Area beku (jangan berubah saat token berganti)

Keputusan pemilik (14-15 Nov 2026): tampilan lembar kerja, pratinjau sertifikat,
dan "02 Pilih alat" TIDAK berubah walau token tema diganti. Daftar dan alasannya
di `docs/desain-ulang/BEKU.md`; ringkasnya:

| Area | Cara dibekukan | Penjaga |
|---|---|---|
| Lembar kerja (17 berkas), `tabel_perhitungan`, `sertifikat_pdf_view`, onboarding, `app_button`, `app_text_field`, `sidik_loader`, `status_badge`, `app_spacing` | hash SHA-256 | `test/beku/berkas_beku_test.dart` |
| Tampilan semua layar beku | golden | `test/beku/lembar_kerja_golden_test.dart` (20 PNG) + 6 golden `lembar-kerja-*`/`lembar-chlorine-alat-kepilih` di `test/screenshots/` |
| Tema dan palet beku | `lib/core/theme/palet_beku.dart`, `tema_beku.dart` (salinan nilai 14 Nov 2026, di-hash) | `test/tema/tema_beku_test.dart` (nilai literal) |
| Pemasangan tema beku | `BekuLembarKerja(child: ...)` di SETIAP pemanggil route | `test/beku/tema_beku_terpasang_test.dart` (memindai `lib/`) |
| "02 Pilih alat" (`category_picker_screen`, `instrument_picker_screen`) | sama, TANPA hash (bukan beku resmi) | `test/beku/picker_dan_sertifikat_beku_test.dart` (piksel sama dengan tema beku, warna kunci = `PaletBeku`) |
| Pratinjau sertifikat di `history/certificate_screen.dart` (`_IdentitasSesi`, `_TabelLaporan`, `_StandarDipakai`) | sama | `picker_dan_sertifikat_beku_test.dart` |

Aturan:

- Pemanggil BARU layar atau area di atas wajib membungkusnya
  `BekuLembarKerja(child: ...)` dari LUAR (di `MaterialPageRoute`, `showDialog`,
  dan sejenisnya), bukan di dalam `build`; pemindai gagal bila lupa.
- `AppColors` membaca `PaletBeku`, bukan `PaletLab`. Layar yang didesain ulang
  berhenti memakai `AppColors` dan membaca `SidikMaterial.of(context)`.
- `SidikMaterial.teksDiBiru`/`teksDiGagal` membaca `PaletLab`, bukan `TemaBeku`:
  layar beku dan "02 Pilih alat" tidak boleh memakainya (peringatan di getter).
- Komponen Biru Awan untuk tombol, isian, loader, dan stempel dibuat BARU
  (`lib/widgets/biru_awan/`); widget beku bersama tidak disentuh.
- Tema yang berlaku di area beku dan tema app sengaja berbeda: tes
  `token_tema_lab_test.dart` ("tema app BUKAN tema beku") gagal bila keduanya
  kebetulan sama, supaya tes pembungkus tidak hampa.
- Berkas beku butuh persetujuan pemilik untuk diubah; golden beku harus lolos
  TANPA diperbarui di setiap PR.

## 11. Utang desain Biru Awan (jawaban desain yang masih dibutuhkan)

Dibuat L1b (15 Nov 2026). Tiap butir memakai nilai LAMA atau pengganti sementara
sampai desain menjawab; semuanya di `lib/core/theme/palet_lab.dart` dan
`sidik_material.dart`.

1. **Status tema gelap** (`lulusGelap`, `awasGelap`, `gagalGelap`, `tungguGelap`
   dan latar tipisnya, `gagalDiAtasGelap`): `tokens.json` hanya punya warna gelap
   untuk merek dan netral. Nilai lama kobalt-era dipertahankan.
2. **Teks galat terang** (`gagalTerang` `#A81B33`): `ELEMEN.md` §Isian menyebut
   kalimat galat `#A3261A`, `tokens.json` tidak punya. Keputusan: L1b TIDAK
   menggeser warna teks galat; `#A3261A` dipakai di L2 saat elemen isian/galat baru
   dibangun, lalu masukkan ke `tokens.json`.
3. **Pensil OCR gelap** (`pensilGelap`): belum ada di `tokens.json`; terang
   memakai `tinta2` (lihat bagian 7).
4. **Warna di atas `awan`, `hijau`, `kuning` untuk teks non-navy**: tidak ada.
   Semua tinta status = navy; ikon/teks status berwarna (hijau, amber) di luar
   stempel belum didefinisikan.
5. **Tepi kontrol** `garisKontrol` `#7C8FA8` menyimpang dari `DESIGN.md`
   ("OutlinedButton tepi #C5D5E6"): minta `DESIGN.md` dan `tokens.json`
   disesuaikan (tambah `garisKontrol`, jadikan `garisTegas` dekoratif).
6. **Isian mati** (`ELEMEN.md`: latar `#F3F7FB`) belum dipasang di tema: tema memberi
   tepi `garisHalus`, isi tetap putih.
7. **Sakelar 56 x 36** dan ukuran meja (desktop 44) belum punya token.
8. **Skala huruf Biru Awan** belum dipasang (bagian 3, Tipografi).
9. **Kartu 24** belum dipasang di tema (bagian 3, Bentuk).
10. **Isian login dan lupa sandi**: `NeuTextField` (collapsed) tetap ikut
    `enabledBorder` tema, jadi login dan lupa sandi dibungkus `IsianNeuLama`
    (`lib/screens/auth/widgets/isian_neu_lama.dart`) yang mengembalikan
    `inputDecorationTheme` lama. Hapus bersama `NeuTextField` saat login
    didesain ulang (L5). Pengguna `NeuTextField` hanya dua layar itu.
11. **Alias sementara** `PaletLab.kobalt*`/`*Terang` dan nama lama `SidikMaterial`
    (`meja`, `logam`, ...): dihapus di PR terakhir (L13).
12. **Stempel FAIL** belum mengikuti rancangan (navy pekat + teks putih): kode
    memakai `m.gagal` `#A81B33` di atas `kabutGagal` (detail-sesi tampil merah di
    atas merah muda). Warna tidak diubah di L1b; dikerjakan bersama stempel baru L3.
13. **Tepi kontrol di atas kabut dan kabutGagal < 3:1** (hasil hitung, tes
    pendokumentasi di `kontras_sidik_test.dart`, ambang 3:1 tidak dilonggarkan):
    `garisKontrol` `#7C8FA8` di atas `kabut` 2,90:1 dan `kabutGagal` 2,70:1
    (di atas putih 3,31, `latar` 3,07). Pemakai nyata: tepi segmen terpilih
    `SegmentedButton` (isi kabut; `sidik_theme.dart`; dipakai `kirim_email_screen`,
    `profile_screen`, `ukur_ocr_screen`, `undang_anggota_dialog`; terpilih juga
    ditandai isi dan centang). Mungkin: tepi stempel netral (`stempel.dart`) bila
    ditaruh di baris berisi kabut, mis. baris terpilih. Tidak ditemukan kontrol
    bertepi di atas `kabutGagal` (hanya banner tanpa tepi). Perlu keputusan desain:
    tepi lain (mis. `primerTua`) untuk kontrol di atas kabut.
14. **Peta `ColorScheme`, tinggi isian, `segmenTitik`**: lihat bagian 3 (dipilih L1b,
    belum disetujui desain).
15. **`SidikMaterial.lulus/awas/tunggu` terang = navy** (tinta status selalu navy):
    isyarat warna hilang di tema terang pada layar yang memakai tinta status di latar
    polos (`simulasi_versi_acuan_screen`, `studio_acuan_screen`); tema gelap tetap
    hijau/amber. Tetap ikon + kata. Ditangani saat layar itu didesain ulang.
16. **Hex `PaletLab` tidak dikunci ke `tokens.json`**: `kontras_sidik_test` hanya
    menghitung rasio pasangan (`closeTo(dokumen, 0.02)`); mengubah `garisDekor`,
    `navyTeks`, atau menggeser satu digit `kuning` tidak ketahuan. Tes literal
    seperti `tema_beku_test` dijadwalkan bersama tes token L2.

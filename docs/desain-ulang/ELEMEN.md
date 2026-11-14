# ELEMEN — komponen umpan balik buatan sendiri (berlaku di app Lab dan Pelanggan)

Artboard: E0 Masuk, E1 Splash, E2 Elemen, E6 Elemen lanjutan (canvas Lab). Satu bentuk untuk satu
tujuan. Pelanggan memakai bentuk yang sama dengan paletnya sendiri (kolom kanan).

| Elemen | Lab (Biru Awan) | Pelanggan (Bento Lab) |
|---|---|---|
| Aksi di toast | primer #1C6FC4 | navy #0B1F4B |
| Kabar masuk | navy #0B2545 + logo | navy #0B1F4B + logo |
| Splash latar / cincin | #F3F7FB / primer | #EEF0F3 / kuning #F6D36B |
| Kosong | ubin langit + motif skala | ubin kuning + visual alat |

## Toast (`ToastSidik`) — mengganti SEMUA `SnackBar` (±242 pemakaian di Lab)
- Kartu putih, lebar = layar − 32 (maks 420), min tinggi 68, radius 22,
  padding 12/8/12/12, bayangan 0 12 30 navy 16 %.
- Ubin ikon 40 radius 14: sukses hijau (centang), info kabut (i), peringatan
  kuning (segitiga), galat koral (×). Judul 15/800, isi 13/18 tinta2.
- Aksi opsional: pil 40 primer. Tutup: tombol 40 (×) tinta2.
- Varian **kabar masuk** (`KabarToast` dari push/realtime): kartu navy, ubin
  putih berisi logo, teks putih/navyTeks, aksi pil putih "Buka". Dedup per id (aturan lama).
- Posisi: atas, 16 dp di bawah status bar. Masuk geser turun + pudar 240 ms; keluar 160 ms.
- Satu toast sekaligus (yang baru menggantikan yang lama).
- Hilang sendiri 4 dtk untuk sukses/info; peringatan 6 dtk; **galat dan toast beraksi
  tidak hilang sendiri**. Usap ke atas untuk menutup.
- Aksesibilitas: `SemanticsService.announce(judul + isi)`; tombol berlabel.
- API: `tampilkanToast(context, jenis:, judul:, isi:, aksi:, onAksi:)` dari
  `flutter/toast_sidik.dart`. Ganti `ScaffoldMessenger.of(context).showSnackBar`
  bertahap per layar yang disentuh; layar BEKU tetap memakai SnackBar lamanya.

## Dialog konfirmasi (`DialogSidik`)
Lebar maks 340 (HP) / 420 (lebar), radius 28, padding 24, ubin ikon 56 radius 20,
judul 20/26·800, isi 14/20 tinta2. Tombol baris: Batal (sekunder) kiri, aksi kanan.
Aksi bahaya: merah tua #A3261A + kata kerja jelas ("Hapus", "Tarik sertifikat"),
tidak pernah "OK"/"Ya". Latar redup navy 42 %.

## Lembar bawah (`LembarBawahSidik`)
Radius atas 32, pegangan 44 × 5 #C5D5E6, padding 10/16/20, judul 20/800 + tombol
tutup 44. Maks 80 % tinggi layar, isi bergulir. Tutup: usap turun / ketuk latar.
Isian di dalamnya memakai isian standar; tombol utama penuh di bawah.

## Banner (menempel di bawah kepala layar)
- Tanpa koneksi: pil navy 48, ikon wifi coret, "Tanpa koneksi. Data terakhir 08.42".
- Pembaruan tersedia: pil langit 56 + tombol navy "Pasang" (pembaruan WAJIB = dialog).
- Peringatan data (standar segera habis, server lambat): kartu kuning tipis #FFF4D1 radius 20.

## Keadaan
- **Memuat**: kerangka (kartu putih dengan blok #E8EEF5 berdenyut 1,2 dtk) untuk
  daftar; spinner 36 primer hanya bila tunggu > 400 ms. Ini SATU-SATUNYA gerak
  berulang yang boleh, dan berhenti begitu data datang.
- **Kosong**: ubin langit radius 24 + motif skala + judul 20/800 + kalimat + satu aksi navy.
- **Galat**: ubin koral tipis #FDE3DA + ubin ikon koral 48 + judul + kalimat
  (pesan server apa adanya bila ada) + "Coba lagi" (tegas navy 44).

## Splash (`splash_screen.dart`)
Timeline SEKALI jalan (aturan lama tetap: tanpa `repeat()`, `pumpAndSettle` harus selesai):
0–100 ms diam → cincin 168 primer ditarik 700 ms → plat logo putih 128 muncul
(skala 0,92→1, 420 ms, mulai 500 ms) → sapuan cahaya lewat logo 600 ms (900 ms)
→ "SIDIK Lab" 32/800 naik (1100 ms) → "Kalibrasi terakreditasi KAN" (1250 ms)
→ nama PT di bawah (1400 ms) → diam. Latar #F3F7FB + garis penggaris bertik (langit 35 %) di atas pita putih
bawah; cincin logo = busur skala. Kurangi gerak = langsung keadaan akhir.

## Masuk (`login_screen.dart`, artboard E0)
Hero langit 330 setinggi atas dengan motif skala + plat logo 104 + "SIDIK Lab" 28/800;
kartu putih radius 32 menumpang -36 dp: judul 24/800, isian Email, isian Sandi
dengan "Tampilkan", tautan "Lupa sandi?" 44, tombol Masuk 56. Bawah: akreditasi 12.

## Kontrol kecil
Lencana (koral min 22, kuning 26, titik 10) · avatar 36/48/84 (inisial 800) ·
centang dan radio 24 (sentuh 48, tepi mati #7C8FA8) · sakelar 56 × 36 ·
tooltip navy radius 12 (hanya tombol ikon, tekan lama) · progres batang 10 dan tik 8.

## Isian
Label di atas 14/700 (placeholder bukan label) · kotak 56 radius 16 · tepi
#C5D5E6 → fokus primer 2 → galat #E0684A 2 + ikon + kalimat #A3261A → mati
latar #F3F7FB. Wajib ditandai "(wajib)" di label, bukan bintang merah.


## Elemen lanjutan (artboard E6) — hasil audit kode app Lab
Setiap widget bawaan yang dipakai di `lib/` punya bentuk SIDIK. Angka = jumlah
pemakaian hari ini (`grep` di lib/). Komponen di `lib/widgets/biru_awan/`.

| Widget bawaan (pemakaian) | Elemen SIDIK | Bentuk |
|---|---|---|
| SnackBar (249) | `tampilkanToast` | lihat §Toast |
| showDialog / AlertDialog (59/54) | `DialogSidik` | lihat §Dialog |
| showModalBottomSheet (10) | `LembarBawahSidik` | lihat §Lembar bawah |
| DropdownButton / DropdownMenu (35/36) | `PilihanSidik` | isian 56 + panah; membuka lembar bawah berisi daftar (cari bila > 7 opsi), terpilih kabut + centang |
| showDatePicker / showDateRangePicker (12/1) | `TanggalSidik` | kalender di lembar bawah: hari ini cincin primer, terpilih bulat primer, rentang pita kabut, tombol konfirmasi menyebut pilihannya |
| pemilih jam | `JamSidik` | dua kotak mono 72 (jam, menit) + pil pilihan cepat |
| Slider (1) | `PenggeserSidik` | rel 8, kenop 28 putih tepi primer 3, nilai mono di kanan atas |
| PopupMenuButton (7) | `MenuAksiSidik` | tombol titik tiga 44 kabut → kartu putih radius 20, butir 48 + ikon; bahaya merah tua paling bawah + konfirmasi |
| ExpansionTile (5) | `AkordeonSidik` | kepala 60 + panah, isi dipisah garis |
| TabBar (2) | `SegmenPil` (2–3 tab) / `TabGaris` (banyak) | segmen pil 56; atau teks bergaris bawah primer 3, bisa digeser |
| RefreshIndicator (32) | `SegarkanSidik` | indikator busur skala 48 putih + "Diperbarui jam" |
| Dismissible (6) | `GeserAksi` | geser kiri membuka aksi berwarna (arsip kabut/awan, hapus koral); hapus tetap konfirmasi |
| FilePicker (4) | `UnggahBerkas` | zona putus-putus 104, kartu berkas + progres 8 + batal, kartu galat + Ulangi |
| ImagePicker / Image.file (6/4) | `KisiFoto` | kisi 3 kolom radius 16, hapus 32 di pojok, ubin tambah putus-putus |
| LinearProgressIndicator (17) | `ProgresSidik` | rel 8 kabut, isi primer; tak tentu = kerangka, bukan garis berjalan |
| CircularProgressIndicator (31) | `SpinnerSidik` | 36 primer di rel kabut, hanya bila > 400 ms |
| Qr (106) | `KartuQr` | QR di plat putih + nomor mono + Salin + Bagikan |
| google_mlkit_barcode_scanning, CameraPreview | `BingkaiPindai` | kamera gelap, sudut bingkai langit 5, petunjuk di pil putih bawah |
| Signature (10) | `BidangTandaTangan` | bidang putih tepi #C5D5E6 + garis dasar + Hapus/Simpan (pratinjau di sertifikat tetap BEKU) |
| SelectableText / Clipboard (16/2) | `TeksSalin` | baris latar + tombol salin 44 → toast "… disalin" |
| DataTable (4) | `TabelSidik` | kepala kabut 12/800, angka mono rata kanan, gulir mendatar dalam kotak (tabel lembar kerja & PERHITUNGAN BEKU) |
| pdfrx | `BingkaiPdf` | kepala anak + unduh + bagikan + penanda halaman pil navy; isi halaman BEKU |
| FloatingActionButton (6) | dihapus | "tambah" = tombol bulat 48 primer di kepala; satu-satunya tombol melayang = Mulai di dock teknisi |
| Badge (173) | `Lencana` | koral 22 / kuning 26 / titik 10 |
| Tooltip (21) | `TooltipSidik` | navy radius 12, hanya tombol ikon |
| Checkbox / Radio / Switch / SegmentedButton | kontrol kecil | lihat §Kontrol kecil |
| FilterChip / ChoiceChip (6/6) | `ChipSaring` | pil 44 + bulatan jumlah 32 |
| NavigationRail / Drawer (5/5) | rel D1 / laci A3 | lihat LAYAR.md |
| Banner / MaterialBanner (69) | `BannerSidik` | lihat §Banner |
| BackdropFilter (5) | dihapus di layar yang didesain ulang | efek kaca tidak dipakai |
| Share / launchUrl (39/4) | tombol "Bagikan" pil primer / tautan teks | lembar bagikan sistem tetap bawaan OS |

Aturan: widget bawaan polos BOLEH dipakai di dalam komponen SIDIK, tetapi layar
tidak memanggilnya langsung bila padanan di atas ada. Pemakaian di berkas BEKU tidak diubah.

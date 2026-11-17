# REVISI 16 Nov 2026 — arah tenang, formal, ringkas (menggantikan Biru Awan penuh warna)

Sumber: dua dokumen revisi pemilik (REVISI-1 arahan umum, REVISI-2 app Pelanggan,
dipakai sebagai pembanding pola). Berkas ini mencatat bagaimana revisi diterapkan
di app Lab. Di mana `DESIGN.md`, `ELEMEN.md`, `POLA.md`, `LAYAR.md`, `VISUAL.md`,
dan `tokens.json` lama bertentangan dengan berkas ini, **berkas ini menang**.
Berkas lama dibiarkan sebagai arsip sampai layar terakhir selesai dipoles.

Yang TIDAK berubah: logika, alur, API, peran, rute, isi data, hitungan, OCR
(`siap_pindai`, `OCR_FORMULIR_ASLI_UJI`, `PAKAI_MESIN_ANGKA`), aturan sensor dan
pengisian lembar. Dan, perintah pemilik: layar **02 "Pilih alat"** dan **03 "isi
lembar kerja"** (grid, keypad, rumus, pembulatan, alur input) TIDAK berubah
tampilan maupun perilaku, termasuk sebagai efek samping token (lihat "Penjaga 02
dan 03").

## Token (sumber: `lib/core/theme/`, dicocokkan ke `tokens.json`)

| Penggunaan | Sebelum (Biru Awan 15 Nov) | Sekarang |
|---|---|---|
| Latar halaman (`latar`) | `#F3F7FB` | `#F4F7FB` |
| Kartu (`kertas`) | `#FFFFFF` | `#FFFFFF` (tetap) |
| Judul dan teks utama (`tinta`) | `#0B2545` | `#102A43` |
| Teks pendukung (`tinta2`) | `#4A5D78` | `#526477` (6,09:1 di putih) |
| Aksi (`primer`) | `#1C6FC4` | `#1769C2` (putih 5,47:1) |
| Pilihan aktif (`kabut`) | `#E4F2FD` | `#EAF3FF`, selalu dipadukan tepi biru, kapsul, atau ikon terisi |
| Garis halus | `#E8EEF5` | `#DCE5EE` |
| Status | pastel jenuh (hijau `#BFE6C4`, kuning `#F6D36B`, koral `#F2957A`, awan `#A9D8FB`) + tinta navy | tinta GELAP di atas isi MUDA: hijau `#124D2C`/`#E3F3E8`, amber `#8A5500`/krem `#FFF3D6`, merah `#A81B33`/`#FDE8E6`, biru tua `#0A3560`/`#E6F0FA`; selalu ikon + kata; krem HANYA untuk "perlu diperiksa" |
| Biru langit (`langit` `#5BB4F5`, `awan` `#A9D8FB`) | hero, ubin, banner, stempel | tinggal di ilustrasi dan panel kecil (hero login 190 dp, motif keadaan kosong, batang grafik); tidak lagi isi stempel atau banner |
| Radius | kartu 24, hero/dialog 28, lembar 32, dock 40, tombol/stempel/chip/kolom cari pil, isian 16 | kartu/hero/dialog/lembar 16, tombol 10, isian/chip/kolom cari 12, penanda segmen 8, lencana 6; pil (999) hanya lingkaran sungguhan |
| Tinggi tombol dan isian | tombol utama 56, isian 56, kolom cari 56, stempel 30, segmen 56 | 48 (desktop 44), kolom cari 48, stempel 24, segmen 48; baris daftar 72 -> 64 (nama kelas `BarisDaftar72` tetap); sasaran sentuh tetap >= 48 |
| Huruf | Inter 800 (tampil 700), judul layar 28, judul bagian 17, spasi huruf negatif | Inter 400/500/600; judul layar 24, judul anak 20, judul bagian 16, label 14/500, tombol 15/600, stempel 12/600; angka sorot 32, angka kartu 28; tanpa spasi negatif; Plex Mono tetap untuk nomor dan angka ukur |
| Bayangan | dock 0/14/34 @16 %, Mulai primer @40 %, kartu login 0/14/34, toast 0/12/30, dialog 0/20/50, laci elevasi 16 | tidak ada di layar; garis 1 dp. Toast 0/2/8 @10 %, dialog 0/4/16 @14 %, lembar/dialog/laci elevasi 1 |

Nama token lama dipertahankan bila artinya masih dekat (`PaletLab.kuning` sekarang
krem, `PaletLab.koral` sekarang merah muda, `IsiBiruAwan.koral` merah muda). Yang
baru: `PaletLab.hijauTinta`, `kuningTinta`, `biruKelabu`, `biruKelabuTinta`,
`IsiBiruAwan.tunggu`, `BentukBiruAwan.tombol/saringan/penandaSegmen/lencana`,
`UkuranBiruAwan.tinggiBilah/kapsulBilah*`. Dihapus: `BentukBiruAwan.dock`,
`UkuranBiruAwan.butirDock*`, `WarnaBiruAwan.bayanganMulai`.

## Komponen bersama (`lib/widgets/biru_awan/`, `lib/widgets/floating_nav_bar.dart`, shell, auth)

- **Bilah navigasi bawah** (`FloatingNavBar`, nama dipertahankan): permukaan
  putih selebar layar, garis 1 dp di atas, tanpa bayangan dan sudut, SEMUA butir
  berlabel, kapsul kabut 56 x 32 + ikon terisi + kata semibold untuk butir aktif.
  Mulai di tengah (teknisi) datar, 48 dp. Tepi sistem di dalam permukaan.
  Disembunyikan bila papan ketik terbuka. Semantik (label, `selected`, "Tab n dari
  m") dan kontrak (`selectedIndex`, `onSelected`, `items`, `aksiTengah`) sama.
  Label mengecil bersama (satu faktor, tidak di bawah 12 sp) bila tidak muat.
- **Tombol** `TombolSidik`: semua ragam 48, sudut 10; cincin fokus mengikuti sudut.
  `TombolBulat` Mulai tanpa bayangan.
- **Lencana status** `StempelSidik`: 24, sudut 6, ikon 14 + kata 12/600, tinta gelap
  di isi muda; "Menunggu approval" biru kelabu. Stempel lama `Stempel` ikut
  palet baru (sudut 4, 600).
- **Lencana jumlah** (`Lencana`, laci): merah galat penuh + angka putih.
- **Saringan dan segmen terpilih**: biru muda + tepi biru 2 dp + kata navy (bukan
  blok navy); kolom cari 48 sudut 12.
- **Kartu**: `KartuSidik24` sudut 16 datar; `Card` tema 16, dipotong
  (`antiAlias`) supaya riak widget lama tidak keluar dari sudut.
- **Dialog, lembar bawah, laci**: sudut 16, bayangan sangat tipis; ikon dialog
  `primary` (bawaan M3 `secondary` = putih di putih; pelajaran tinjauan
  Pelanggan).
- **Banner**: pembaruan = kotak kabut (bukan bidang langit), tanpa koneksi navy
  48 sudut 12, peringatan krem 16.
- **Keadaan kosong**: kartu putih bergaris, ilustrasi motif kecil, min 200
  (dulu ubin langit 260).
- **Masuk dan splash** (`KerangkaMasuk`): hero langit 190 (dulu 330), plat logo
  72, kartu menumpang 24 sudut 16 bergaris, tanpa bayangan; nama 22/600.

## Beranda teknisi (PR 2; REVISI-1 §7)

`lib/screens/teknisi/kalibrasi_teknisi_screen.dart`. Banner besar dan carousel
draf diganti area kerja ringkas, dari atas: header identitas (logo, nama lab,
lonceng), sapaan, judul "Pekerjaan saya", ringkasan tiga angka (draf, perlu
revisi, menunggu pemeriksaan), tombol utama "Kalibrasi baru" (48), tombol
"Pindai lembar kerja" (bila ada), "Perlu revisi" (kartu dengan catatan utuh),
"Lanjutkan pekerjaan" (draf: DAFTAR VERTIKAL, bukan carousel) dan "Aktivitas
terbaru" (kiriman terakhir). Tiap item draf/kiriman: nama alat, pelanggan,
nomor kalibrasi, waktu pembaruan, status.

Logika data yang sudah dibuktikan di L7a DIPERTAHANKAN: hitungan "menunggu
pemeriksaan" dari kiriman terakhir yang dimuat (kartunya menyebut dasarnya,
"dari {n} kiriman terakhir"); klaim "Semua lembar sudah terkirim." hanya bila
ketiga daftar terbaca dan kosong DAN salinan lembar di HP terbaca dan kosong;
daftar yang gagal atau masih memuat ditulis "–", bukan 0; `drafLokalProvider`
tetap hanya penggerbang klaim. Yang berubah: kalimat 28/800 diganti judul tetap
+ kartu angka (tidak ada kalimat yang bisa terlalu yakin). Waktu pembaruan =
`diubahPada` (atau `dikirimPada` bila itu satu-satunya); tanpa keduanya baris
waktu tidak ditulis. Kartu "Perlu revisi" krem hanya bila ada isinya.

## Penjaga 02 dan 03 (BATAS KERAS pemilik)

Mekanisme yang sudah ada: `TemaBeku`/`PaletBeku` (salinan), `BekuLembarKerja` di
pemanggil, hash berkas beku, golden macOS. Yang R1 tambahkan:

- Jalur kebocoran lewat NILAI BERSAMA yang dibaca area beku di luar tema
  dikunci literal di `test/tema/token_beku_tak_bocor_test.dart`: `BentukLab`,
  `AppSpacing`, `SidikMaterial.sudut*`, `UkuranLab`, `AppUkuran`, tiga konstanta
  `PaletLab` (`kertas`, `teksDiAtasPrimerGelap`, `gagalDiAtasGelap`), dan
  `SidikTheme.gayaAngka`. Semuanya TIDAK diubah: token revisi hidup di
  `BentukBiruAwan`/`UkuranBiruAwan` (baru atau yang tidak dibaca area beku).
- Jalur PEMAKAI: tes yang sama memindai sumber area beku (daftar `BEKU.md`, dua
  layar 02, widget bersama yang mereka impor) dan gagal bila ada yang membaca
  `PaletLab`, `*BiruAwan`, `widgets/biru_awan/`, atau dock.
- Bukti piksel sebelum vs sesudah (Windows, mesin yang sama, deterministik):
  `rincian-r1-lab.md` bagian "Bukti 02 dan 03".

## Belum dikerjakan (PR berikutnya)

Poles layar legacy yang masih memakai berat 700/800 literal dan radius 8
(`SidikPermukaan`, `kertasLembar`; nilainya dibaca `neu.dart`/`tabel_perhitungan`
yang beku), tema gelap (hanya dijaga kontrasnya), layar teknisi sisa
(Draf/Profil), beranda admin dan super admin, layar admin.

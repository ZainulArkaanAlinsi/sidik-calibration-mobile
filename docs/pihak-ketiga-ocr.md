# Pihak ketiga untuk pekerjaan OCR kamera

Daftar ini sengaja ringkas: cukup untuk dirapikan (atribusi/lisensi) nanti.
Diperbarui 12 Nov 2026. Lisensi dibaca dari pub.dev / GitHub API pada tanggal itu.

## Dipakai di kode (Fase 1)

| Apa | Sumber | Versi | Lisensi | Dipakai untuk |
|---|---|---|---|---|
| `image` | https://pub.dev/packages/image | ^4.3.0 (sudah ada sebelumnya) | MIT | kompresi salinan arsip (`lib/services/foto_kompres.dart`) |
| `google_mlkit_text_recognition` | https://pub.dev/packages/google_mlkit_text_recognition | 0.15.1 (sudah ada) | MIT | pembaca teks on-device (tidak berubah) |
| Kode kompresi & deteksi kode formulir | repo ini, PR #223 (`feat/ocr-layout-kompresi-20261110`, TIDAK di-merge) | commit `4b734a5` | milik sendiri | `foto_kompres.dart`, `jenis_lembar.dart`, `test/jenis_lembar_test.dart`, `test/assets/jenis-lembar-fixture.json` (hanya kode; model layout 123 MB dan `flutter_ocr_kit` TIDAK ikut) |

## Dipakai di kode (Fase 2: registrasi halaman, `lib/services/registrasi_halaman/`)

Dependensi BARU: tidak ada. `pubspec.yaml` tidak berubah; tidak ada paket, aset, atau biner native baru. Selisih ukuran APK belum diukur (hanya kode Dart di folder itu; CI yang melaporkan).

| Apa | Sumber | Versi | Lisensi | Dipakai untuk |
|---|---|---|---|---|
| `image` | https://pub.dev/packages/image | ^4.3.0 (sudah ada) | MIT | tipe `img.Image`, decode foto (`registrasiHalamanDariBitaDiIsolate`), baca bita mentah |
| Ambang Otsu | N. Otsu, "A threshold selection method from gray-level histograms", IEEE Trans. SMC 9(1), 1979 | - | metode terbuka, kode ditulis sendiri | memisahkan halaman terang dari alas (`deteksi_sudut_halaman.dart`) |
| Lambung cembung monotone chain | A. M. Andrew, 1979 | - | metode terbuka, kode ditulis sendiri | `geometri_halaman.dart` |
| Persegi panjang pembungkus berluas terkecil (rotating calipers) | Freeman & Shapira, CACM 18(7), 1975 | - | metode terbuka, kode ditulis sendiri | menentukan orientasi halaman untuk memilih sudut kasar |
| Garis kuadrat-terkecil Huber (IRLS) | P. J. Huber, 1964 | - | metode terbuka, kode ditulis sendiri | pengganti `cv2.fitLine(DIST_HUBER)` di prototipe Python; OpenCV hanya jadi ACUAN perilaku prototipe, tidak ada kode OpenCV disalin atau di-link |
| Rasio halaman dari sudut proyeksi | Z. Zhang & L.-W. He, "Whiteboard scanning and image enhancement", Digital Signal Processing 17(2), 2007 | - | rumus terbuka, kode ditulis sendiri | `perkirakanRasioHalaman` (kewajaran rasio halaman) |
| Homografi kuadrat-terkecil + perataan bilinear | repo ini (`registrasi_jangkar_teks.dart`: `Homografi`, `ratakanHalaman`) | sudah ada | milik sendiri | meluruskan foto dari empat sudut |

Data uji (bukan kode aplikasi): `test/fixtures/registrasi_halaman/geometri_prototipe.json`
(41 KB) memuat homografi dan kotak sel (angka saja) dari 26 foto sintetis prototipe 12 Nov
2026 untuk 12 formulir FM-CAL kosong. Tidak ada nilai tulisan, nama pelanggan, atau foto.

## Batas yang diketahui registrasi halaman (12 Nov 2026)

Modul `lib/services/registrasi_halaman/` hanya menghasilkan USULAN sudut halaman; semua
foto ujinya sintetis (belum ada foto nyata). Belum disambung ke alur pindai.

- **Dijamin:** kegagalan yang TERDETEKSI (alas terang, tepi terpotong/melengkung, bentuk tak
  wajar, rasio tak cocok, berkas kosong/terpotong/rusak, masukan `luruskanHalaman` yang tak
  masuk akal) menjadi `RegistrasiHalamanGagal`, tidak pernah sudut tebakan, dan fungsi modul
  tidak melempar pada foto buruk. Salinan arsip terkompresi ditolak (`FotoTerkompresiDitolak`;
  penjaga Fase 1 dipanggil di dalam modul untuk bita sebelum decode dan citra sesudahnya).
- **TIDAK dijamin: "tidak pernah salah".** Satu kelas salah-diam-diam sudah terukur dan
  lolos semua pemeriksaan: halaman di atas lembar/tumpukan kertas LEBIH BESAR dengan rasio
  sama (bantalan, map). Bantalan 6% sisi: galat 3,5–4,3% diagonal foto; 12%: 6,8–7,9%
  (terhadap bantalan hanya 0,03–0,09%). Dikunci sebagai uji "BATAS DIKETAHUI" di
  `test/registrasi_halaman_test.dart`; bila kelas ini kelak ditutup, uji itu dibalik jadi
  "ditolak".
- **Cue "tepi kedua sejajar di dalam 2–15% sisi" dicoba dan TIDAK dipakai.** Garis bingkai
  cetak dan garis tabel formulir menghasilkan cue yang sama: kedalaman garis gelap median per
  sisi di pita itu 32–195 pada 26 foto prototipe, 26–123 pada halaman sintetis tanpa
  bantalan, dan −8–134 pada bantalan 3–12% (pengukuran ad hoc, skrip tidak dikomit).
  Rentangnya tumpang tindih, jadi ambang apa pun menolak halaman sah atau meloloskan
  bantalan. Dibuka lagi hanya bila ada foto nyata.
- **Wajib di sisi pemanggil:** registrasi jangkar teks / kode formulir menjadi pemeriksa
  kedua pada citra hasil SEBELUM sel dibaca; jangkar meleset = jalur lama / input manual.
- **Arah 90°/180° tidak bisa ditentukan dari bentuk.** Adaptor memverifikasi orientasi lewat
  kode formulir / teks cetak (mencoba `putaranKuadran` 0–3 dari sudut yang sama lewat
  `luruskanHalaman`), jatuh ke jalur lama bila tak ada yang cocok. Koordinat sudut memakai
  citra SESUDAH EXIF dipanggang. Adaptor memakai `registrasiHalamanDariBitaDiIsolate`
  (decode dan registrasi di isolate latar).

Ringkasan algoritma dan ambang (diturunkan dari prototipe Python 12 Nov 2026 yang tidak ada
di repo ini; alasan tiap ambang ada di KDoc `OpsiRegistrasiHalaman`): perkecil ke lebar
640 → penutupan abu-abu 7×7 (hapus garis tabel/teks) → ambang Otsu (pemisahan kelas ≥ 50
tingkat abu; kroma ≥ 30) → komponen terang terbesar (25–97% foto) → siluet → lambung
cembung → sudut kasar pada sumbu halaman → garis Huber per sisi → perhalusan puncak gradien
→ kewajaran (tepi tak menempel bingkai foto, sudut dalam 60°–120°, luas ≥ 25%, RMS sisi
≤ 1,2 px, kontras tepi ≥ 20, rasio dalam 12% dari formulir).

Terukur pada foto sintetis (`flutter test`, JIT, laptop): 26 geometri prototipe 26/26, galat
sudut maks 0,16% diagonal foto, 100% sel IoU ≥ 0,7; matriks variasi (alas gelap/sedang/kayu
terang, lanskap-di-potret) 18/18, maks 0,10%; alas krem 6/8 diterima (2 ditolak), alas putih
0/4 (semua ditolak). Deteksi median ±0,3 detik pada lebar kerja 640.

**Belum terbukti:** foto kamera nyata (bantalan, meja berkilap, kertas melengkung, tangan,
pantulan lampu), waktu AOT di ponsel (`tool/ukur_registrasi_halaman.dart` mengukur AOT di
laptop), dan selisih ukuran APK (hanya kode Dart; CI yang melaporkan).

## Dirujuk untuk Fase 2 (belum ada di kode)

| Apa | URL | Versi | Lisensi | Catatan |
|---|---|---|---|---|
| `document_scan` | https://pub.dev/packages/document_scan | 0.5.0 | MIT | deteksi sudut headless; Android memakai OpenCV 4.11.0 (AAR 115 MB 4 ABI). Strategi dokumennya (grayscale, beberapa strategi ambang, hull, kewajaran segi empat) dibaca sebagai IDE; tidak ada kode disalin |
| OpenCV (Android AAR) | https://repo1.maven.org/maven2/org/opencv/opencv/4.11.0/ | 4.11.0 | Apache-2.0 | ditolak: dampak APK besar |
| `opencv_dart` | https://pub.dev/packages/opencv_dart | 2.2.2 | Apache-2.0 | ditolak untuk sekarang: FFI OpenCV, dampak APK belum diukur dan besar. Cadangan bila Dart murni gagal pada foto NYATA: dipasang di balik signature `deteksiSudutHalaman(img.Image) -> HasilDeteksiHalaman` yang sama |
| `google_mlkit_document_scanner` | https://pub.dev/packages/google_mlkit_document_scanner | 0.7.2 | MIT | alternatif; butuh Google Play services |
| `cunning_document_scanner`, `edge_detection` | https://pub.dev/packages/cunning_document_scanner , https://pub.dev/packages/edge_detection | 3.1.0 / 1.1.3 | MIT / Apache-2.0 | hanya dibandingkan, tidak dipakai |
| FormCharRecognition | https://github.com/amirmgh1375/FormCharRecognition | - | TIDAK ADA lisensi | hanya ide (urut kontur baris), kode tidak disalin |
| tabular-data-digitalizer | https://github.com/ohidurbappy/tabular-data-digitalizer | - | TIDAK ADA lisensi | hanya ide, kode tidak disalin |

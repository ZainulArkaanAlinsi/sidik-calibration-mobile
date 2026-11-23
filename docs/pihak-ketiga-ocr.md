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

## Mesin angka tulisan tangan (Fase 3, `lib/services/ocr_angka/`)

Dependensi BARU: tidak ada (13 Nov 2026). Tidak ada paket atau biner native baru: runtime inferensi adalah
`tflite_flutter` 0.12.1 / LiteRT 1.4.0 yang SUDAH ada di APK. `pubspec.yaml` hanya menambah aset
(`assets/models/ocr_angka_en.tflite` +7,83 MB, meta, dan crop uji sintetis ±126 KB). ONNX Runtime ditolak
karena melewati batas ukuran pemilik. Rincian ukuran per-ABI, opsi, dan hasil rig: `docs/ocr-angka-onnx.md`.

| Apa | Sumber | Versi | Lisensi | Status |
|---|---|---|---|---|
| `en_PP-OCRv5_mobile_rec_onnx` → `ocr_angka_en.tflite` | https://huggingface.co/PaddlePaddle/en_PP-OCRv5_mobile_rec_onnx | rev `3fafbc3b`; ONNX 7.848.423 bita dikonversi `onnx2tf` 2.6.9 ke TFLite float32 7.829.508 bita | Apache-2.0 | DIBUNDEL di APK (`assets/models/`), dimuat hanya bila sakelar developer menyala; sha256 dipatok |
| `flutter_onnxruntime` | https://pub.dev/packages/flutter_onnxruntime | 1.9.0 (6 Okt 2026) | MIT | DITAHAN: ORT 1.28.0 menambah ±49 MB mentah ke APK dua-ABI |
| `com.microsoft.onnxruntime:onnxruntime-android` | Maven Central | 1.28.0 | MIT | dibawa plugin di atas; diukur dari AAR, tidak dipakai |
| `com.microsoft.onnxruntime:onnxruntime-mobile` | Maven Central | 1.18.0 (rilis terakhir paket itu) | MIT | opsi, belum dicoba (±7,8 MB dua-ABI) |
| `tflite_flutter` / LiteRT | pub.dev | 0.12.1 / 1.4.0 | Apache-2.0 | sudah ada (±7,2 MB di APK dua-ABI); KINI TERPAKAI mesin angka (`interpreter_mentah_tflite.dart`) di balik sakelar developer |

Kode (milik sendiri, metode terbuka): pengubah ukuran bilinear 11-bit ala OpenCV `INTER_LINEAR`
(`praproses_sel.dart`, OpenCV hanya ACUAN perilaku, tidak ada kode disalin), dekode CTC greedy, persentil linier.
Fixture uji `test/fixtures/ocr_angka/` (±174 KB): logits dan crop SINTETIS dari rig, tanpa tulisan teknisi.

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

## Pelaporan galat: Sentry (19 Nov 2026, paket LAB-UI-2 butir 4)

Keputusan pemilik 19 Nov 2026. **Nonaktif kecuali build diberi `--dart-define=SENTRY_DSN=...`**; tidak ada DSN di
repo (dijaga `test/pelapor_galat_sentry_test.dart`). Tanpa DSN: SDK tidak diinisialisasi, tidak ada penangkap, tidak
ada panggilan jaringan. Hanya Android/iOS (aplikasi HP); desktop dan web dilewati. Kode: `lib/core/pelapor_galat_sentry.dart`
(dipasang `lib/main.dart`, di samping Crashlytics lewat `PelaporGalatGabungan`).

| Apa | Sumber | Versi | Lisensi | Dipakai untuk |
|---|---|---|---|---|
| `sentry_flutter` | https://pub.dev/packages/sentry_flutter | 10.5.0 (17 Nov 2026); syarat Dart >=3.12, Flutter >=3.44 (lock sudah mensyaratkan keduanya; CI 3.44.6) | MIT | pelapor galat, berpenyaring (di bawah) |
| `sentry` (Dart inti) | https://pub.dev/packages/sentry | 10.5.0 (transitif) | BSD-3-Clause | inti SDK |
| `jni` | https://pub.dev/packages/jni | 1.1.2 (sudah ada di lock sebagai transitif 1.0.3; `sentry_flutter` mensyaratkan ^1.1.0; 1.2.0 DITARIK pub.dev, tidak dipakai) | BSD-3-Clause | jembatan Android milik plugin |
| `io.sentry:sentry-android` + `sentry-native-ndk` | Maven Central | 8.64.0 / 0.17.6 | MIT | dibawa plugin di Android (tidak ditulis di pubspec) |

**Yang keluar dari HP** (sama dengan jalur Crashlytics): hanya NAMA JENIS galat (`GalatTersaring`) + jejak tumpukan
kode kita + label konteks buatan kode + versi aplikasi (`versi+build`). Pesan galat tidak pernah ikut. Tiga lapis:
(1) `PelaporGalatSentry.catat` hanya mengirim jenis dan membuang galat jaringan/4xx; (2) `terapkanOpsiSentry` mematikan
tangkapan layar, hierarki tampilan, semua breadcrumb (`maxBreadcrumbs = 0`), badan permintaan HTTP, PII bawaan, sesi,
replay, performa (`tracesSampleRate = 0`, semua transaksi/log/metrik dibuang), laporan klien, dan daftar paket, serta
mencabut penangkap galat milik SDK sendiri; (3) `beforeSend` membuang pesan, pengguna, request, extra, konteks perangkat,
host, path absolut, dan tag di luar whitelist. Crash native tetap dilaporkan Crashlytics, bukan Sentry.

**Sisi native Android: BELUM diuji di HP (koreksi 19 Nov 2026).** Versi awal dokumen ini keliru menulis bahwa SDK native
"tidak dinyalakan" dan bahwa penangkap crash native dicabut oleh opsi Dart. Yang benar (dari kode `sentry_flutter` 10.5.0 dan
bytecode `sentry-android-core` 8.64.0):
- SDK native HARUS hidup begitu DSN diisi, karena event Dart dikirim lewat transport native (`FileSystemTransport`);
  `autoInitializeNativeSdk` dibiarkan bawaan (true). Tanpa DSN, SDK tidak pernah berjalan (provider auto-init dicabut).
- `enableNativeCrashHandling = false` HANYA mematikan handler pengecualian native dan ANR. NDK (`enableNdk`) bawaannya TRUE
  dan tidak dipetakan Flutter, jadi penangkap crash NDK aktif begitu DSN diisi, dan event native TIDAK melewati `beforeSend` Dart.
- Karena itu `android/app/src/main/AndroidManifest.xml` kini memuat meta-data yang dibaca SDK native SEBELUM callback Flutter:
  `io.sentry.ndk.enable=false` (+ `ndk.scope-sync`, `ndk.app-hang`, `anr`, `tombstone`, `uncaught-exception-handler`,
  `auto-session-tracking`, `attach-screenshot`, `attach-view-hierarchy`, `attach-threads`, `send-default-pii`,
  `send-client-reports`, `max-breadcrumbs=0`, semua `breadcrumbs.*`, `logs.enabled`, `metrics.enabled`). Nama kunci diperiksa dari
  bytecode `ManifestMetadataReader` 8.64.0. Dijaga `test/sentry_manifest_test.dart` (kunci ada, nilai mati, himpunan izin tidak berubah).
- BELUM terbukti di perangkat: bahwa meta-data benar-benar mematikan NDK, dan apa yang dikirim native saat DSN diisi. Residu yang
  diketahui: kode Flutter menyetel `logs.enabled`/`metrics.enabled` native menjadi true SESUDAH manifest (aplikasi tidak memakai
  API log/metrik Sentry, dan log/metrik Dart dibuang `beforeSend*`). Pemilik menguji di HP asli dengan DSN uji sebelum DSN rilis
  dipasang; periksa envelope yang tiba di Sentry (tidak boleh ada event native).

**Dampak APK (PERKIRAAN, belum diukur dengan build rilis).** Dari berkas Maven Central: `libsentry.so` arm64-v8a
887.712 bita mentah (317 KB terkompresi) + `libsentry-android.so` 20 KB; armeabi-v7a 588 KB mentah (284 KB terkompresi);
Java `sentry-android-core` 517 KB + `-replay` 376 KB + `-ndk` 13 KB (AAR, sebelum R8). Ditambah kode Dart AOT `sentry` +
`sentry_flutter`. Perkiraan total **sekitar +1,5 sampai +2,5 MB per APK arm64** (dua-ABI arm64+arm32: sekitar +2 sampai +3 MB).
Angka pasti = bandingkan `flutter build apk --release` sebelum dan sesudah.

**Izin Android: tidak bertambah.** Manifest plugin hanya MENCABUT `SentryInitProvider` (tanpa auto-init); manifest
`sentry-android-core` hanya menyatakan `INTERNET`, yang sudah ada di aplikasi.

**Yang BELUM diverifikasi (wajib lewat CI sebelum rilis):** build Windows/macOS/Linux dan Web (plugin ini membawa kode
native `sentry-native` untuk desktop dan pod `Sentry` untuk macOS), dan perilaku di HP nyata dengan DSN sungguhan.
Mengisi `SENTRY_DSN` di workflow rilis adalah keputusan pemilik (berkas workflow tidak diubah paket ini).

## Google Cloud Vision (OCR awan, lewat backend) — diizinkan 23 Nov 2026, BAWAAN MATI

Keputusan pemilik 23 Nov 2026. **Bukan paket Flutter dan bukan SDK di aplikasi**: aplikasi tidak memuat apa pun dari
Google untuk ini. Aplikasi hanya mengirim foto halaman ke backend kita (`POST /api/ocr/halaman`); backend yang memanggil
`vision.googleapis.com` (fitur `DOCUMENT_TEXT_DETECTION`) dengan kredensial service account di env server.

| Apa | Sumber | Dipakai untuk | Batasan |
|---|---|---|---|
| Google Cloud Vision API, `images:annotate` | https://cloud.google.com/vision/docs/ocr | OCR mentah seluruh halaman (blok, kata, kotak, keyakinan) | hanya dari backend; bawaan mati; hasil usulan |

**Yang keluar dari HP ke server kita:** foto halaman utuh. **Yang diteruskan server ke Google:** foto halaman utuh (nama
pelanggan dan nomor sertifikat ikut terbaca di gambar). Gambar dan teks hasil tidak disimpan di log; log hanya mencatat waktu,
unit, ukuran, durasi, dan status.

**Syarat menyalakan untuk teknisi sungguhan (belum terpenuhi):** pemilik memastikan kontrak pelanggan mengizinkan foto halaman
dikirim ke pihak ketiga dan ISO/IEC 17025 bagian 4.2 tidak dilanggar. **Tidak ada kunci/kredensial Google di kode Flutter atau
di APK.** Tidak ada klaim akurasi atau biaya sebelum diukur dengan foto uji nyata berlabel manusia (satu unit = satu gambar
masih ASUMSI). Kontrak: `docs/kontrak-api.md` bagian 22 di repo API.


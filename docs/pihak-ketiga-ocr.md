# Pihak ketiga untuk pekerjaan OCR kamera

Daftar ini sengaja ringkas: cukup untuk dirapikan (atribusi/lisensi) nanti.
Diperbarui 12 Nov 2026. Lisensi dibaca dari pub.dev / GitHub API pada tanggal itu.

## Dipakai di kode (Fase 1)

| Apa | Sumber | Versi | Lisensi | Dipakai untuk |
|---|---|---|---|---|
| `image` | https://pub.dev/packages/image | ^4.3.0 (sudah ada sebelumnya) | MIT | kompresi salinan arsip (`lib/services/foto_kompres.dart`) |
| `google_mlkit_text_recognition` | https://pub.dev/packages/google_mlkit_text_recognition | 0.15.1 (sudah ada) | MIT | pembaca teks on-device (tidak berubah) |
| Kode kompresi & deteksi kode formulir | repo ini, PR #223 (`feat/ocr-layout-kompresi-20261110`, TIDAK di-merge) | commit `4b734a5` | milik sendiri | `foto_kompres.dart`, `jenis_lembar.dart`, `test/jenis_lembar_test.dart`, `test/assets/jenis-lembar-fixture.json` (hanya kode; model layout 123 MB dan `flutter_ocr_kit` TIDAK ikut) |

## Dirujuk untuk Fase 2 (belum ada di kode)

| Apa | URL | Versi | Lisensi | Catatan |
|---|---|---|---|---|
| `document_scan` | https://pub.dev/packages/document_scan | 0.5.0 | MIT | deteksi sudut headless; Android memakai OpenCV 4.11.0 (AAR 115 MB 4 ABI) |
| OpenCV (Android AAR) | https://repo1.maven.org/maven2/org/opencv/opencv/4.11.0/ | 4.11.0 | Apache-2.0 | ditolak: dampak APK besar |
| `opencv_dart` | https://pub.dev/packages/opencv_dart | 2.2.2 | Apache-2.0 | ditolak: FFI OpenCV, dampak APK belum diukur dan besar |
| `google_mlkit_document_scanner` | https://pub.dev/packages/google_mlkit_document_scanner | 0.7.2 | MIT | alternatif; butuh Google Play services |
| `cunning_document_scanner`, `edge_detection` | https://pub.dev/packages/cunning_document_scanner , https://pub.dev/packages/edge_detection | 3.1.0 / 1.1.3 | MIT / Apache-2.0 | hanya dibandingkan, tidak dipakai |
| FormCharRecognition | https://github.com/amirmgh1375/FormCharRecognition | - | TIDAK ADA lisensi | hanya ide (urut kontur baris), kode tidak disalin |
| tabular-data-digitalizer | https://github.com/ohidurbappy/tabular-data-digitalizer | - | TIDAK ADA lisensi | hanya ide, kode tidak disalin |

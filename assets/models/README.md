# assets/models

Berkas di sini TIDAK terdaftar di `pubspec.yaml` dan tidak ikut APK.

- `ocr_angka_en.meta.json` — meta model pembaca angka (`MetaModelOcr`): sha256, versi,
  kolom keluaran, ambang, dan penanda bukti `SINTETIS`. Salinan sumber untuk
  dititipkan bersama model ke perangkat.
- `ocr_angka_en.onnx` — **belum ada di repo**. Model resmi PaddlePaddle
  (`en_PP-OCRv5_mobile_rec_onnx`, Apache-2.0, 7.848.423 bita). Unduh dari URL dan revisi di
  meta, periksa sha256, lalu titipkan ke `…/files/ocr-ukur/` di tablet (lihat
  `docs/ocr-angka-onnx.md`, bagian "Mengukur di tablet").

Model sengaja belum dibundel: tanpa runtime inferensi di app, 7,8 MB itu bobot mati.
Mendaftarkannya di `pubspec.yaml` menunggu keputusan runtime.

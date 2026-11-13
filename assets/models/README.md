# assets/models

Yang terdaftar di `pubspec.yaml` (dua berkas, BUKAN seluruh folder) dan ikut APK:

- `ocr_angka_en.tflite` — model pembaca angka sel (PP-OCRv5 en, `onnx2tf` dari ONNX asli, float32,
  7.829.508 bita, sha256 `e1121d54…43b7`, Apache-2.0). Masukan `[1,48,320,3]`, keluaran `[1,40,438]`
  peluang softmax. Ikut APK walau sakelar developer `PAKAI_MESIN_ANGKA` mati (bawaan); baru DIMUAT bila
  sakelar menyala dan sha256-nya sama dengan yang dipatok di `muat_mesin_bawaan.dart`
  (`sha256ModelDipercaya`). Bukti akurasinya SINTETIS.
- `ocr_angka_en.meta.json` — meta model (`MetaModelOcr`): berkas, sha256, kolom keluaran, ambang, penanda
  bukti `SINTETIS`.

`README.md` ini tidak terdaftar. Menukar model: `docs/ocr-angka-onnx.md` bagian 9;
`test/ocr_angka_tflite_aset_test.dart` menjaga aset, meta, dan pin tetap sama. Model asal ada di rig
`sidik-ocr-eval/models/ppocrv5_en_tflite/` (`rec_en_f32.tflite`; bukan `rec_en_f16w`, bukan INT8).

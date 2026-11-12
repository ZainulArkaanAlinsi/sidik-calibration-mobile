# ocr_angka — pembaca angka tulisan tangan per sel (on-device)

Murni Dart; semuanya diuji di CI tanpa runtime native. Dasar keputusan: laporan rig
`10-uji-mesin-angka.md` (SEMUA ANGKA SINTETIS). Penjelasan lengkap: `docs/ocr-angka-onnx.md`.

Alur satu sel: `pagar_tinta` → `praproses_sel` → `SesiInferensiCtc` (model) → `dekoder_ctc`
→ `keputusan_sel` (ambang `jalur` + `aturan_format_sel`).

| berkas | tugas |
|---|---|
| `aturan_format_sel.dart` | gerbang format: jumlah desimal + boleh-negatif dari templat server |
| `praproses_sel.dart` | crop → tensor `[1,3,48,W]`, bilinear ala OpenCV (sama dengan rig) |
| `dekoder_ctc.dart` | pilih kolom whitelist, CTC greedy, skor `jalur` |
| `pagar_tinta.dart` | sel tanpa tinta tidak dikirim ke model |
| `keputusan_sel.dart` | status: kosong / perluCek / usulanKeyakinanTinggi |
| `meta_model.dart` | baca dan periksa `meta.json` (sha256, kolom, bukti) |
| `sesi_inferensi.dart` | jahitan ke runtime (BELUM ADA implementasi nyata) |
| `mesin_angka.dart` | menyambung semuanya per sel |
| `muat_mesin.dart`, `sumber_model_ocr.dart`, `muat_mesin_bawaan.dart` | gerbang muat model, sumber aset/folder |
| `ukur_ocr.dart`, `ukur_ocr_jalankan.dart` | logika layar diagnostik `Ukur OCR` |

Aturan keras: foto tidak keluar HP; hasil hanya USULAN dan tetap diperiksa teknisi per sel;
sel kosong tetap kosong; tulisan tangan tidak pernah hijau; skor `jalur` bukan persen.
Pembaca untuk alur pindai: `lib/services/pembaca_sel_onnx.dart` (di balik sakelar developer
`PAKAI_MESIN_ANGKA_ONNX`, bawaan mati).

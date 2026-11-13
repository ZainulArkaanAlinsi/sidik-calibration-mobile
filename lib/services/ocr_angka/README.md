# ocr_angka — pembaca angka tulisan tangan per sel (on-device)

Murni Dart kecuali satu berkas (`interpreter_mentah_tflite.dart`); semuanya diuji di CI tanpa runtime
native memakai pelari/sesi tiruan. Dasar keputusan: laporan rig `10-uji-mesin-angka.md` (SEMUA ANGKA
SINTETIS). Penjelasan lengkap: `docs/ocr-angka-onnx.md` (nama berkas masih `onnx`; runtime-nya **TFLite**,
`tflite_flutter` 0.12.1 / LiteRT 1.4.0 yang sudah ada di APK).

Alur satu sel: `pemotong_sel` (garis tabel dihapus, hanya tulisan milik baris, dipangkas ke kotak tinta)
→ `pagar_tinta` (hanya `gelap`) → `praproses_sel` → `SesiInferensiCtc` (model) → `dekoder_ctc`
→ `keputusan_sel` (ambang `jalur` + `aturan_format_sel`).

| berkas | tugas |
|---|---|
| `aturan_format_sel.dart` | gerbang format: jumlah desimal + boleh-negatif dari templat server; "0" polos hanya bila templat menandai `boleh_bulat` (field USULAN, belum ada di server) |
| `praproses_sel.dart` | crop → tensor `[1,3,48,W]` (CHW, BGR), bilinear ala OpenCV (sama dengan rig) |
| `dekoder_ctc.dart` | pilih kolom whitelist, CTC greedy, skor `jalur`; `sudahPeluang` = keluaran TFLite sudah softmax |
| `pemotong_sel.dart` | pemotong sel v2 (varian "luas" rig): dari halaman lurus + kotak sel → crop per baris. Meluber vertikal, hapus garis tabel mendatar (hanya yang di tepi atas/bawah kotak; garis datar di tengah = tulisan), jembatani goresan yang melintas garis, komponen terhubung milik baris, pangkas ke kotak tinta. Bila ragu → `HasilPotongSel.sebabTakYakin` (`perluCek`, model tidak jalan). Dipanggil di isolate perataan `JalankanPindaiAsli` |
| `pagar_tinta.dart` | sel tanpa tinta tidak dikirim ke model; SATU penentu: `gelap >= gelapMin` (sementara, dari 2 foto). Crop yang ADA tetapi ditolak pagar (tinta pudar, rasio 0,70–0,78) = `perluCek`/`tintaPudar`, bukan kosong |
| `keputusan_sel.dart` | status: kosong / perluCek / usulanKeyakinanTinggi. Sel BERTINTA yang tak menghasilkan bacaan (model diam, pemotong ragu) = `perluCek` tanpa bacaan (`perluCekTanpaBacaan`), BUKAN kosong |
| `meta_model.dart` | baca dan periksa `meta.json` (sha256, kolom, bukti) |
| `sesi_inferensi.dart` | jahitan ke runtime (`SesiInferensiCtc`, `KeluaranCtc`, `SesiLebarTetap`) |
| `sesi_inferensi_tflite.dart` | adaptor TFLite: CHW → NHWC `[1,48,320,3]`, periksa kontrak tensor, muat malas satu kali, tutup; lebar TETAP 320. `PabrikSesiTfliteBersama` memuat model sekali per proses (alur pindai membuat pembaca baru tiap foto; `fromBuffer` membocorkan 7,8 MB per muat) |
| `pelari_tflite.dart` | `PelariTfliteIsolate`: satu isolate pekerja yang memegang interpreter (bukan `IsolateInterpreter` bawaan paket); seam `InterpreterMentah` |
| `interpreter_mentah_tflite.dart` | satu-satunya berkas yang menyentuh `tflite_flutter` (tidak diuji di host; dibuktikan `integration_test/ocr_tflite_hp_test.dart`) |
| `interpreter_mentah_tflite_stub.dart` | pengganti tanpa `dart:ffi` untuk WEB (`buat` melempar `UnsupportedError` → `runtimeGagalDimuat` → ML Kit). `sesi_inferensi_tflite.dart` memilihnya lewat `import '..._stub.dart' if (dart.library.ffi) '....dart'`; tanpa itu `flutter build web` gagal (`tflite_flutter` mengimpor `dart:ffi`). Antarmuka publik kedua berkas harus tetap sama |
| `mesin_angka.dart` | menyambung semuanya per sel |
| `muat_mesin.dart`, `sumber_model_ocr.dart`, `muat_mesin_bawaan.dart` | gerbang muat model, sumber aset/folder |
| `ukur_ocr.dart`, `ukur_ocr_jalankan.dart` | logika layar diagnostik `Ukur OCR` |

Pemotong v2 hanya untuk jalur pindai formulir asli: `PembacaSelMesin.bacaMesin` menerima crop sel apa adanya
(ML Kit cadangan + tampilan review) DAN hasil pemotong (mesin angka). Sel `perluCekTanpaBacaan` masuk
`HasilBacaAsli.gagalDibaca` (jalur review MERAH kosong yang sudah ada). Alat paritas Dart-vs-rig:
`tool/ukur_pemotong_sel.dart` (masukan dari `SIDIK_PARITAS_DIR`, tanpa data nyata di repo).

Aturan keras: foto tidak keluar HP; hasil hanya USULAN dan tetap diperiksa teknisi per sel;
sel kosong tetap kosong; tulisan tangan tidak pernah hijau; skor `jalur` bukan persen.
Pembaca untuk alur pindai: `lib/services/pembaca_sel_onnx.dart` (di balik sakelar developer
`PAKAI_MESIN_ANGKA`, nama lama `PAKAI_MESIN_ANGKA_ONNX` tetap diterima; bawaan MATI, ML Kit tetap pembaca
bawaan). Model: `assets/models/ocr_angka_en.tflite` (7,83 MB, SINTETIS, sha256 dipatok di
`muat_mesin_bawaan.dart`). Sakelar mati = `buatSesiOcrAngkaProvider` `null`: model tidak dibuka. Gagal muat
runtime/model, atau galat saat membaca satu sel → ML Kit, tanpa crash. Sel bertinta yang hasil resize-nya
> 320 px ditahan `MesinAngka` (`ukuranTakWajar`) dan dibaca ML Kit oleh `PembacaSelOnnx`; sel tanpa tinta
tetap kosong. Pemuatan runtime yang gagal diingat per proses (maks. 2 percobaan, lalu aset tak dibaca lagi). Yang TIDAK terbukti: inferensi di perangkat Android (lihat bagian 6-7 dokumen).

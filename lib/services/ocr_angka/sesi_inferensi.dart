import 'dart:typed_data';

/// Keluaran model per sel: peluang `[frame, kelas]` baris demi baris.
class KeluaranCtc {
  const KeluaranCtc({
    required this.nilai,
    required this.frame,
    required this.kelas,
    this.sudahPeluang,
  });

  final Float32List nilai;
  final int frame;
  final int kelas;

  /// `true` = [nilai] sudah PELUANG softmax per frame (TFLite hasil konversi)
  /// dan dipakai apa adanya; `false` = logit, di-softmax dulu; `null` = tak
  /// diketahui, ditebak dari jumlah baris pertama (perilaku lama, ONNX).
  /// Sesi yang tahu bentuk keluaran modelnya sebaiknya mengisi ini: tebakan
  /// meleset pada keluaran yang tidak utuh (kolom dipangkas, frame pertama
  /// tidak berjumlah 1) dan meratakan skor tanpa galat.
  final bool? sudahPeluang;
}

/// Jahitan ke runtime inferensi.
///
/// Seluruh logika angka (praproses, dekode, gerbang, keputusan) ada di
/// `lib/services/ocr_angka/` dan diuji di CI TANPA runtime. Yang butuh native
/// cukup mengimplementasikan kelas ini.
///
/// Implementasi nyata: `SesiInferensiTflite` (`tflite_flutter` 0.12.1 / LiteRT
/// 1.4.0 yang sudah ada di APK; keputusan 13 Nov 2026). ONNX Runtime tidak
/// dipakai: +29..57 MB ke APK dua-ABI, lihat `docs/ocr-angka-onnx.md` bagian 4.
abstract class SesiInferensiCtc {
  /// Jalankan model pada [masukan] = tensor `[1, 3, 48, lebar]` (CHW, BGR).
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar);

  Future<void> tutup();
}

/// Sesi yang hanya menerima SATU lebar kanvas, karena bentuk masukan modelnya
/// statis (TFLite `[1,48,320,3]`). Model ONNX asli berlebar dinamis dan
/// mempertahankan aspek; model berlebar tetap harus menekan crop yang lebih
/// lebar dari kanvasnya, dan itu mengubah bacaan. `MesinAngka` menahan sel
/// seperti itu (`ukuranTakWajar`) alih-alih menebak, dan `PembacaSelOnnx`
/// menyerahkannya ke ML Kit.
///
/// Antarmuka terpisah (bukan anggota [SesiInferensiCtc]) supaya sesi tiruan
/// yang sudah ada tidak perlu diubah.
abstract interface class SesiLebarTetap {
  /// Lebar kanvas masukan model, dalam piksel.
  int get lebarTetap;
}

/// Pabrik sesi dari byte model. Boleh melempar: pemanggil menjatuhkan pembaca
/// ke ML Kit tanpa menumbangkan aplikasi.
typedef BuatSesiCtc = Future<SesiInferensiCtc> Function(Uint8List model);

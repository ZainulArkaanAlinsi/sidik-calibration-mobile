import 'dart:typed_data';

/// Keluaran model per sel: peluang `[frame, kelas]` baris demi baris.
class KeluaranCtc {
  const KeluaranCtc({
    required this.nilai,
    required this.frame,
    required this.kelas,
  });

  final Float32List nilai;
  final int frame;
  final int kelas;
}

/// Jahitan ke runtime inferensi (ONNX Runtime, LiteRT, atau lainnya).
///
/// Seluruh logika angka (praproses, dekode, gerbang, keputusan) ada di
/// `lib/services/ocr_angka/` dan diuji di CI TANPA runtime. Yang butuh native
/// cukup mengimplementasikan kelas ini.
///
/// **Belum ada implementasi nyata di repo ini** (12 Nov 2026): pustaka native
/// ONNX Runtime menambah ±49 MB ke APK dua-ABI, di atas batas pemilik; lihat
/// `docs/ocr-angka-onnx.md` bagian "Keputusan dependensi".
abstract class SesiInferensiCtc {
  /// Jalankan model pada [masukan] = tensor `[1, 3, 48, lebar]` (CHW, BGR).
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar);

  Future<void> tutup();
}

/// Pabrik sesi dari byte model. Boleh melempar: pemanggil menjatuhkan pembaca
/// ke ML Kit tanpa menumbangkan aplikasi.
typedef BuatSesiCtc = Future<SesiInferensiCtc> Function(Uint8List model);

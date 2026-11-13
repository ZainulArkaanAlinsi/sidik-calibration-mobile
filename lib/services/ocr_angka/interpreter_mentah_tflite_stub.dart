import 'dart:typed_data';

import 'pelari_tflite.dart';

/// Pengganti `interpreter_mentah_tflite.dart` untuk platform TANPA `dart:ffi`
/// (web). Dipilih lewat impor bersyarat di `sesi_inferensi_tflite.dart`:
///
/// ```dart
/// import 'interpreter_mentah_tflite_stub.dart'
///     if (dart.library.ffi) 'interpreter_mentah_tflite.dart';
/// ```
///
/// `package:tflite_flutter` mengimpor `dart:ffi` (dan `package:ffi`); kompilator
/// web menolaknya, sehingga satu impor langsung ke berkas aslinya membuat
/// `flutter build web` gagal walau mesin angka tidak pernah jalan di web.
///
/// Antarmuka publik IDENTIK dengan berkas asli: kelas [InterpreterMentahTflite]
/// dan pabrik `static buat`. Di sini `buat` melempar [UnsupportedError]. Pemanggil
/// (`SesiInferensiTflite.dariByte` → `muatMesinAngka`) menangkapnya sebagai
/// `PenolakanMesin.runtimeGagalDimuat`, jadi pembaca jatuh ke ML Kit tanpa crash,
/// persis seperti pustaka native yang gagal dimuat di Android.
///
/// Android, iOS, dan desktop (termasuk Sidik Studio) punya `dart.library.ffi`
/// dan tetap memakai berkas asli.
class InterpreterMentahTflite implements InterpreterMentah {
  InterpreterMentahTflite._();

  /// [PabrikInterpreterMentah] bawaan; selalu gagal di platform ini.
  static InterpreterMentah buat(Uint8List model, int thread) =>
      throw UnsupportedError(
        'TFLite butuh dart:ffi (Android, iOS, desktop); tidak tersedia di web',
      );

  @override
  KontrakTensor get kontrak => throw UnsupportedError(_pesan);

  @override
  Float32List jalankan(Float32List masukan) => throw UnsupportedError(_pesan);

  @override
  void tutup() {}

  static const _pesan = 'TFLite tidak tersedia tanpa dart:ffi';
}

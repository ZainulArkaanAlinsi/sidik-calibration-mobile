import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart'
    show Interpreter, InterpreterOptions, Tensor;

import 'pelari_tflite.dart';

/// [InterpreterMentah] asli di atas `tflite_flutter` 0.12.1 (LiteRT 1.4.0 yang
/// sudah ada di APK). Satu-satunya berkas di app ini yang menyentuh pustaka
/// native untuk mesin angka; dibuat DI DALAM isolate pekerja
/// ([PelariTfliteIsolate]) lewat [buat].
///
/// **Tidak diuji di host** (runtime native tidak ada di mesin test); yang
/// membuktikannya `integration_test/ocr_tflite_hp_test.dart` di perangkat.
///
/// ## Kenapa bukan `Interpreter.run`
///
/// `run` membungkus masukan jadi `List` bersarang `[1][48][320][3]` (46.080
/// `double` berkotak) dan menyalin keluaran ke `List` bersarang. Di sini byte
/// `Float32List` disalin langsung ke tensor (`Tensor.data`), `invoke()`, lalu
/// byte keluaran disalin ke `Float32List` baru. Tensor dialokasikan SEKALI,
/// saat `Interpreter` dibuat (konstruktornya memanggil `allocateTensors`); tidak
/// ada `resizeInputTensor`.
///
/// ## Delegate
///
/// Hanya `InterpreterOptions.threads`. Delegate XNNPACK TIDAK ditambahkan
/// eksplisit: runtime menerapkan XNNPACK bawaan untuk model float32 bila build
/// LiteRT-nya memuatnya, dan menambah delegate kedua tanpa pengukuran di
/// perangkat bisa memperburuk. Aktif atau tidaknya XNNPACK di Android TIDAK
/// terbukti (lihat `docs/ocr-angka-onnx.md`).
class InterpreterMentahTflite implements InterpreterMentah {
  InterpreterMentahTflite._(this._it, this._masuk, this._keluar, this.kontrak);

  /// [PabrikInterpreterMentah] bawaan.
  static InterpreterMentah buat(Uint8List model, int thread) {
    // Opsi sengaja tidak di-`delete()`: struct kecil, sekali per proses, dan
    // paket tidak menjamin urutan hidup opsi terhadap interpreter.
    final opsi = InterpreterOptions()..threads = thread;
    final it = Interpreter.fromBuffer(model, options: opsi);

    try {
      final masuk = it.getInputTensor(0);
      final keluar = it.getOutputTensor(0);

      return InterpreterMentahTflite._(
        it,
        masuk,
        keluar,
        KontrakTensor(
          bentukMasukan: masuk.shape,
          tipeMasukan: masuk.type.name,
          bentukKeluaran: keluar.shape,
          tipeKeluaran: keluar.type.name,
        ),
      );
    } catch (_) {
      it.close();
      rethrow;
    }
  }

  final Interpreter _it;
  final Tensor _masuk;
  final Tensor _keluar;
  bool _ditutup = false;

  @override
  final KontrakTensor kontrak;

  @override
  Float32List jalankan(Float32List masukan) {
    if (_ditutup) throw StateError('interpreter TFLite sudah ditutup');

    _masuk.data = masukan.buffer.asUint8List(
      masukan.offsetInBytes,
      masukan.lengthInBytes,
    );
    _it.invoke();

    // `Tensor.data` = tampilan atas memori native yang dipakai ulang di
    // panggilan berikut: salin dulu. `fromList` memberi buffer baru berpangkal
    // di 0, jadi `asFloat32List` selalu sejajar.
    return Uint8List.fromList(_keluar.data).buffer.asFloat32List();
  }

  @override
  void tutup() {
    if (_ditutup) return;
    _ditutup = true;
    _it.close();
  }
}

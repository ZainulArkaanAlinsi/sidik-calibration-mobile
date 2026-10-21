import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart' show Interpreter;

import 'pembaca_digit_tflite.dart' show InterpreterDigit, PembacaDigitTflite;
import 'segmentasi_karakter.dart' show sisiMnist;

/// [InterpreterDigit] asli di atas `tflite_flutter` (LiteRT on-device).
///
/// Dibuat HANYA lewat `PembacaDigitTflite.siapkan(buatInterpreter: ...)`,
/// sesudah gerbang sakelar, sha256, dan `asal_data` lolos. Tidak diuji di host:
/// runtime native TFLite tidak ada di mesin test; seam-nya diuji dengan
/// interpreter palsu.
class InterpreterTflite implements InterpreterDigit {
  InterpreterTflite(Uint8List model) : _it = Interpreter.fromBuffer(model);

  final Interpreter _it;

  @override
  List<double> jalankan(Float32List masukan784) {
    // Bentuk [1, 28, 28, 1].
    final masukan = [
      [
        for (var y = 0; y < sisiMnist; y++)
          [
            for (var x = 0; x < sisiMnist; x++) [masukan784[y * sisiMnist + x]],
          ],
      ],
    ];
    final keluaran = [
      List<double>.filled(PembacaDigitTflite.kelasDiharapkan.length, 0),
    ];

    _it.run(masukan, keluaran);

    return keluaran.first;
  }

  @override
  void tutup() => _it.close();
}

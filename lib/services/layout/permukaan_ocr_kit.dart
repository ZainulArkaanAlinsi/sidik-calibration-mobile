import 'package:flutter_ocr_kit/flutter_ocr_kit.dart';

import 'detektor_layout_ocrkit.dart';

/// Adaptor tipis ke `OcrKit` (flutter_ocr_kit, dipin ke commit tertentu di
/// pubspec). TIDAK ada logika di sini — urutan init/deteksi/release ada di
/// [deteksiLayoutSinkron] supaya teruji. Berkas ini satu-satunya yang
/// mengimpor paket itu, jadi paketnya bisa diganti tanpa menyentuh alur.
class PermukaanOcrKitAsli implements PermukaanOcrKit {
  const PermukaanOcrKitAsli();

  @override
  void init(String modelPath) => OcrKit.init(modelPath);

  @override
  LayoutMentah detectLayout(String imagePath, {double confThreshold = 0.5}) {
    final hasil = OcrKit.detectLayout(imagePath, confThreshold: confThreshold);
    if (hasil.hasError) throw StateError(hasil.error!);

    return (
      lebar: hasil.imageWidth,
      tinggi: hasil.imageHeight,
      durasiMs: hasil.inferenceTimeMs,
      wilayah: [
        for (final d in hasil.detections)
          (
            kelas: d.className,
            skor: d.score,
            x1: d.x1,
            y1: d.y1,
            x2: d.x2,
            y2: d.y2,
          ),
      ],
    );
  }

  @override
  void releaseLayout() => OcrKit.releaseLayout();
}

import 'detektor_layout_ocrkit.dart';

/// Pengganti [PermukaanOcrKitAsli] untuk platform tanpa `dart:ffi` (web).
/// `flutter_ocr_kit` mengimpor `dart:ffi`, sehingga mengimpornya langsung
/// mematahkan `flutter build web`. Di sini tidak pernah dipanggil:
/// `layoutDidukungPlatformProvider` false di luar Android.
class PermukaanOcrKitAsli implements PermukaanOcrKit {
  const PermukaanOcrKitAsli();

  @override
  void init(String modelPath) =>
      throw UnsupportedError('OcrKit butuh dart:ffi');

  @override
  LayoutMentah detectLayout(String imagePath, {double confThreshold = 0.5}) =>
      throw UnsupportedError('OcrKit butuh dart:ffi');

  @override
  void releaseLayout() {}
}

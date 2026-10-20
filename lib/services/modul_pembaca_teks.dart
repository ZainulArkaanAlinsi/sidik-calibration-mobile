import 'package:flutter/services.dart' show PlatformException;

/// Modul pengenal teks ML Kit UNBUNDLED belum ada di HP.
///
/// Sejak ML Kit text recognition dipasang unbundled (model ikut Google Play
/// Services, bukan APK), HP yang belum pernah mengunduh modul `ocr` menolak
/// membaca dengan `MlKitException` UNAVAILABLE: "Waiting for the text
/// (optional|recognition) module to be downloaded. Please wait." (string di
/// `play-services-mlkit-text-recognition-common` 19.1.0). Unduhannya butuh
/// internet SEKALI; inferensi tetap di HP.
///
/// Ini BUKAN foto jelek dan bukan sel kosong: teknisi diberi tahu dengan
/// pesannya sendiri, isian manual tetap terbuka.
class ModulPembacaTeksBelumSiap implements Exception {
  const ModulPembacaTeksBelumSiap();

  @override
  String toString() => 'ModulPembacaTeksBelumSiap';
}

final _polaBelumTerunduh = RegExp(
  r'module to be downloaded',
  caseSensitive: false,
);

/// [e] galat ML Kit "modul belum terunduh"?
bool galatModulBelumTerunduh(Object e) {
  if (e is! PlatformException) return false;

  return _polaBelumTerunduh.hasMatch('${e.message} ${e.details}');
}

/// Jalankan [kerja]; galat "modul belum terunduh" diterjemahkan jadi
/// [ModulPembacaTeksBelumSiap], galat lain dilempar apa adanya.
Future<T> denganModulPembacaTeks<T>(Future<T> Function() kerja) async {
  try {
    return await kerja();
  } on PlatformException catch (e) {
    if (galatModulBelumTerunduh(e)) throw const ModulPembacaTeksBelumSiap();
    rethrow;
  }
}

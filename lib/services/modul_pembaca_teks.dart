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

/// Modul pemindai QR/barcode ML Kit UNBUNDLED belum ada di HP.
///
/// Manifest meminta `ocr,barcode` sekaligus; dua modul itu turun TERPISAH,
/// jadi teks yang sudah bisa dibaca tidak menjamin QR-nya juga. Pesannya
/// sendiri supaya teknisi tidak mengira QR di kertasnya yang rusak.
class ModulPembacaQrBelumSiap implements Exception {
  const ModulPembacaQrBelumSiap();

  @override
  String toString() => 'ModulPembacaQrBelumSiap';
}

/// HP tanpa Google Play Services (mis. Huawei seri baru) atau versinya terlalu
/// lama untuk modul ML Kit unbundled. Foto ulang tidak menolong; yang
/// menolong memperbarui Play Services — atau isi manual.
class LayananGooglePlayTidakSiap implements Exception {
  const LayananGooglePlayTidakSiap();

  @override
  String toString() => 'LayananGooglePlayTidakSiap';
}

/// Kode status yang dipakai ML Kit/Play Services untuk "belum tersedia".
///
/// Plugin `google_mlkit_*` (0.14/0.15) sekarang SELALU memakai kode generik
/// (`TextRecognizerError`, `BarcodeDetectorError`) dan menaruh
/// `MlKitException` di pesan — kode ini cuma pengaman kalau plugin suatu hari
/// meneruskan kode aslinya. Pencocokan teks di bawah tetap jalur utama.
const _kodeBelumTersedia = {'UNAVAILABLE', '14'};

final _polaBelumTerunduh = RegExp(
  r'module to be downloaded|waiting for the .{0,40}module',
  caseSensitive: false,
);

/// Tanda Play Services tidak ada / tidak bisa dipakai. Nama konstanta
/// `ConnectionResult` + kalimat bawaan GMS.
final _polaTanpaPlayServices = RegExp(
  r'SERVICE_MISSING|SERVICE_INVALID|SERVICE_DISABLED|'
  r'SERVICE_VERSION_UPDATE_REQUIRED|API_UNAVAILABLE|'
  r'google play services (is )?(missing|not available|unavailable|'
  r'out of date|is updating|not installed)|'
  r'is not available on this device',
  caseSensitive: false,
);

String _teks(PlatformException e) => '${e.message} ${e.details}';

/// [e] galat ML Kit "modul belum terunduh"?
bool galatModulBelumTerunduh(Object e) {
  if (e is! PlatformException) return false;

  final teks = _teks(e);
  if (_polaBelumTerunduh.hasMatch(teks)) return true;

  // Kode UNAVAILABLE TANPA tanda Play Services hilang = modul masih turun.
  return _kodeBelumTersedia.contains(e.code) &&
      !_polaTanpaPlayServices.hasMatch(teks);
}

/// [e] galat "Google Play Services tidak ada / terlalu lama"?
bool galatTanpaPlayServices(Object e) {
  if (e is! PlatformException) return false;
  if (galatModulBelumTerunduh(e)) return false;

  return _polaTanpaPlayServices.hasMatch(_teks(e));
}

/// Jalankan [kerja]; galat "modul belum terunduh" diterjemahkan jadi
/// [ModulPembacaTeksBelumSiap], Play Services hilang jadi
/// [LayananGooglePlayTidakSiap], galat lain dilempar apa adanya.
Future<T> denganModulPembacaTeks<T>(Future<T> Function() kerja) =>
    _denganModul(kerja, belumSiap: const ModulPembacaTeksBelumSiap());

/// Sama dengan [denganModulPembacaTeks], untuk pemindai QR/barcode ML Kit.
Future<T> denganModulPembacaQr<T>(Future<T> Function() kerja) =>
    _denganModul(kerja, belumSiap: const ModulPembacaQrBelumSiap());

Future<T> _denganModul<T>(
  Future<T> Function() kerja, {
  required Exception belumSiap,
}) async {
  try {
    return await kerja();
  } on PlatformException catch (e) {
    if (galatModulBelumTerunduh(e)) throw belumSiap;
    if (galatTanpaPlayServices(e)) throw const LayananGooglePlayTidakSiap();
    rethrow;
  }
}

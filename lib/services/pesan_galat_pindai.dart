import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import 'dart:isolate' show RemoteError;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;

import '../core/pelapor_galat.dart';
import '../l10n/app_localizations.dart';
import 'auth_service.dart' show KoneksiException;
import 'modul_pembaca_teks.dart';

/// Golongan galat jalur foto/pindai — yang menentukan KALIMAT untuk teknisi.
///
/// Galat mentah (`PlatformException(camera_access_denied, ...)`,
/// `MlKitException: ...`) tidak pernah ditampilkan: isinya bahasa programmer
/// dan bisa membawa path berkas. Yang mentah hanya ke [catatGalatPindai].
enum GolonganGalatPindai {
  izinKameraDitolak,
  kameraTidakAda,
  kameraSibuk,
  modulTeksDiunduh,
  modulQrDiunduh,
  tanpaPlayServices,
  koneksi,

  /// Memori HP habis waktu decode/olah foto (HP RAM kecil). Foto ulang —
  /// sering cukup karena memori sudah lega lagi.
  memoriHabis,
  umum,
}

/// `OutOfMemoryError` Dart — di isolate sendiri, atau dibawa pulang dari
/// `Isolate.run` (bisa sebagai [RemoteError] kalau tak tersalin utuh).
bool galatMemoriHabis(Object e) =>
    e is OutOfMemoryError ||
    (e is RemoteError && e.toString().contains('Out of Memory'));

/// Kode `PlatformException` image_picker 1.2.x (Android
/// `ImagePickerDelegate`, iOS `FLTImagePickerPlugin`).
const _kodeIzinDitolak = {'camera_access_denied', 'photo_access_denied'};

GolonganGalatPindai golongkanGalatPindai(Object e) {
  if (galatMemoriHabis(e)) return GolonganGalatPindai.memoriHabis;
  if (e is ModulPembacaTeksBelumSiap) {
    return GolonganGalatPindai.modulTeksDiunduh;
  }
  if (e is ModulPembacaQrBelumSiap) return GolonganGalatPindai.modulQrDiunduh;
  if (e is LayananGooglePlayTidakSiap) {
    return GolonganGalatPindai.tanpaPlayServices;
  }
  if (e is KoneksiException || e is SocketException || e is TimeoutException) {
    return GolonganGalatPindai.koneksi;
  }
  if (e is PlatformException) {
    if (_kodeIzinDitolak.contains(e.code)) {
      return GolonganGalatPindai.izinKameraDitolak;
    }
    if (e.code == 'no_available_camera') {
      return GolonganGalatPindai.kameraTidakAda;
    }
    if (e.code == 'already_active') return GolonganGalatPindai.kameraSibuk;
    // ML Kit yang lolos tanpa pembungkus `denganModul*`.
    if (galatModulBelumTerunduh(e)) return GolonganGalatPindai.modulTeksDiunduh;
    if (galatTanpaPlayServices(e)) return GolonganGalatPindai.tanpaPlayServices;
  }

  return GolonganGalatPindai.umum;
}

/// Kalimat aman untuk teknisi. [umum] = kalimat cadangan jalur pemanggil
/// (mis. "Foto tabel gagal diproses…") untuk galat yang tidak dikenali.
String pesanGalatPindai(
  AppLocalizations l10n,
  Object e, {
  required String umum,
}) => switch (golongkanGalatPindai(e)) {
  GolonganGalatPindai.izinKameraDitolak => l10n.lkGalatIzinKamera,
  GolonganGalatPindai.kameraTidakAda => l10n.lkGalatKameraTidakAda,
  GolonganGalatPindai.kameraSibuk => l10n.lkGalatKameraSibuk,
  GolonganGalatPindai.modulTeksDiunduh => l10n.lkModulPembacaTeksDiunduh,
  GolonganGalatPindai.modulQrDiunduh => l10n.lkModulPembacaQrDiunduh,
  GolonganGalatPindai.tanpaPlayServices => l10n.lkGalatTanpaPlayServices,
  GolonganGalatPindai.koneksi => l10n.lkGalatServerBelumTersambung,
  GolonganGalatPindai.memoriHabis => l10n.lkGalatFotoTerlaluBesar,
  GolonganGalatPindai.umum => umum,
};

/// Galat mentah ke log (logcat lewat `flutter logs`/`adb logcat`), BUKAN ke
/// layar. Isi lembar kerja tidak ikut: yang dicatat cuma galatnya.
///
/// Juga dilaporkan sebagai NON-FATAL lewat [pelaporGalat] (Crashlytics di
/// rilis) — hanya jenis galat + jejak tumpukan, tanpa pesannya.
void catatGalatPindai(String tempat, Object e, [StackTrace? st]) {
  debugPrint('Pindai[$tempat]: ${e.runtimeType}: $e');
  if (st != null) debugPrint('$st');
  pelaporGalat.catat(e, st, konteks: 'pindai:$tempat');
}

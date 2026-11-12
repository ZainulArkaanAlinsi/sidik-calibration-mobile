import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'mesin_angka.dart';
import 'muat_mesin.dart';
import 'sesi_inferensi.dart';
import 'sumber_model_ocr.dart';

/// Nama subfolder (di folder file app) tempat model + crop uji dititipkan.
const namaFolderOcrUkur = 'ocr-ukur';

/// Folder pengukuran di perangkat. Android: folder file EKSTERNAL milik app
/// (`/sdcard/Android/data/<paket>/files/ocr-ukur`), yang bisa diisi lewat
/// `adb push` tanpa izin penyimpanan. Platform lain: folder dukungan app.
Future<Directory> folderOcrUkur() async {
  Directory? dasar;
  if (Platform.isAndroid) dasar = await getExternalStorageDirectory();
  dasar ??= await getApplicationSupportDirectory();

  return Directory('${dasar.path}/$namaFolderOcrUkur');
}

/// Sumber model bawaan: aset APK dulu (kosong selama model belum dibundel),
/// lalu [folderOcrUkur].
Future<SumberModelOcr> sumberModelBawaan() async => SumberBerlapisOcr([
  SumberAsetOcr(rootBundle),
  SumberFolderOcr(await folderOcrUkur()),
]);

/// sha256 model yang dipercaya build rilis: `en_PP-OCRv5_mobile_rec_onnx`
/// rev `3fafbc3b`. Model dari folder perangkat (adb push) hanya dimuat bila
/// sha256-nya ada di sini; build debug memuat model apa pun yang lolos meta.
const sha256ModelDipercaya = {
  'b5f833dfc5d0eb71da397b4efa06ebeee9b431b690a47d6af40d77d8eabc557f',
};

/// Muat mesin angka untuk pembaca sel; `null` bila tidak bisa (alasannya
/// dibuang — pembaca jatuh ke ML Kit).
///
/// [izinkanSintetis] = sakelar developer `pakaiMesinAngkaOnnx` menyala. Tanpa
/// itu model yang buktinya SINTETIS ditolak, jadi rilis biasa tidak pernah
/// memakainya. Di rilis model juga harus yang dipatok ([sha256ModelDipercaya]),
/// supaya berkas di folder perangkat tidak bisa menggantinya.
Future<MesinAngka?> muatMesinAngkaBawaan(
  BuatSesiCtc? buatSesi, {
  required bool izinkanSintetis,
}) async {
  // Tanpa runtime tidak ada yang perlu dicari di penyimpanan.
  if (buatSesi == null) return null;

  try {
    final hasil = await muatMesinAngka(
      sumber: await sumberModelBawaan(),
      buatSesi: buatSesi,
      izinkanSintetis: izinkanSintetis,
      sha256Dipercaya: kDebugMode ? null : sha256ModelDipercaya,
    );

    return hasil.mesin;
  } catch (_) {
    return null;
  }
}

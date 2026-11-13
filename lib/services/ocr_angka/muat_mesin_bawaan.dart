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

/// Sumber model bawaan: aset APK dulu (`assets/models/ocr_angka_en.tflite` +
/// `.meta.json`, dibundel), lalu [folderOcrUkur]. Selama aset ada, meta aset yang
/// menang; folder perangkat hanya terpakai bila aset tidak ditemukan.
Future<SumberModelOcr> sumberModelBawaan() async => SumberBerlapisOcr([
  SumberAsetOcr(rootBundle),
  SumberFolderOcr(await folderOcrUkur()),
]);

/// sha256 model yang dipercaya build rilis: `rec_en_f32.tflite` (PP-OCRv5 en
/// rev `3fafbc3b`, dikonversi `onnx2tf` dari ONNX asli, 7.829.508 bita) =
/// `assets/models/ocr_angka_en.tflite`. Model dari folder perangkat (adb push)
/// hanya dimuat bila sha256-nya ada di sini; build debug memuat model apa pun
/// yang lolos meta. Dijaga `test/ocr_angka_tflite_aset_test.dart`: aset, meta,
/// dan pin ini tidak boleh berbeda.
const sha256ModelDipercaya = {
  'e1121d540ae96a69f2891a6d8811ecb89cb5e55d8eafb69efce2ee1fae4043b7',
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
  bool Function()? menyerah,
}) async {
  // Tanpa runtime tidak ada yang perlu dicari di penyimpanan; runtime yang sudah
  // menyerah (gagal dimuat berulang) juga tidak: sumber model pun tidak dibuka.
  if (buatSesi == null || (menyerah?.call() ?? false)) return null;

  try {
    final hasil = await muatMesinAngka(
      sumber: await sumberModelBawaan(),
      buatSesi: buatSesi,
      izinkanSintetis: izinkanSintetis,
      sha256Dipercaya: kDebugMode ? null : sha256ModelDipercaya,
      menyerah: menyerah,
    );

    return hasil.mesin;
  } catch (_) {
    return null;
  }
}

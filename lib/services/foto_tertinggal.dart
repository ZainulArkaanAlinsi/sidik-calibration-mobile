import 'dart:io';

import 'photo_source.dart';

/// Ambil foto — tapi PULIHKAN dulu foto yang tertinggal kalau ada.
///
/// ## Kenapa ini ada
///
/// Di HP RAM kecil Android sering mematikan aplikasi selama app kamera
/// terbuka. Teknisi sudah menjepret, kembali ke aplikasi yang dinyalakan
/// ulang, dan fotonya HILANG tanpa pesan apa pun. image_picker menyimpan
/// hasil itu dan memulangkannya SEKALI lewat `retrieveLostData()`.
///
/// Fotonya tidak dipakai diam-diam: aplikasi baru saja dinyalakan ulang, jadi
/// tidak ada jaminan foto itu untuk lembar yang sekarang terbuka. Teknisi
/// yang memutuskan lewat [pakaiTertinggal]; ditolak → berkasnya dihapus
/// (isinya lembar kerja pelanggan) dan kamera dibuka seperti biasa.
Future<File?> ambilFotoAtauPulihkan(
  SumberFoto sumber, {
  required Future<bool> Function(File foto) pakaiTertinggal,
  int? maxWidth,
  int? maxHeight,
  int? imageQuality,
}) async {
  File? sisa;
  try {
    sisa = await sumber.ambilFotoTertinggal();
  } catch (_) {
    sisa = null; // Pemulihan tidak boleh menghalangi kamera.
  }

  if (sisa != null && sisa.existsSync()) {
    if (await pakaiTertinggal(sisa)) return sisa;

    try {
      await sisa.delete();
    } catch (_) {
      // Sampah cache pemilih; tidak menghalangi foto baru.
    }
  }

  return sumber.ambil(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
  );
}

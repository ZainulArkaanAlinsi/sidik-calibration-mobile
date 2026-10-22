import 'package:flutter/widgets.dart';

/// Lebar piksel FISIK untuk `cacheWidth`/`ResizeImage` dari lebar tampil
/// logis. Gambar yang didekode penuh (mis. foto 4200 px ≈ 70 MB RGBA) padahal
/// cuma tampil selebar layar adalah penyebab utama HP RAM kecil ditutup
/// sistem. `null` = lebar tak terbatas/tak dikenal → dekode apa adanya.
///
/// Hanya aman untuk `BoxFit.contain`/`fitWidth` (rasio dijaga dan tampilan
/// tidak pernah lebih lebar dari [lebarLogis]). Untuk `cover` lebar saja tidak
/// cukup — sisi pendek foto lanskap bisa jadi buram.
int? lebarDekode(BuildContext context, double lebarLogis) {
  if (!lebarLogis.isFinite || lebarLogis <= 0) return null;
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  return (lebarLogis * dpr).ceil();
}

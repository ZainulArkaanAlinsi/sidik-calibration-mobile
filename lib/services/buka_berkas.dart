import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Buka berkas lokal (PDF/Excel) pakai aplikasi bawaan sistem.
///
/// Dua jalur, dan ini bukan soal selera: `open_filex` cuma mendeklarasikan
/// implementasi **android & ios** di pubspec plugin-nya — nggak ada `windows`
/// maupun `macos`. Di desktop dia nggak "gagal dengan pesan", tapi nggak ada
/// yang nanggepin panggilannya sama sekali, jadi tombol PDF/Excel/QR kelihatan
/// mati total: dipencet, nggak kejadian apa-apa, nggak ada error.
///
/// Windows & macOS itu target rilis proyek ini, bukan bonus — jadi di desktop
/// dipakai `url_launcher` (yang memang punya implementasi desktop) lewat URI
/// `file://`, yang nyerahin berkasnya ke aplikasi default sistem.
///
/// Balikin `null` kalau kebuka. Kalau nggak, balikin alasannya — bukan `bool`,
/// karena "nggak ada aplikasi pembaca PDF" beda penanganan dari "berkasnya
/// nggak ada", dan admin butuh tau bedanya.
Future<String?> bukaBerkas(String path) async {
  if (!await File(path).exists()) {
    return 'Berkasnya nggak ketemu di perangkat ini.';
  }

  // Android/iOS: open_filex, karena dia yang ngerti intent & UTI.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    final hasil = await OpenFilex.open(path);
    if (hasil.type == ResultType.done) return null;

    return switch (hasil.type) {
      ResultType.noAppToOpen => 'Nggak ada aplikasi yang bisa buka berkas ini.',
      ResultType.permissionDenied => 'Izin buka berkas ditolak perangkat.',
      ResultType.fileNotFound => 'Berkasnya nggak ketemu di perangkat ini.',
      _ => 'Berkasnya nggak bisa dibuka.',
    };
  }

  // Desktop: serahin ke aplikasi default lewat file:// URI.
  try {
    final ok = await launchUrl(Uri.file(path));
    return ok ? null : 'Nggak ada aplikasi yang bisa buka berkas ini.';
  } catch (_) {
    return 'Berkasnya nggak bisa dibuka di perangkat ini.';
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Font Studio — DIRUJUK dari paket `sidik_calibration`, tidak disalin.
///
/// ## Dua nama untuk berkas yang sama
///
/// Pubspec paket `sidik_calibration` mendeklarasikan `Inter` dan `IBMPlexMono`.
/// Waktu paket itu dipakai sebagai DEPENDENSI, Flutter membundel font-nya di
/// bawah nama berawalan paket: `packages/sidik_calibration/Inter`
/// (flutter_tools `asset.dart`, `_parsePackageFonts`). Nama polos `Inter`
/// cuma berlaku di aplikasi yang paketnya sendiri adalah akar — app lapangan.
///
/// Akibatnya:
///  - tema Studio memakai [inter] & [mono] (berawalan) — dijamin ada karena
///    tercatat di `FontManifest.json` hasil build, tanpa langkah runtime;
///  - widget milik paket bersama (layar M2, `SidikTheme.gayaAngka`) menulis
///    nama POLOS `IBMPlexMono`/`Inter`. Tanpa [daftarkanAliasFont] nama itu
///    tidak dikenal di Studio dan angka acuan jatuh ke `monospace` sistem —
///    kolom tetap rata, tapi bukan font sertifikat.
abstract final class FontStudio {
  static const paket = 'sidik_calibration';

  /// Teks antarmuka.
  static const inter = 'packages/$paket/Inter';

  /// Angka: nilai acuan, nomor versi, sha.
  static const mono = 'packages/$paket/IBMPlexMono';

  /// Berkas yang dideklarasikan pubspec paket (`assets/fonts/<Keluarga>-<Ragam>.ttf`).
  static const _ragam = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  static const _keluarga = ['Inter', 'IBMPlexMono'];

  /// Kunci aset bundel untuk satu berkas font paket.
  static String kunciAset(String keluarga, String ragam) =>
      'packages/$paket/assets/fonts/$keluarga-$ragam.ttf';
}

/// Daftarkan nama polos `Inter` & `IBMPlexMono` dari berkas yang SAMA di bundel
/// paket, supaya widget bersama yang menulis nama polos tetap memakai font
/// yang benar. Mengembalikan jumlah berkas yang termuat.
///
/// Gagal memuat TIDAK menghentikan aplikasi: yang hilang cuma bentuk huruf
/// (jatuh ke font sistem), bukan data. Kegagalannya dicatat, tidak ditelan
/// diam-diam.
Future<int> daftarkanAliasFont({AssetBundle? bundel}) async {
  final sumber = bundel ?? rootBundle;
  var termuat = 0;
  for (final keluarga in FontStudio._keluarga) {
    final pemuat = FontLoader(keluarga);
    for (final ragam in FontStudio._ragam) {
      final kunci = FontStudio.kunciAset(keluarga, ragam);
      try {
        // Dimuat dulu di sini supaya aset yang hilang ketahuan per berkas,
        // bukan sebagai kegagalan `load()` tanpa nama.
        final data = await sumber.load(kunci);
        pemuat.addFont(Future.value(data));
        termuat++;
      } catch (e) {
        debugPrint('Font $kunci tidak termuat: $e');
      }
    }
    await pemuat.load();
  }
  return termuat;
}

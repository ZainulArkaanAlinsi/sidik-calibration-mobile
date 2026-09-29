import 'package:flutter/material.dart';

import 'sidik_theme.dart';

/// Pintu masuk tema aplikasi — sekarang "Meja Kerja Lab".
///
/// Kelas ini dipertahankan (bukan dihapus) karena `lib/app.dart`,
/// `test/screenshot_test.dart`, dan `test/tombol_lingkar_test.dart` memanggil
/// `AppTheme.light` / `AppTheme.dark`. Isinya sekarang satu sumber saja:
/// [SidikTheme], yang membangun ThemeData dari `SidikMaterial`.
///
/// Kenapa tidak dua tema yang hidup berdampingan: dua sumber gaya berarti
/// layar yang sama bisa tampil beda tergantung jalur mana yang membangunnya,
/// dan yang menemukannya bukan test — tapi orang lab yang melihat tombol
/// biru di satu layar dan hitam di layar sebelahnya.
///
/// Empat material, satu tugas masing-masing (detail di `sidik_material.dart`):
/// KERTAS untuk membaca & mengisi, LOGAM untuk menekan & membingkai, KACA LCD
/// untuk angka hidup, KACA BENING cuma untuk benda mengambang & sementara.
///
/// Yang SENGAJA dipertahankan dari tema lama "Titanium":
/// - transisi halaman `TransisiHalus` (iOS/macOS tetap bawaan platform),
/// - label tombol HURUF BESAR — sentence case menyusul sebagai commit
///   terpisah bersama pembaruan test (lihat `SidikTheme._labelTombol`),
/// - skala huruf ×0.9 di desktop dan `visualDensity` adaptif.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => SidikTheme.terang;

  static ThemeData get dark => SidikTheme.gelap;
}

import 'package:flutter/material.dart';

/// Skala tipografi Titanium — pakai **Inter**, sesuai `DESIGN.md`.
///
/// Font-nya dibundel di APK (lihat `pubspec.yaml`), bukan diunduh runtime
/// lewat `google_fonts` — app ini dipakai teknisi di lapangan yang sinyalnya
/// nggak nentu, tipografi nggak boleh gagal muncul.
///
/// Prinsip dari DESIGN.md: heading pakai letter-spacing rapat & bobot berat
/// (biar berwibawa), body longgar (biar enak dibaca lama), label huruf besar
/// + spasi lebar (biar metadata kebedain dari isi).
class AppTypography {
  const AppTypography._();

  static const String family = 'Inter';

  static TextTheme textTheme(Color onSurface, Color muted) {
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: family,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.64, // -0.02em
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: family,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 36 / 28,
        letterSpacing: -0.28,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: family,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: family,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: muted,
      ),
      bodyLarge: TextStyle(
        fontFamily: family,
        fontSize: 18,
        height: 28 / 18,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 24 / 16,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 20 / 14,
        color: muted,
      ),
      // Label metadata: HURUF BESAR, spasi lebar — dipakai buat label field
      // di form login/register, persis kayak desain.
      labelLarge: TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.6, // 0.05em
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontFamily: family,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: muted,
      ),
    );
  }

  /// Angka hasil ukur — lebar digit tetap (tabular) biar kolom angka di
  /// worksheet kalibrasi lurus, nggak goyang tiap digit berubah.
  static const TextStyle measurement = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

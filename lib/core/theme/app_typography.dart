import 'package:flutter/material.dart';

/// Skala tipografi ASMO.
///
/// Sengaja pakai font bawaan sistem (Roboto di Android), bukan `google_fonts`:
/// nambah dependensi + font harus diunduh/dibundel, sementara app ini dipakai
/// teknisi di lapangan yang sinyalnya nggak selalu bagus. Font sistem selalu
/// ada dan render-nya instan.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color onSurface, Color muted) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: muted,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: onSurface),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: onSurface),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: muted,
        letterSpacing: 0.4,
      ),
    );
  }

  /// Buat angka hasil ukur — pakai lebar digit tetap (tabular) supaya kolom
  /// angka di worksheet kalibrasi lurus, nggak goyang tiap digit berubah.
  static const TextStyle measurement = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

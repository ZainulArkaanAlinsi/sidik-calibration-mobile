import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema app — satu-satunya sumber gaya visual.
///
/// Widget nggak boleh nentuin warna/ukuran sendiri; ambil dari
/// `Theme.of(context)` biar sekali ganti di sini, seluruh app ikut.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    Brightness.light,
    const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCFE7EA),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.navy,
      onSurfaceVariant: Color(0xFF5A6E75),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceLight,
      surfaceContainerHighest: Color(0xFFE8EEF0),
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.outline,
      outlineVariant: Color(0xFFD6DFE2),
    ),
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    const ColorScheme.dark(
      primary: Color(0xFF6FD0DE),
      onPrimary: Color(0xFF00363F),
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: Color(0xFFB9EDF5),
      secondary: Color(0xFF7FCBD9),
      onSecondary: Color(0xFF00363F),
      surface: AppColors.surfaceDark,
      onSurface: Color(0xFFE3EDEF),
      onSurfaceVariant: Color(0xFFA8BDC3),
      surfaceContainerLowest: Color(0xFF0A1F26),
      surfaceContainerLow: Color(0xFF13333D),
      surfaceContainerHighest: Color(0xFF1D4551),
      error: Color(0xFFE98C84),
      onError: Color(0xFF5C1109),
      outline: Color(0xFF7A9198),
      outlineVariant: Color(0xFF34505A),
    ),
  );

  static ThemeData _build(Brightness brightness, ColorScheme scheme) {
    final text = AppTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      textTheme: text,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 48dp — tinggi minimum yang nyaman dipencet, penting karena teknisi
          // sering pakai app ini sambil pegang alat / pakai sarung tangan.
          minimumSize: const Size.fromHeight(48),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        labelStyle: text.bodyMedium,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        surfaceTintColor: Colors.transparent,
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

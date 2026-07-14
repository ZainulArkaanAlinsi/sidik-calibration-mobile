import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema "Titanium" — satu-satunya sumber gaya visual.
///
/// Prinsip dari `DESIGN.md`: kedalaman dibentuk lewat **garis tipis**, bukan
/// bayangan tebal. Card = border 1px, tanpa elevation. Tombol utama = solid
/// navy, tombol sekunder = border tipis. Nggak ada gradient, nggak ada
/// warna-warni — teal dipakai irit cuma buat sinyal fungsional.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    Brightness.light,
    const ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.surfaceMuted,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.teal,
      onSecondary: AppColors.white,
      secondaryContainer: Color(0xFFD6F2EC),
      onSecondaryContainer: Color(0xFF00382F),
      surface: AppColors.white,
      onSurface: Color(0xFF191C1D),
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.surfaceLight,
      surfaceContainer: Color(0xFFEDEEEF),
      surfaceContainerHighest: Color(0xFFE1E3E4),
      error: AppColors.danger,
      onError: AppColors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
      outline: AppColors.outline,
      outlineVariant: AppColors.titanium,
    ),
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    const ColorScheme.dark(
      // Di tema gelap, tombol utama jadi putih di atas navy — persis
      // tombol "SIGN IN" di screenshot desain.
      primary: AppColors.white,
      onPrimary: AppColors.navyDeep,
      primaryContainer: AppColors.darkElevated,
      onPrimaryContainer: AppColors.white,
      secondary: AppColors.tealBright,
      onSecondary: Color(0xFF00382F),
      secondaryContainer: Color(0xFF005046),
      onSecondaryContainer: Color(0xFF6DF5E1),
      surface: AppColors.darkBase,
      onSurface: Color(0xFFF0F1F2),
      onSurfaceVariant: AppColors.darkTextMuted,
      surfaceContainerLowest: Color(0xFF081A21),
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkElevated,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      outline: Color(0xFF7A9198),
      outlineVariant: AppColors.darkOutline,
    ),
  );

  static ThemeData _build(Brightness brightness, ColorScheme scheme) {
    final text = AppTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: isLight
          ? AppColors.surfaceLight
          : AppColors.darkBase,
      textTheme: text,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),

      // Kedalaman = garis tipis, bukan bayangan (DESIGN.md, Elevation).
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52dp — desain minta tombol tebal, dan teknisi sering mencet sambil
          // pegang alat / pakai sarung tangan.
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          textStyle: text.labelLarge?.copyWith(letterSpacing: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge?.copyWith(letterSpacing: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight ? AppColors.teal : AppColors.tealBright,
          textStyle: text.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.white : AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _border(scheme.outlineVariant),
        enabledBorder: _border(scheme.outlineVariant),
        // Fokus = border nebel jadi navy (light) / putih (dark), bukan ganti
        // warna — sesuai DESIGN.md.
        focusedBorder: _border(scheme.primary, width: 2),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, width: 2),
        disabledBorder: _border(scheme.outlineVariant.withValues(alpha: 0.5)),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        surfaceTintColor: Colors.transparent,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isLight ? AppColors.white : AppColors.darkSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: _border(scheme.outlineVariant),
          enabledBorder: _border(scheme.outlineVariant),
          focusedBorder: _border(scheme.primary, width: 2),
        ),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

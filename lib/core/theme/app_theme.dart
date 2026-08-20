import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema "Titanium" — satu-satunya sumber gaya visual.
///
/// Arah visual aplikasi: panel instrumen yang modern, berlapis liquid glass,
/// dengan aksen retro yang hangat. Kontras dan warna status tetap dijaga agar
/// nyaman dipakai saat kerja di lab, bukan sekadar dekoratif.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    Brightness.light,
    const ColorScheme.light(
      // Cobalt satu-satunya warna interaktif. Semua tombol utama, tautan, dan
      // penanda aktif pakai ini — jadi teknisi nggak perlu nebak mana yang
      // bisa dipencet.
      primary: AppColors.cobalt,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.cobaltSoft,
      onPrimaryContainer: AppColors.cobaltDeep,
      // Mint aslinya jadi bidang (chip, badge) dengan teks hitam di atasnya;
      // versi gelapnya yang dipakai kalau mint harus jadi huruf.
      secondary: AppColors.mintDeep,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.mint,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.ivory,
      surfaceContainer: AppColors.ivoryDim,
      surfaceContainerHighest: AppColors.hairline,
      error: AppColors.crimson,
      onError: AppColors.white,
      errorContainer: AppColors.crimsonSoft,
      onErrorContainer: AppColors.crimsonDeep,
      outline: AppColors.outline,
      outlineVariant: AppColors.hairline,
    ),
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    const ColorScheme.dark(
      // Cobalt penuh terlalu gelap buat jadi bidang di atas Jet Black; versi
      // terangnya yang dipakai, tetap rona yang sama.
      primary: AppColors.cobaltLight,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.cobaltDeep,
      onPrimaryContainer: AppColors.cobaltSoft,
      secondary: AppColors.mint,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.mintInk,
      onSecondaryContainer: AppColors.mint,
      surface: AppColors.inkSurface,
      onSurface: AppColors.ivory,
      onSurfaceVariant: AppColors.inkTextMuted,
      surfaceContainerLowest: AppColors.inkDeep,
      surfaceContainerLow: AppColors.inkSurface,
      surfaceContainer: AppColors.inkSurface,
      surfaceContainerHighest: AppColors.inkElevated,
      error: AppColors.crimsonLight,
      onError: AppColors.ink,
      errorContainer: AppColors.crimsonDeep,
      onErrorContainer: AppColors.crimsonSoft,
      outline: Color(0xFF8A8A85),
      outlineVariant: AppColors.inkOutline,
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
      // Ground rata satu warna. Ivory sedikit lebih tua dari putih, jadi kartu
      // putih di atasnya tetap kebaca timbul tanpa perlu latar yang melandai —
      // dan aksen cobalt/mint di atasnya kebaca bersih, nggak ketarik rona
      // latar.
      scaffoldBackgroundColor: isLight ? AppColors.ivory : AppColors.inkDeep,
      textTheme: text,
      // Perpindahan halaman diseragamkan lewat tema, bukan per `Navigator.push`
      // — ada 60-an `MaterialPageRoute` di app ini dan nyetel satu-satu itu
      // cara paling pasti buat ninggalin sebagian. iOS & macOS dibiarkan
      // bawaan supaya gestur geser-balik dari tepi layar nggak ilang.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransisiHalus(),
          TargetPlatform.fuchsia: TransisiHalus(),
          TargetPlatform.linux: TransisiHalus(),
          TargetPlatform.windows: TransisiHalus(),
        },
      ),

      appBarTheme: AppBarTheme(
        // Nyatu sama ground, tanpa garis pemisah — biar layar kebaca sebagai
        // satu bidang utuh yang ditempeli kartu, bukan tumpukan kotak.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarHeight: 68,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),

      // Arah desain berubah: dulu kedalaman digambar pakai garis rambut
      // (DESIGN.md, Elevation). Sekarang pakai bayangan lembut — acuan visual
      // barunya 3D lembut + liquid glass, dan garis tipis bikin semua layar
      // kebaca rata.
      //
      // Bayangannya sengaja lebar & tipis, bukan pekat & sempit: yang pertama
      // kebaca empuk, yang kedua kebaca kayak kartu ketebalan.
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: AppColors.ink.withValues(alpha: isLight ? 0.14 : 0.6),
        surfaceTintColor: Colors.transparent,
        color: isLight ? AppColors.white : AppColors.inkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isLight ? AppColors.hairline : AppColors.inkOutline,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52dp — desain minta tombol tebal, dan teknisi sering mencet sambil
          // pegang alat / pakai sarung tangan.
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          textStyle: text.labelLarge?.copyWith(letterSpacing: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          backgroundColor: isLight ? AppColors.white : AppColors.inkSurface,
          textStyle: text.labelLarge?.copyWith(letterSpacing: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight ? AppColors.cobalt : AppColors.cobaltLight,
          textStyle: text.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.white : AppColors.inkElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _border(scheme.outlineVariant),
        enabledBorder: _border(scheme.outlineVariant),
        // Fokus = border nebel jadi cobalt, satu-satunya warna interaktif.
        // Ketebalannya yang naik, bukan ronanya yang loncat.
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
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        surfaceTintColor: Colors.transparent,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isLight ? AppColors.white : AppColors.inkElevated,
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

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.ivoryDim : AppColors.inkElevated,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.72)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: text.labelMedium,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

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

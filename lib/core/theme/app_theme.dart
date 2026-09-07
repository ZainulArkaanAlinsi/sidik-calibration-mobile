import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'app_colors.dart';
import 'tombol_bergaris.dart';
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

  /// Platform meja: jendela dilihat dari jarak ~60 cm pakai tetikus, bukan
  /// digenggam dan dicolok jari. Ukuran kontrol yang pas di HP kebaca
  /// kegedean di situ — bukan selera, tapi jarak pandang dan alat tunjuk yang
  /// beda.
  ///
  /// Dibaca dari `defaultTargetPlatform`, bukan dari lebar jendela: yang
  /// nentuin ukuran kontrol itu ALAT TUNJUKNYA. HP yang dicolok ke layar
  /// gede tetap butuh sasaran sentuh 48 dp; jendela laptop yang dikecilin
  /// tetap ditunjuk pakai kursor yang presisinya satu piksel.
  ///
  /// Di `flutter test` nilainya `android`, jadi semua test & golden yang ada
  /// tetap ngerender ukuran HP — nggak ada baseline yang bergeser gara-gara
  /// perubahan ini.
  static bool get _meja => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  static ThemeData _build(Brightness brightness, ColorScheme scheme) {
    // Skala hurufnya diturunkan 10% di meja.
    //
    // Ukuran di `AppTypography` dipilih buat HP: layar sejengkal, dilihat dari
    // ~30 cm, sering sambil jalan di lab. Angka yang sama di monitor yang
    // dilihat dari ~60 cm kebaca kegedean — judul halaman jadi sebesar
    // spanduk dan angka di kartu ringkasan makan setengah kartunya.
    //
    // 10%, bukan lebih: di bawah itu teksnya mulai kekecilan buat dibaca
    // sambil berdiri di depan meja kalibrasi, dan layar ini juga dipakai
    // begitu — bukan cuma sambil duduk.
    //
    // `fontSizeFactor` dipakai supaya SELURUH skalanya turun sebanding.
    // Menurunkan sebagiannya saja merusak jenjang ukuran antar-gaya, dan
    // jenjang itu yang bikin orang tahu mana judul mana keterangan.
    final skala = AppTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final text = _meja ? skala.apply(fontSizeFactor: 0.9) : skala;
    final isLight = brightness == Brightness.light;

    return ThemeData(
      // Satu saklar yang memadatkan SEMUA kontrol Material sekaligus —
      // ListTile, checkbox, radio, tombol, chip. Di platform meja dia jadi
      // `compact`, di HP tetap `standard`. Ini yang bikin layar desktop
      // berhenti kebaca sebagai tampilan HP yang dibesarkan, tanpa perlu
      // nyetel tinggi tiap widget satu-satu.
      visualDensity: VisualDensity.adaptivePlatformDensity,
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
        toolbarHeight: _meja ? 52 : 68,
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

      // Tombol aksi bergaya btn-12: pil hitam bertepi tebal, batang putih
      // meluncur masuk waktu disentuh. Mekaniknya di `TombolBergaris` —
      // termasuk alasan kenapa label SELALU ditulis putih di dua-duanya.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52 dp di HP — desain minta tombol tebal, dan teknisi sering mencet
          // sambil pegang alat / pakai sarung tangan. Di meja nggak ada jari
          // yang perlu diakomodasi, dan 52 dp di situ kebaca kayak spanduk.
          minimumSize: Size.fromHeight(_meja ? 40 : 52),
          // Dibalik di tema gelap. Pil hitam di atas ground yang juga nyaris
          // hitam kebaca sama persis kayak tombol hantu di sebelahnya —
          // hierarki "mana aksi utama" ilang. Yang dijaga bukan warnanya,
          // tapi kontrasnya: aksi utama SELALU kebalikan dari latar.
          backgroundColor: isLight ? AppColors.ink : AppColors.white,
          foregroundColor: AppColors.white,
          elevation: 0,
          // 3rem di CSS acuannya. Pil selebar layar nggak butuh sebanyak itu,
          // tapi tombol yang ngikut isinya (mis. di dialog) butuh biar nggak
          // kebaca sempit.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          // Tepinya sewarna dasar waktu diam, jadi nggak kelihatan — dan baru
          // muncul waktu tombolnya kebalik ketiban batang. Tanpa ini, pil
          // putih hasil tekanan lenyap di atas kertas krem (tema terang) dan
          // pil hitamnya lenyap di ground gelap.
          side: BorderSide(
            color: isLight ? AppColors.ink : AppColors.white,
            width: 2,
          ),
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          shape: const StadiumBorder(),
        ).copyWith(
          // Percikan ripple dimatikan: dia dilukis DI ATAS batang dan bikin
          // noda kelabu yang ngotorin polanya. Umpan balik tekanannya udah
          // dikerjain batang itu sendiri — jauh lebih kebaca daripada ripple.
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundBuilder: TombolBergaris.latar(
            isLight ? AppColors.white : AppColors.ink,
          ),
          foregroundBuilder: TombolBergaris.labelBerbalik,
        ),
      ),

      // Kembaran versi hantu: dasarnya tembus pandang, batangnya `onSurface`.
      // Ini yang bikin hierarki aksi utama vs pendamping nggak ilang — kalau
      // dua-duanya pil hitam pekat, nggak ada lagi yang nunjukin mana "Simpan"
      // dan mana "Batal".
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(_meja ? 40 : 52),
          foregroundColor: AppColors.white,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: scheme.onSurface, width: 2),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          shape: const StadiumBorder(),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundBuilder: TombolBergaris.latar(scheme.onSurface),
          foregroundBuilder: TombolBergaris.labelBerbalik,
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

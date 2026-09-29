import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'sidik_material.dart';
import 'tombol_lingkar.dart';

/// Tema **"Meja Kerja Lab"** — pengganti `AppTheme`.
///
/// Kenapa file ini penting: hampir semua layar di `lib/screens/` memakai widget
/// Material bawaan (`Card`, `FilledButton`, `TextFormField`, `ListTile`).
/// Dengan menema komponen-komponen itu di sini, **seluruh app berubah tampilan
/// tanpa satu pun layar disentuh**. Itu yang bikin perubahan ini aman: logika,
/// provider, service, dan test alur tetap utuh.
///
/// Cara pasang — satu perubahan di `lib/app.dart`:
///
/// ```dart
/// // sebelum
/// theme: AppTheme.light,
/// darkTheme: AppTheme.dark,
///
/// // sesudah
/// theme: SidikTheme.terang,
/// darkTheme: SidikTheme.gelap,
/// ```
///
/// Tidak ada file lain yang wajib diubah.
class SidikTheme {
  const SidikTheme._();

  /// Keluarga huruf bawaan.
  ///
  /// Dipatok ke **Inter** karena itu yang SUDAH dibundel di `pubspec.yaml`,
  /// jadi tema ini langsung jalan tanpa menambah aset. Desainnya sendiri minta
  /// IBM Plex Sans; cara menukarnya ada di `PASANG-TEMA-SIDIK.md` — satu baris
  /// di sini plus dua berkas font.
  static const String keluarga = 'Inter';

  /// Huruf angka ukur, nomor sertifikat, dan serial.
  ///
  /// Selama Plex Mono belum dibundel, dia jatuh ke monospace bawaan sistem.
  /// `fontFeatures` tabular tetap dipasang di [gayaAngka] supaya kolom angka
  /// di lembar kerja tetap lurus apa pun fontnya.
  static const String keluargaMono = 'IBMPlexMono';

  static ThemeData get terang => _bangun(SidikMaterial.terangDefault);
  static ThemeData get gelap => _bangun(SidikMaterial.gelapDefault);

  /// Platform meja: jendela dilihat dari ~60 cm pakai tetikus, bukan digenggam.
  ///
  /// Dibaca dari `defaultTargetPlatform`, BUKAN dari lebar jendela — yang
  /// menentukan ukuran kontrol itu alat tunjuknya. Aturan ini disalin apa
  /// adanya dari `AppTheme` lama supaya golden test yang ada tidak bergeser.
  static bool get _meja => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  /// Angka hasil ukur: lebar digit tetap, supaya kolom di worksheet lurus dan
  /// tidak goyang tiap digit berubah.
  static TextStyle gayaAngka({
    double ukuran = 15,
    FontWeight berat = FontWeight.w600,
    Color? warna,
  }) => TextStyle(
    fontFamily: keluargaMono,
    fontFamilyFallback: const ['monospace'],
    fontSize: ukuran,
    fontWeight: berat,
    color: warna,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static ThemeData _bangun(SidikMaterial m) {
    final terang = m.terang;
    final brightness = terang ? Brightness.light : Brightness.dark;

    final skema = ColorScheme(
      brightness: brightness,
      primary: m.biru,
      onPrimary: terang ? Colors.white : const Color(0xFFEFF3FF),
      primaryContainer: m.biruTipis,
      onPrimaryContainer: m.biruTinta,
      secondary: m.lulus,
      onSecondary: terang ? Colors.white : const Color(0xFF0F1114),
      secondaryContainer: m.lulusTipis,
      onSecondaryContainer: m.lulus,
      error: m.gagal,
      onError: terang ? Colors.white : const Color(0xFF24070D),
      errorContainer: m.gagalTipis,
      onErrorContainer: m.gagal,
      surface: m.kertas,
      onSurface: m.tinta,
      onSurfaceVariant: m.tinta2,
      surfaceContainerLowest: m.kertas,
      surfaceContainerLow: m.kertas,
      surfaceContainer: m.kertas2,
      surfaceContainerHigh: m.kertas2,
      surfaceContainerHighest: m.meja2,
      outline: m.kertasTepi,
      outlineVariant: m.garis,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: m.kaca,
      onInverseSurface: m.lcdTeks,
      inversePrimary: m.biruTinta,
    );

    final teks = _teks(m).apply(fontFamily: keluarga);
    final teksSkala = _meja ? teks.apply(fontSizeFactor: 0.9) : teks;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: skema,
      fontFamily: keluarga,
      textTheme: teksSkala,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Latar layar = permukaan meja.
      scaffoldBackgroundColor: m.meja,
      canvasColor: m.meja,
      dividerColor: m.garis,

      extensions: <ThemeExtension<dynamic>>[m],

      // Dipertahankan dari AppTheme lama apa adanya: transisi halaman bukan
      // bagian dari ganti tampilan, dan iOS/macOS sengaja tetap pakai bawaan
      // platform (gestur geser-balik).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransisiHalus(),
          TargetPlatform.fuchsia: TransisiHalus(),
          TargetPlatform.linux: TransisiHalus(),
          TargetPlatform.windows: TransisiHalus(),
        },
      ),

      // ── App bar: panel logam yang megang layar ──────────────────────
      // Bedanya dari versi lama: app bar sekarang PUNYA permukaan sendiri
      // (logam), bukan menyatu dengan ground. Itu yang bikin isi layar kebaca
      // sebagai kertas yang diletakkan DI DALAM alat, bukan kotak melayang.
      appBarTheme: AppBarTheme(
        backgroundColor: m.logam,
        surfaceTintColor: Colors.transparent,
        foregroundColor: m.etsa,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        centerTitle: false,
        toolbarHeight: _meja ? 54 : 62,
        titleTextStyle: teksSkala.titleLarge?.copyWith(
          color: m.etsa,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: m.etsa, size: 22),
        shape: Border(bottom: BorderSide(color: m.logamTepi)),
      ),

      // ── Kartu = lembar kertas ────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: m.kertas,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: terang ? 0.16 : 0.55),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SidikMaterial.sudutKertas),
          side: BorderSide(color: m.kertasTepi),
        ),
      ),

      // ── Tombol utama: anodisasi biru ─────────────────────────────────
      // `FilledButton` dipakai di banyak layar sebagai aksi utama. Di sini dia
      // dapat warna & bentuknya; efek "tertekan"-nya ada di SidikTombol untuk
      // layar yang sudah dimigrasi.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(_meja ? 42 : 48),
          backgroundColor: m.biru,
          foregroundColor: Colors.white,
          disabledBackgroundColor: m.kertas2,
          disabledForegroundColor: m.tinta2.withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SidikMaterial.sudutLogam),
            side: BorderSide(color: terang ? const Color(0xFF12275C) : m.logamTepi),
          ),
          textStyle: teksSkala.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ).copyWith(foregroundBuilder: _labelTombol),
      ),

      // ── Tombol sekunder: logam polos ─────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(_meja ? 42 : 48),
          foregroundColor: m.etsa,
          backgroundColor: m.logam,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: m.logamTepi),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SidikMaterial.sudutLogam),
          ),
          textStyle: teksSkala.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ).copyWith(foregroundBuilder: _labelTombol),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: m.biruTinta,
          textStyle: teksSkala.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: m.etsa,
          minimumSize: const Size(48, 48),
        ),
      ),

      // ── Isian: kolom di formulir cetak ───────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: m.kertas2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintStyle: teksSkala.bodyMedium?.copyWith(
          color: m.tinta2.withValues(alpha: 0.75),
        ),
        labelStyle: teksSkala.bodySmall?.copyWith(
          color: m.tinta,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: teksSkala.bodySmall?.copyWith(color: m.tinta2),
        errorStyle: teksSkala.bodySmall?.copyWith(color: m.gagal),
        // Garis bawah tebal = tempat menulis. Sisi lain tipis.
        // `UnderlineInputBorder` dipakai, bukan `OutlineInputBorder`: yang
        // bikin isian kebaca sebagai kolom formulir itu garis bawahnya yang
        // tebal, dan Flutter tidak bisa menebalkan satu sisi saja pada
        // OutlineInputBorder.
        border: _garisIsian(m.tinta2),
        enabledBorder: _garisIsian(m.tinta2),
        focusedBorder: _garisIsian(m.biru),
        errorBorder: _garisIsian(m.gagal),
        focusedErrorBorder: _garisIsian(m.gagal),
        disabledBorder: _garisIsian(m.kertasTepi),
      ),

      // ── Navigasi bawah: panel logam ──────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: m.logam,
        surfaceTintColor: Colors.transparent,
        indicatorColor: m.logamBawah,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? m.biruTinta : m.etsa,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: keluarga,
            fontSize: 10.5,
            height: 1.24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: m.etsa,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: m.logam,
        selectedIconTheme: IconThemeData(color: m.biruTinta, size: 22),
        unselectedIconTheme: IconThemeData(color: m.etsa, size: 22),
        selectedLabelTextStyle: TextStyle(
          fontFamily: keluarga,
          color: m.etsa,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: keluarga,
          color: m.etsa,
          fontSize: 12,
        ),
      ),

      // ── Lembar, dialog, snack ────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        // Pegangan tetap ada seperti tema lama — beberapa sheet (lembar tolak)
        // mengandalkannya sebagai satu-satunya tanda bisa ditarik.
        showDragHandle: true,
        dragHandleColor: m.tinta2.withValues(alpha: 0.45),
        backgroundColor: m.kertas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: m.kertas,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
      ),

      dialogTheme: DialogThemeData(
        // Batas lebar dari tema lama: di desktop dialog 1.200 px itu garis baca
        // yang tidak bisa diikuti mata.
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        backgroundColor: m.kertas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: m.kertasTepi),
        ),
        titleTextStyle: teksSkala.titleLarge,
        contentTextStyle: teksSkala.bodyMedium,
      ),

      // Snack = pelat logam gelap yang muncul di atas meja.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C2228),
        contentTextStyle: TextStyle(
          fontFamily: keluarga,
          color: const Color(0xFFEAE6DC),
          fontSize: 14,
          height: 1.43,
        ),
        actionTextColor: const Color(0xFF8FB0FF),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: Color(0xFF05070A)),
        ),
      ),

      // ── Sisanya ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: m.logam,
        selectedColor: m.biru,
        side: BorderSide(color: m.logamTepi),
        labelStyle: teksSkala.bodyMedium?.copyWith(
          color: m.etsa,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: teksSkala.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: m.tinta2,
        textColor: m.tinta,
        minVerticalPadding: 12,
      ),

      dividerTheme: DividerThemeData(color: m.garis, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: m.biru,
        linearTrackColor: m.kertas2,
        circularTrackColor: m.kertas2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : m.logamAtas,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : m.kertas2,
        ),
        trackOutlineColor: WidgetStatePropertyAll(m.logamTepi),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: m.tinta2, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : m.tinta2,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2228),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Color(0xFFEAE6DC), fontSize: 12),
      ),
    );
  }

  /// Label tombol tetap HURUF BESAR untuk sementara.
  ///
  /// Keputusan 26 Sep: tombol jadi sentence case. Tapi 333 `find.text` di
  /// test/ mencocokkan label kapital, dan test itu tidak bisa dijalankan di
  /// tempat tema ini ditulis. Jadi pergantian tampilan (warna, material,
  /// bentuk) dipisah dari pergantian huruf: yang ini netral terhadap test, dan
  /// sentence case menyusul sebagai commit sendiri bersama pembaruan test-nya
  /// (`alat/ke_sentence_case.py`). Memakai `TombolLingkar.hurufBesar` yang sama
  /// supaya pembaca layar tetap dapat teks aslinya.
  static Widget _labelTombol(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => TombolLingkar.hurufBesar(child);

  static InputBorder _garisIsian(Color bawah) => UnderlineInputBorder(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    borderSide: BorderSide(color: bawah, width: 2),
  );

  /// Skala tipografi. Prinsipnya sama dengan `AppTypography` lama — heading
  /// rapat & berat, body longgar — dengan dua perubahan:
  ///
  /// 1. Tidak ada lagi ukuran di bawah 12 (panel teknisi lama sampai 8,5).
  /// 2. `labelLarge` TIDAK lagi huruf besar. Kapital cuma dipakai di logam,
  ///    lewat `SidikMaterial.gayaEtsa`, karena di situ dia benar secara fisik.
  static TextTheme _teks(SidikMaterial m) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700,
        letterSpacing: -0.56, color: m.tinta,
      ),
      headlineMedium: TextStyle(
        fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600,
        letterSpacing: -0.24, color: m.tinta,
      ),
      headlineSmall: TextStyle(
        fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600,
        letterSpacing: -0.22, color: m.tinta,
      ),
      titleLarge: TextStyle(
        fontSize: 19, height: 25 / 19, fontWeight: FontWeight.w600, color: m.tinta,
      ),
      titleMedium: TextStyle(
        fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, color: m.tinta,
      ),
      titleSmall: TextStyle(
        fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: m.tinta2,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 26 / 17, color: m.tinta),
      bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, color: m.tinta),
      bodySmall: TextStyle(fontSize: 13, height: 18 / 13, color: m.tinta2),
      labelLarge: TextStyle(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: m.tinta,
      ),
      labelMedium: TextStyle(
        fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: m.tinta2,
      ),
      labelSmall: TextStyle(
        fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: m.tinta2,
      ),
    );
  }
}

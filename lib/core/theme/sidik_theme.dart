import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'bentuk_lab.dart';
import 'palet_lab.dart';
import 'sidik_material.dart';

/// Tema Lab: Material 3 datar, kobalt + netral dingin, terang dan gelap.
///
/// Kenapa file ini penting: hampir semua layar di `lib/screens/` memakai widget
/// Material bawaan (`Card`, `FilledButton`, `TextFormField`, `ListTile`).
/// Dengan menema komponen-komponen itu di sini, **seluruh app berubah tampilan
/// tanpa satu pun layar disentuh**. Itu yang bikin perubahan ini aman: logika,
/// provider, service, dan test alur tetap utuh.
///
/// Nilai warna datang dari [SidikMaterial] (yang membaca `PaletLab`); bentuk
/// dan ukuran sentuh dari [BentukLab] dan [UkuranLab]:
///
/// - Aksi utama (`FilledButton`) 56 dp, radius 16. Semua aksi lain 48 dp,
///   radius 10 (desktop Windows 44, alat tunjuk tetikus).
/// - Isian = kolom bergaris bawah tegas (3:1); fokus = garis kobalt 2 dp.
/// - Tanpa gradien dan tanpa bayangan di layar; hanya lembar bawah dan dialog
///   yang punya bayangan lembut.
/// - Huruf minimum 12 sp, termasuk di desktop (skala 0,9 tidak boleh menembus).
///
/// Dipasang lewat `AppTheme.light` / `AppTheme.dark` (`lib/app.dart`).
class SidikTheme {
  const SidikTheme._();

  /// Keluarga huruf bawaan: **Inter**, sudah dibundel di `pubspec.yaml`.
  static const String keluarga = 'Inter';

  /// Huruf angka ukur, nomor sertifikat, dan serial (IBM Plex Mono).
  ///
  /// Dibundel di `assets/fonts/IBMPlexMono-*.ttf` — sama di Android, iOS,
  /// desktop, dan golden. `fontFeatures` tabular tetap dipasang di
  /// [gayaAngka] sebagai jaring kalau font gagal dimuat.
  static const String keluargaMono = 'IBMPlexMono';

  static ThemeData get terang => _bangun(SidikMaterial.terangDefault);
  static ThemeData get gelap => _bangun(SidikMaterial.gelapDefault);

  /// Platform meja: jendela dilihat dari ~60 cm pakai tetikus, bukan digenggam.
  ///
  /// Dibaca dari `defaultTargetPlatform`, BUKAN dari lebar jendela — yang
  /// menentukan ukuran kontrol itu alat tunjuknya.
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
      onPrimary: m.teksDiBiru,
      primaryContainer: m.biruTipis,
      onPrimaryContainer: terang
          ? PaletLab.kobalt900
          : PaletLab.kobaltGelapTeks,
      // Kobalt juga untuk `secondary`: satu warna merek. Dulu hijau (warna
      // "lulus"), dan layar yang memakai `secondaryContainer` (pil aktif rail,
      // baris terpilih) jadi hijau yang bertabrakan dengan arti PASS.
      secondary: m.biruTinta,
      onSecondary: m.teksDiBiru,
      secondaryContainer: m.biruTipis,
      onSecondaryContainer: terang
          ? PaletLab.kobalt900
          : PaletLab.kobaltGelapTeks,
      error: m.gagal,
      onError: m.teksDiGagal,
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
      // `outline` dipakai 22 tempat sebagai TEKS dan ikon redup (keterangan,
      // ikon keadaan kosong), bukan hanya garis. Jadi nilainya harus >= 4,5:1
      // di kertas dan baki: di tema terang sedikit lebih tua dari garis tegas
      // (`m.garisTegas`, 4,6:1 di kertas tetapi 4,4:1 di baki); di tema gelap
      // garis tegas sudah cukup.
      outline: terang ? PaletLab.garisTeksTerang : m.garisTegas,
      outlineVariant: m.garis,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: terang ? PaletLab.tintaTerang : PaletLab.terangkatGelap,
      onInverseSurface: terang ? PaletLab.latarTerang : PaletLab.tintaGelap,
      inversePrimary: PaletLab.kobalt300,
      surfaceTint: Colors.transparent,
    );

    final teks = _teks(m).apply(fontFamily: keluarga);
    final teksSkala = _meja ? _skalaMeja(teks) : teks;

    final tinggiUtama = _meja ? UkuranLab.aksiMeja : UkuranLab.aksiUtama;
    final tinggiAksi = _meja ? UkuranLab.aksiMeja : UkuranLab.aksi;
    final sudutUtama = _meja ? BentukLab.kontrol : BentukLab.utama;
    final bentukUtama = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sudutUtama),
    );
    final bentukKontrol = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukLab.kontrol),
    );
    final garisHalus = BorderSide(color: m.kertasTepi);
    final tengahTebal = teksSkala.labelLarge;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: skema,
      fontFamily: keluarga,
      textTheme: teksSkala,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Latar layar = permukaan latar.
      scaffoldBackgroundColor: m.meja,
      canvasColor: m.meja,
      dividerColor: m.garis,

      extensions: <ThemeExtension<dynamic>>[m],

      // Dipertahankan apa adanya: transisi halaman bukan bagian dari ganti
      // tampilan, dan iOS/macOS sengaja tetap pakai bawaan platform (gestur
      // geser-balik).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransisiHalus(),
          TargetPlatform.fuchsia: TransisiHalus(),
          TargetPlatform.linux: TransisiHalus(),
          TargetPlatform.windows: TransisiHalus(),
        },
      ),

      // ── App bar: permukaan putih, dipisah garis halus ────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: m.logam,
        surfaceTintColor: Colors.transparent,
        foregroundColor: m.etsa,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: _meja ? 54 : 56,
        titleTextStyle: teksSkala.titleLarge?.copyWith(color: m.etsa),
        iconTheme: IconThemeData(color: m.etsa, size: 24),
        shape: Border(bottom: garisHalus),
      ),

      // ── Kartu: permukaan putih + garis halus, tanpa bayangan ─────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: m.kertas,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SidikMaterial.sudutKertas),
          side: garisHalus,
        ),
      ),

      // ── Aksi utama: kobalt, 56 dp, radius 16 ─────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(tinggiUtama),
          backgroundColor: skema.primary,
          foregroundColor: skema.onPrimary,
          disabledBackgroundColor: m.tungguTipis,
          disabledForegroundColor: m.tinta2.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: bentukUtama,
          textStyle: tengahTebal,
        ),
      ),

      // ── Aksi sekunder: garis tegas, 48 dp, radius 10 ─────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(tinggiAksi),
          foregroundColor: m.biruTinta,
          backgroundColor: m.kertas,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: m.garisTegas),
          shape: bentukKontrol,
          textStyle: tengahTebal,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(48, tinggiAksi),
          foregroundColor: m.biruTinta,
          shape: bentukKontrol,
          textStyle: tengahTebal,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: m.etsa,
          minimumSize: Size.square(tinggiAksi),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: m.biru,
        foregroundColor: m.teksDiBiru,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 2,
        shape: bentukUtama,
      ),

      // ── Isian: kolom dengan garis bawah tegas ────────────────────────
      // Tetap garis bawah (bukan kotak): ~100 isian di layar dan `NeuTextField`
      // (login) dibangun di atas bentuk ini, dan menggantinya jadi kotak
      // menggandakan tepi. Gaya isian tunggal (kotak) = paket lembar kerja.
      // Warna garisnya sekarang garis tegas 3:1, bukan `tinta2` yang pudar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: m.kertas2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        hintStyle: teksSkala.bodyMedium?.copyWith(color: skema.outline),
        labelStyle: teksSkala.bodySmall?.copyWith(
          color: m.tinta,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: teksSkala.bodySmall?.copyWith(color: m.tinta2),
        errorStyle: teksSkala.bodySmall?.copyWith(color: m.gagal),
        prefixIconColor: m.tinta2,
        suffixIconColor: m.tinta2,
        border: _garisIsian(m.garisTegas),
        enabledBorder: _garisIsian(m.garisTegas),
        focusedBorder: _garisIsian(m.biru),
        errorBorder: _garisIsian(m.gagal),
        focusedErrorBorder: _garisIsian(m.gagal),
        disabledBorder: _garisIsian(m.kertasTepi),
      ),

      // ── Navigasi: putih, keadaan aktif = kapsul kobalt tipis ─────────
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: m.logam,
        surfaceTintColor: Colors.transparent,
        indicatorColor: m.biruTipis,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? m.biruTinta : m.tinta2,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => teksSkala.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? m.tinta : m.tinta2,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: m.logam,
        indicatorColor: m.biruTipis,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: m.biruTinta, size: 24),
        unselectedIconTheme: IconThemeData(color: m.tinta2, size: 24),
        selectedLabelTextStyle: teksSkala.labelMedium?.copyWith(color: m.tinta),
        unselectedLabelTextStyle: teksSkala.labelMedium?.copyWith(
          color: m.tinta2,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(0, tinggiAksi)),
          side: WidgetStatePropertyAll(BorderSide(color: m.garisTegas)),
          textStyle: WidgetStatePropertyAll(tengahTebal),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? m.biruTipis : m.kertas,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? skema.onPrimaryContainer
                : m.tinta,
          ),
        ),
      ),

      // ── Lembar, dialog, snack: satu-satunya yang punya bayangan ──────
      bottomSheetTheme: BottomSheetThemeData(
        // Pegangan tetap ada: beberapa sheet (lembar tolak) mengandalkannya
        // sebagai satu-satunya tanda bisa ditarik.
        showDragHandle: true,
        dragHandleColor: m.garisTegas,
        backgroundColor: m.kertas,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: m.kertas,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BentukLab.lembar),
          ),
          side: garisHalus,
        ),
      ),

      dialogTheme: DialogThemeData(
        // Batas lebar: di desktop dialog 1.200 px itu garis baca yang tidak
        // bisa diikuti mata.
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        backgroundColor: m.kertas,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukLab.lembar),
          side: garisHalus,
        ),
        titleTextStyle: teksSkala.titleLarge,
        contentTextStyle: teksSkala.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: skema.inverseSurface,
        contentTextStyle: teksSkala.bodyMedium?.copyWith(
          color: skema.onInverseSurface,
        ),
        actionTextColor: skema.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: bentukKontrol,
      ),

      // ── Sisanya ──────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: m.kertas,
        selectedColor: m.biru,
        checkmarkColor: skema.onPrimary,
        side: BorderSide(color: m.garisTegas),
        // Warna label ikut keadaan: kobalt terpilih = label di atas kobalt.
        labelStyle: teksSkala.bodyMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? skema.onPrimary : m.tinta,
          ),
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: teksSkala.bodyMedium?.copyWith(
          color: skema.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: bentukKontrol,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: m.tinta2,
        textColor: m.tinta,
        minVerticalPadding: 12,
      ),

      dividerTheme: DividerThemeData(color: m.garis, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: m.biru,
        linearTrackColor: m.meja2,
        circularTrackColor: m.meja2,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? skema.onPrimary : m.garisTegas,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : m.kertas2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : m.garisTegas,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(m.teksDiBiru),
        side: BorderSide(color: m.garisTegas, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukLab.sel),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.biru : m.garisTegas,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: skema.inverseSurface,
          borderRadius: BorderRadius.circular(BentukLab.sel),
        ),
        textStyle: teksSkala.bodySmall?.copyWith(color: skema.onInverseSurface),
      ),
    );
  }

  static InputBorder _garisIsian(Color bawah) => UnderlineInputBorder(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(BentukLab.sel),
    ),
    borderSide: BorderSide(color: bawah, width: 2),
  );

  /// Skala huruf desktop: 0,9x, tetapi tidak pernah di bawah 12 sp.
  static TextTheme _skalaMeja(TextTheme t) {
    TextStyle? kecil(TextStyle? g) {
      final u = g?.fontSize;
      if (g == null || u == null) return g;
      final skala = (u * 0.9).roundToDouble();
      return g.copyWith(fontSize: skala < 12 ? 12 : skala);
    }

    return t.copyWith(
      displayLarge: kecil(t.displayLarge),
      displayMedium: kecil(t.displayMedium),
      displaySmall: kecil(t.displaySmall),
      headlineLarge: kecil(t.headlineLarge),
      headlineMedium: kecil(t.headlineMedium),
      headlineSmall: kecil(t.headlineSmall),
      titleLarge: kecil(t.titleLarge),
      titleMedium: kecil(t.titleMedium),
      titleSmall: kecil(t.titleSmall),
      bodyLarge: kecil(t.bodyLarge),
      bodyMedium: kecil(t.bodyMedium),
      bodySmall: kecil(t.bodySmall),
      labelLarge: kecil(t.labelLarge),
      labelMedium: kecil(t.labelMedium),
      labelSmall: kecil(t.labelSmall),
    );
  }

  /// Skala tipografi Lab (Inter; angka ukur memakai [gayaAngka]).
  ///
  /// | Tingkat    | Ukuran/baris | Berat | Slot `TextTheme`          |
  /// |------------|--------------|-------|---------------------------|
  /// | tampilan   | 28/34        | 700   | display*                  |
  /// | judul      | 20/26        | 600   | headline*                 |
  /// | app bar    | 18/24        | 600   | titleLarge                |
  /// | subjudul   | 16/24        | 600   | titleMedium               |
  /// | bagian     | 14/20        | 600   | titleSmall (tinta kedua)  |
  /// | isi        | 15/22        | 400   | bodyMedium (bodyLarge 16) |
  /// | keterangan | 13/18        | 400   | bodySmall (tinta kedua)   |
  /// | tombol     | 15/20        | 600   | labelLarge                |
  /// | label      | 12/16        | 600   | labelMedium, labelSmall   |
  ///
  /// Minimum 12 sp: tidak ada ukuran di bawahnya (panel lama sampai 8,5).
  /// Kapital hanya untuk singkatan (PASS, FAIL, KAN), bukan gaya label.
  static TextTheme _teks(SidikMaterial m) {
    TextStyle gaya(
      double ukuran,
      double baris,
      FontWeight berat,
      Color warna, [
      double spasi = 0,
    ]) => TextStyle(
      fontSize: ukuran,
      height: baris / ukuran,
      fontWeight: berat,
      letterSpacing: spasi,
      color: warna,
    );

    final tampilan = gaya(28, 34, FontWeight.w700, m.tinta, -0.3);
    final judul = gaya(20, 26, FontWeight.w600, m.tinta, -0.1);
    final label = gaya(12, 16, FontWeight.w600, m.tinta2);

    return TextTheme(
      displayLarge: tampilan,
      displayMedium: tampilan,
      displaySmall: tampilan,
      headlineLarge: judul,
      headlineMedium: judul,
      headlineSmall: judul,
      titleLarge: gaya(18, 24, FontWeight.w600, m.tinta),
      titleMedium: gaya(16, 24, FontWeight.w600, m.tinta),
      titleSmall: gaya(14, 20, FontWeight.w600, m.tinta2),
      bodyLarge: gaya(16, 24, FontWeight.w400, m.tinta),
      bodyMedium: gaya(15, 22, FontWeight.w400, m.tinta),
      bodySmall: gaya(13, 18, FontWeight.w400, m.tinta2),
      labelLarge: gaya(15, 20, FontWeight.w600, m.tinta),
      labelMedium: label,
      labelSmall: label,
    );
  }
}

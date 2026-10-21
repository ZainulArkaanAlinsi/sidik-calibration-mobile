import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';

import 'font_studio.dart';
import 'warna_studio.dart';

/// Jarak, sudut, dan ukuran Studio. Kelipatan 4 — grid padat.
abstract final class UkuranStudio {
  static const double j1 = 4;
  static const double j2 = 8;
  static const double j3 = 12;
  static const double j4 = 16;
  static const double j6 = 24;
  static const double j8 = 32;

  /// Sudut alat kerja: tajam, bukan "kartu aplikasi".
  static const double sudut = 4;
  static const double sudutPanel = 6;

  static const double lebarSidebar = 240;
  static const double tinggiBilah = 48;
}

/// Tipografi Studio: Inter untuk teks, IBM Plex Mono untuk angka. Ukurannya
/// lebih kecil dari app lapangan — dilihat dari ±60 cm, informasi padat.
abstract final class TipografiStudio {
  /// Angka (nilai acuan, nomor versi, sha): lebar digit tetap supaya kolom
  /// lurus. `tabularFigures` tetap dipasang sebagai jaring bila font gagal.
  static TextStyle angka({
    double ukuran = 13,
    FontWeight berat = FontWeight.w500,
    Color? warna,
  }) => TextStyle(
    fontFamily: FontStudio.mono,
    fontFamilyFallback: const ['monospace'],
    fontSize: ukuran,
    fontWeight: berat,
    color: warna,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextTheme teks(WarnaStudio w, {required bool sentuh}) {
    // Tablet (sentuh) sedikit lebih besar — jarak pandang & jari, bukan mouse.
    final f = sentuh ? 1.08 : 1.0;
    TextStyle g(
      double ukuran,
      FontWeight berat,
      Color warna, {
      double? jarak,
    }) => TextStyle(
      fontFamily: FontStudio.inter,
      fontSize: ukuran * f,
      fontWeight: berat,
      color: warna,
      letterSpacing: jarak,
      height: 1.35,
    );

    return TextTheme(
      headlineSmall: g(20, FontWeight.w600, w.teks),
      titleLarge: g(17, FontWeight.w600, w.teks),
      titleMedium: g(15, FontWeight.w600, w.teks),
      titleSmall: g(13, FontWeight.w600, w.teks),
      bodyLarge: g(14, FontWeight.w400, w.teks),
      bodyMedium: g(13, FontWeight.w400, w.teks),
      bodySmall: g(12, FontWeight.w400, w.teks2),
      labelLarge: g(13, FontWeight.w600, w.teks),
      labelMedium: g(12, FontWeight.w500, w.teks2),
      labelSmall: g(11, FontWeight.w600, w.teks2, jarak: 0.4),
    );
  }
}

/// Tema Sidik Studio — terang bawaan, gelap tersedia.
abstract final class TemaStudio {
  static ThemeData get terang => bangun(WarnaStudio.terangBawaan);
  static ThemeData get gelap => bangun(WarnaStudio.gelapBawaan);

  /// Mouse & jendela vs jari. Dibaca dari platform, sama alasannya dengan
  /// `SidikTheme._meja`: yang menentukan ukuran kontrol itu alat tunjuknya.
  static bool get _meja => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  static ThemeData bangun(WarnaStudio w) {
    final sentuh = !_meja;
    final kecerahan = w.terang ? Brightness.light : Brightness.dark;
    final teks = TipografiStudio.teks(w, sentuh: sentuh);
    final tinggiKontrol = sentuh ? 48.0 : 36.0;

    final skema = ColorScheme(
      brightness: kecerahan,
      primary: w.primer,
      onPrimary: w.diAtasPrimer,
      primaryContainer: w.aksenTipis,
      onPrimaryContainer: w.teks,
      secondary: w.aksen,
      onSecondary: w.diAtasAksen,
      secondaryContainer: w.aksenTipis,
      onSecondaryContainer: w.teks,
      tertiary: w.info,
      onTertiary: w.permukaan,
      error: w.gagal,
      onError: w.permukaan,
      errorContainer: w.gagalTipis,
      onErrorContainer: w.gagal,
      surface: w.permukaan,
      onSurface: w.teks,
      onSurfaceVariant: w.teks2,
      surfaceContainerLowest: w.permukaan,
      surfaceContainerLow: w.permukaan,
      surfaceContainer: w.permukaanRendah,
      surfaceContainerHigh: w.permukaanRendah,
      surfaceContainerHighest: w.permukaanRendah,
      // `outline` dipakai widget bawaan sebagai garis kontrol DAN oleh
      // sebagian layar sebagai teks redup — jadi nada yang masih terbaca.
      outline: w.teksRedup,
      outlineVariant: w.garis,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: w.teks,
      onInverseSurface: w.permukaan,
      inversePrimary: w.aksen,
      surfaceTint: Colors.transparent,
    );

    final sudut = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(UkuranStudio.sudut),
    );
    final garisIsian = OutlineInputBorder(
      borderRadius: BorderRadius.circular(UkuranStudio.sudut),
      borderSide: BorderSide(color: w.garisKuat),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: kecerahan,
      colorScheme: skema,
      fontFamily: FontStudio.inter,
      textTheme: teks,
      visualDensity: sentuh ? VisualDensity.standard : VisualDensity.compact,
      materialTapTargetSize: sentuh
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      scaffoldBackgroundColor: w.latar,
      canvasColor: w.permukaan,
      dividerColor: w.garis,
      splashFactory: InkRipple.splashFactory,
      hoverColor: w.teks.withValues(alpha: 0.05),
      focusColor: w.aksen.withValues(alpha: 0.22),
      highlightColor: w.teks.withValues(alpha: 0.06),
      extensions: <ThemeExtension<dynamic>>[w, materialUntukLayarBersama(w)],

      appBarTheme: AppBarTheme(
        backgroundColor: w.permukaan,
        foregroundColor: w.teks,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: sentuh ? 56 : UkuranStudio.tinggiBilah,
        titleTextStyle: teks.titleMedium,
        iconTheme: IconThemeData(color: w.teks2, size: 20),
        actionsIconTheme: IconThemeData(color: w.teks2, size: 20),
        shape: Border(bottom: BorderSide(color: w.garis)),
      ),
      cardTheme: CardThemeData(
        color: w.permukaan,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UkuranStudio.sudutPanel),
          side: BorderSide(color: w.garis),
        ),
      ),
      dividerTheme: DividerThemeData(color: w.garis, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: w.teks2, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: w.permukaan,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: UkuranStudio.j3,
          vertical: UkuranStudio.j3,
        ),
        border: garisIsian,
        enabledBorder: garisIsian,
        focusedBorder: garisIsian.copyWith(
          borderSide: BorderSide(color: w.primer, width: 2),
        ),
        errorBorder: garisIsian.copyWith(
          borderSide: BorderSide(color: w.gagal),
        ),
        focusedErrorBorder: garisIsian.copyWith(
          borderSide: BorderSide(color: w.gagal, width: 2),
        ),
        labelStyle: teks.bodyMedium?.copyWith(color: w.teks2),
        floatingLabelStyle: teks.bodyMedium?.copyWith(color: w.teks),
        hintStyle: teks.bodyMedium?.copyWith(color: w.teksRedup),
        errorStyle: teks.bodySmall?.copyWith(color: w.gagal),
        prefixIconColor: w.teks2,
        suffixIconColor: w.teks2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: w.primer,
          foregroundColor: w.diAtasPrimer,
          disabledBackgroundColor: w.permukaanRendah,
          disabledForegroundColor: w.teksRedup,
          minimumSize: Size(64, tinggiKontrol),
          padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j4),
          shape: sudut,
          textStyle: teks.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: w.teks,
          minimumSize: Size(64, tinggiKontrol),
          padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j4),
          side: BorderSide(color: w.garisKuat),
          shape: sudut,
          textStyle: teks.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: w.terang ? w.primer : w.aksenTeks,
          minimumSize: Size(48, tinggiKontrol),
          shape: sudut,
          textStyle: teks.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: w.teks2, shape: sudut),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: w.teks,
        unselectedLabelColor: w.teks2,
        labelStyle: teks.labelLarge,
        unselectedLabelStyle: teks.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: w.aksen,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: w.aksen, width: 3),
        ),
        dividerColor: w.garis,
        overlayColor: WidgetStatePropertyAll(w.teks.withValues(alpha: 0.05)),
        tabAlignment: TabAlignment.start,
      ),
      listTileTheme: ListTileThemeData(
        dense: !sentuh,
        iconColor: w.teks2,
        textColor: w.teks,
        selectedColor: w.teks,
        selectedTileColor: w.aksenTipis,
        contentPadding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j3),
        shape: sudut,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: w.permukaanRendah,
        side: BorderSide(color: w.garis),
        shape: sudut,
        labelStyle: teks.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: UkuranStudio.j1),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(w.permukaanRendah),
        headingTextStyle: teks.labelMedium?.copyWith(
          color: w.teks,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: teks.bodyMedium,
        headingRowHeight: sentuh ? 44 : 34,
        dataRowMinHeight: sentuh ? 44 : 30,
        dataRowMaxHeight: sentuh ? 52 : 36,
        dividerThickness: 1,
        horizontalMargin: UkuranStudio.j3,
        columnSpacing: UkuranStudio.j6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: w.permukaan,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UkuranStudio.sudutPanel),
        ),
        titleTextStyle: teks.titleMedium,
        contentTextStyle: teks.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: w.permukaan,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(UkuranStudio.sudutPanel),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: w.teks,
          borderRadius: BorderRadius.circular(UkuranStudio.sudut),
        ),
        textStyle: teks.bodySmall?.copyWith(color: w.permukaan),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: w.teks,
        contentTextStyle: teks.bodyMedium?.copyWith(color: w.permukaan),
        shape: sudut,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: w.terang ? w.primer : w.aksen,
        linearTrackColor: w.permukaanRendah,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(!sentuh),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(UkuranStudio.sudut),
        thumbColor: WidgetStatePropertyAll(w.garisKuat.withValues(alpha: 0.6)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: w.sisi,
        elevation: 0,
        indicatorColor: w.aksen,
        indicatorShape: sudut,
        selectedIconTheme: IconThemeData(color: w.diAtasAksen, size: 22),
        unselectedIconTheme: IconThemeData(color: w.sisiTeksRedup, size: 22),
        selectedLabelTextStyle: teks.labelMedium?.copyWith(
          color: w.sisiTeks,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: teks.labelMedium?.copyWith(
          color: w.sisiTeksRedup,
        ),
        labelType: NavigationRailLabelType.all,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: w.sisi,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: const RoundedRectangleBorder(),
        width: UkuranStudio.lebarSidebar + 40,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: w.sisiAktif,
        textColor: w.sisiTeks,
        textStyle: teks.labelSmall,
      ),
    );
  }

  /// Token `SidikMaterial` versi Studio untuk layar BERSAMA dari paket
  /// sidik_calibration (layar data acuan M2 membaca `SidikMaterial.of`).
  ///
  /// Tanpa ini layar M2 jatuh ke `SidikMaterial.terangDefault` — kertas krem
  /// app lapangan di dalam jendela Studio. Dengan ini warnanya ikut Studio
  /// dan gradien logam jadi rata (atas = tengah = bawah). Yang TIDAK bisa
  /// diatur lewat token (bayangan hitam di `kertasLembar`, bayangan teks
  /// `gayaEtsa`) tetap terlihat — dicatat di laporan S0b, bukan ditambal di
  /// paket bersama.
  static SidikMaterial materialUntukLayarBersama(WarnaStudio w) =>
      SidikMaterial(
        terang: w.terang,
        meja: w.latar,
        meja2: w.permukaanRendah,
        kertas: w.permukaan,
        kertas2: w.permukaanRendah,
        kertasTepi: w.garis,
        garis: w.garis,
        tinta: w.teks,
        tinta2: w.teks2,
        pensil: w.teksRedup,
        logam: w.permukaanRendah,
        logamAtas: w.permukaanRendah,
        logamBawah: w.permukaanRendah,
        logamTepi: w.garis,
        etsa: w.teks2,
        kilau: Colors.transparent,
        lekuk: Colors.transparent,
        biru: w.primer,
        biruAtas: w.primer,
        biruTipis: w.aksenTipis,
        biruTinta: w.terang ? w.primer : w.aksenTeks,
        lulus: w.lulus,
        lulusTipis: w.lulusTipis,
        gagal: w.gagal,
        gagalTipis: w.gagalTipis,
        awas: w.awas,
        awasTipis: w.awasTipis,
        tunggu: w.teks2,
        tungguTipis: w.permukaanRendah,
        // Kaca (readout) selalu gelap, di dua tema.
        kaca: w.terang ? w.teks : w.permukaanRendah,
        kaca2: w.terang ? w.teks : w.permukaan,
        lcdTeks: w.terang ? w.permukaan : w.teks,
        lcdHijau: w.lulus,
        lcdAmber: w.aksen,
      );
}

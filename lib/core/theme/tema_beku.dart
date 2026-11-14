import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'palet_beku.dart';
import 'sidik_material.dart';

/// TEMA BEKU: `ThemeData` Lab per 14 Nov 2026, dibangun dari [PaletBeku]
/// (desain ulang Lab, L1a).
///
/// Salinan `SidikTheme._bangun` (`sidik_theme.dart`), kata demi kata, dengan
/// tiga perbedaan yang SENGAJA:
///
/// - warna dari [PaletBeku], bukan `PaletLab`; radius dan tinggi dari
///   `BentukBeku`/`UkuranBeku`, bukan `BentukLab`/`UkuranLab`;
/// - `onPrimary`/`onError` ditulis dari [PaletBeku], tidak lewat getter
///   `SidikMaterial.teksDiBiru`/`teksDiGagal` (getter itu membaca `PaletLab`);
/// - ada [PenandaBeku] di `extensions`, supaya tes bisa membuktikan sebuah
///   layar sungguh berada di bawah tema ini.
///
/// Nilai `SidikMaterial` untuk dua mode disalin dari `terangDefault` dan
/// `gelapDefault`. Semua `ThemeExtension` Lab (`SidikMaterial`) ikut di sini.
///
/// ## Kenapa disalin, bukan builder bersama
///
/// Lembar kerja berstatus BEKU (`docs/desain-ulang/BEKU.md`). Kalau tema beku
/// dan tema app dibangun oleh satu fungsi berparameter, setiap suntingan
/// `SidikTheme` (L1b dan seterusnya) ikut mengubah lembar kerja. Dua salinan
/// berarti suntingan `SidikTheme` tidak bisa bocor ke sini.
///
/// ## Jangan diubah
///
/// PR desain mana pun tidak boleh mengubah berkas ini. Bukti kesetiaannya ke
/// `SidikTheme` hari ini ditulis di deskripsi PR L1a; golden
/// `test/beku/goldens/` menjaga hasil render.
///
/// Dipasang lewat `BekuLembarKerja` (`beku_lembar_kerja.dart`).
class TemaBeku {
  const TemaBeku._();

  /// Tema terang beku. Dibangun sekali per platform lalu dipakai ulang: tema
  /// yang berganti objek tiap `build` (penutup `WidgetStateProperty`-nya selalu
  /// baru) membuat semua pemakainya dibangun ulang, padahal isinya sama.
  static ThemeData get terang => _ambil(Brightness.light);

  /// Tema gelap beku.
  static ThemeData get gelap => _ambil(Brightness.dark);

  /// Tema beku yang cocok dengan mode (terang/gelap) tema di atas [context].
  static ThemeData untuk(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gelap : terang;

  /// Kunci memuat platform: `_bangun` membaca `defaultTargetPlatform`
  /// (`_meja`, `visualDensity`, tipografi) dan tes menggantinya per kasus.
  static final Map<(Brightness, TargetPlatform), ThemeData> _tembolok = {};

  static ThemeData _ambil(Brightness mode) =>
      _tembolok.putIfAbsent(
        (mode, defaultTargetPlatform),
        () => _bangun(
          mode == Brightness.light ? _materialTerang : _materialGelap,
        ),
      );

  /// Keluarga huruf bawaan: **Inter**, sama dengan `SidikTheme.keluarga`.
  static const String _keluarga = 'Inter';

  /// Platform meja: jendela dilihat dari ~60 cm pakai tetikus, bukan digenggam.
  ///
  /// Dibaca dari `defaultTargetPlatform`, BUKAN dari lebar jendela.
  static bool get _meja => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  static ThemeData _bangun(SidikMaterial m) {
    final terang = m.terang;
    final brightness = terang ? Brightness.light : Brightness.dark;
    // Ditulis dari PaletBeku, BUKAN lewat getter `SidikMaterial.teksDiBiru` /
    // `teksDiGagal` (getter itu membaca `PaletLab`, yang nanti berganti).
    final teksDiBiru = terang ? PaletBeku.putih : PaletBeku.kobaltDiAtas300;
    final teksDiGagal = terang ? PaletBeku.putih : PaletBeku.gagalDiAtasGelap;

    final skema = ColorScheme(
      brightness: brightness,
      primary: m.biru,
      onPrimary: teksDiBiru,
      primaryContainer: m.biruTipis,
      onPrimaryContainer: terang
          ? PaletBeku.kobalt900
          : PaletBeku.kobaltGelapTeks,
      // Kobalt juga untuk `secondary`: satu warna merek. Dulu hijau (warna
      // "lulus"), dan layar yang memakai `secondaryContainer` (pil aktif rail,
      // baris terpilih) jadi hijau yang bertabrakan dengan arti PASS.
      secondary: m.biruTinta,
      onSecondary: teksDiBiru,
      secondaryContainer: m.biruTipis,
      onSecondaryContainer: terang
          ? PaletBeku.kobalt900
          : PaletBeku.kobaltGelapTeks,
      error: m.gagal,
      onError: teksDiGagal,
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
      outline: terang ? PaletBeku.garisTeksTerang : m.garisTegas,
      outlineVariant: m.garis,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: terang ? PaletBeku.tintaTerang : PaletBeku.terangkatGelap,
      onInverseSurface: terang ? PaletBeku.latarTerang : PaletBeku.tintaGelap,
      inversePrimary: PaletBeku.kobalt300,
      surfaceTint: Colors.transparent,
    );

    final teks = _teks(m).apply(fontFamily: _keluarga);
    final teksSkala = _meja ? _skalaMeja(teks) : teks;

    final tinggiUtama = _meja ? UkuranBeku.aksiMeja : UkuranBeku.aksiUtama;
    final tinggiAksi = _meja ? UkuranBeku.aksiMeja : UkuranBeku.aksi;
    final sudutUtama = _meja ? BentukBeku.kontrol : BentukBeku.utama;
    final bentukUtama = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(sudutUtama),
    );
    final bentukKontrol = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukBeku.kontrol),
    );
    final garisHalus = BorderSide(color: m.kertasTepi);
    final tengahTebal = teksSkala.labelLarge;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: skema,
      fontFamily: _keluarga,
      textTheme: teksSkala,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Latar layar = permukaan latar.
      scaffoldBackgroundColor: m.meja,
      canvasColor: m.meja,
      dividerColor: m.garis,

      extensions: <ThemeExtension<dynamic>>[m, const PenandaBeku()],

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
          borderRadius: BorderRadius.circular(BentukBeku.panel),
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
        foregroundColor: teksDiBiru,
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
            top: Radius.circular(BentukBeku.lembar),
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
          borderRadius: BorderRadius.circular(BentukBeku.lembar),
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
        checkColor: WidgetStatePropertyAll(teksDiBiru),
        side: BorderSide(color: m.garisTegas, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBeku.sel),
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
          borderRadius: BorderRadius.circular(BentukBeku.sel),
        ),
        textStyle: teksSkala.bodySmall?.copyWith(color: skema.onInverseSurface),
      ),
    );
  }

  static InputBorder _garisIsian(Color bawah) => UnderlineInputBorder(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(BentukBeku.sel),
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

  // ══════════════════════════════════════════════════════════════════════
  // NILAI TOKEN BEKU (salinan SidikMaterial.terangDefault / gelapDefault)
  // ══════════════════════════════════════════════════════════════════════

  static const SidikMaterial _materialTerang = SidikMaterial(
    terang: true,
    meja: PaletBeku.latarTerang,
    meja2: PaletBeku.latar2Terang,
    kertas: PaletBeku.kertasTerang,
    kertas2: PaletBeku.kertas2Terang,
    kertasTepi: PaletBeku.garisHalusTerang,
    garis: PaletBeku.garisHalusTerang,
    tinta: PaletBeku.tintaTerang, // 17,7:1 di kertas
    tinta2: PaletBeku.tinta2Terang, // 7,7:1 di kertas, 7,0:1 di latar
    pensil: PaletBeku.pensilTerang, // saran OCR, 5,4:1 di kertas
    logam: PaletBeku.kertasTerang,
    logamAtas: PaletBeku.kertasTerang,
    logamBawah: PaletBeku.latar2Terang,
    logamTepi: PaletBeku.garisTegasTerang, // garis tegas, 4,6:1 di kertas
    etsa: PaletBeku.tintaTerang,
    kilau: PaletBeku.tembus,
    lekuk: PaletBeku.tembus,
    biru: PaletBeku.kobalt700, // 9,5:1 di kertas; putih di atasnya 9,5:1
    biruAtas: PaletBeku.kobalt300,
    biruTipis: PaletBeku.kobalt100,
    biruTinta: PaletBeku.kobalt700,
    lulus: PaletBeku.lulusTerang, // 7,3:1 di latar tipisnya
    lulusTipis: PaletBeku.lulusLatarTerang,
    gagal: PaletBeku.gagalTerang, // 6,1:1
    gagalTipis: PaletBeku.gagalLatarTerang,
    awas: PaletBeku.awasTerang, // 6,3:1
    awasTipis: PaletBeku.awasLatarTerang,
    tunggu: PaletBeku.tungguTerang, // 8,7:1
    tungguTipis: PaletBeku.tungguLatarTerang,
    kaca: PaletBeku.latarGelap,
    kaca2: PaletBeku.kertasGelap,
    lcdHijau: PaletBeku.lulusGelap,
    lcdAmber: PaletBeku.awasGelap,
    lcdTeks: PaletBeku.tintaGelap,
  );

  /// Tema gelap: latar `#0E1320`, permukaan `#171D2B`, kobalt jenjang 300.
  static const SidikMaterial _materialGelap = SidikMaterial(
    terang: false,
    meja: PaletBeku.latarGelap,
    meja2: PaletBeku.latar2Gelap,
    kertas: PaletBeku.kertasGelap,
    kertas2: PaletBeku.kertas2Gelap,
    kertasTepi: PaletBeku.garisHalusGelap,
    garis: PaletBeku.garisHalusGelap,
    tinta: PaletBeku.tintaGelap, // 14,0:1 di kertas
    tinta2: PaletBeku.tinta2Gelap, // 7,9:1
    pensil: PaletBeku.pensilGelap, // 5,8:1
    logam: PaletBeku.kertasGelap,
    logamAtas: PaletBeku.kertasGelap,
    logamBawah: PaletBeku.latar2Gelap,
    logamTepi: PaletBeku.garisTegasGelap, // garis tegas, 4,7:1 di kertas
    etsa: PaletBeku.tintaGelap,
    kilau: PaletBeku.tembus,
    lekuk: PaletBeku.tembus,
    biru: PaletBeku.kobalt300, // isi tombol & teks aksen: 7,8:1 di kertas
    biruAtas: PaletBeku.kobalt300,
    biruTipis: PaletBeku.kobaltGelapTipis,
    biruTinta: PaletBeku.kobalt300,
    lulus: PaletBeku.lulusGelap,
    lulusTipis: PaletBeku.lulusLatarGelap,
    gagal: PaletBeku.gagalGelap,
    gagalTipis: PaletBeku.gagalLatarGelap,
    awas: PaletBeku.awasGelap,
    awasTipis: PaletBeku.awasLatarGelap,
    tunggu: PaletBeku.tungguGelap,
    tungguTipis: PaletBeku.tungguLatarGelap,
    kaca: PaletBeku.latarGelap,
    kaca2: PaletBeku.kertasGelap,
    lcdHijau: PaletBeku.lulusGelap,
    lcdAmber: PaletBeku.awasGelap,
    lcdTeks: PaletBeku.tintaGelap,
  );
}

/// Penanda: layar ini berada di bawah [TemaBeku].
///
/// Tidak membawa data dan tidak dibaca kode produksi mana pun. Hanya tes
/// (`test/beku/tema_beku_terpasang_test.dart`) yang memakainya:
/// `Theme.of(context).extension<PenandaBeku>() != null` membuktikan sebuah
/// layar, dialog, atau lembar bawah benar-benar membaca tema beku. Tema app
/// (`SidikTheme`) tidak memilikinya.
@immutable
class PenandaBeku extends ThemeExtension<PenandaBeku> {
  const PenandaBeku();

  @override
  PenandaBeku copyWith() => this;

  @override
  PenandaBeku lerp(ThemeExtension<PenandaBeku>? other, double t) => this;
}

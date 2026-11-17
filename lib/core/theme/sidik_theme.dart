import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion/transisi_halaman.dart';
import 'app_ukuran.dart';
import 'bentuk_lab.dart';
import 'palet_lab.dart';
import 'sidik_material.dart';

/// Tema Lab: Material 3 datar, "Biru Awan" (L1b, 15 Nov 2026), terang dan gelap,
/// diselaraskan ke REVISI 16 Nov 2026 (R1, `docs/desain-ulang/REVISI-16NOV.md`):
/// tenang, formal, ringkas.
///
/// Kenapa file ini penting: hampir semua layar di `lib/screens/` memakai widget
/// Material bawaan (`Card`, `FilledButton`, `TextFormField`, `ListTile`).
/// Dengan menema komponen-komponen itu di sini, **seluruh app berubah tampilan
/// tanpa satu pun layar disentuh**. Itu yang bikin perubahan ini aman: logika,
/// provider, service, dan test alur tetap utuh.
///
/// Nilai warna datang dari [SidikMaterial] (yang membaca `PaletLab`); bentuk
/// dan ukuran sentuh dari [BentukBiruAwan], [UkuranBiruAwan], dan [UkuranLab]:
///
/// - Aksi utama (`FilledButton`) dan semua aksi lain 48 dp, persegi bersudut
///   [BentukBiruAwan.tombol] (10); desktop Windows 44 (alat tunjuk tetikus).
/// - Isian = kotak radius 12 bertepi kontrol (3:1, `PaletLab.garisKontrol`);
///   fokus = primer 2 dp; galat = koral batang 2 dp. Dialog dan lembar bawah
///   radius 16.
/// - Kartu radius [BentukBiruAwan.kartu] (16), dipotong (`antiAlias`) supaya
///   riak widget lama tidak keluar dari sudutnya. `SidikMaterial.sudutKertas`
///   (8) TIDAK diubah: ia dibaca `neu.dart`/`tabel_perhitungan` yang beku, jadi
///   permukaan lama (`SidikPermukaan`, `kertasLembar`) tetap 8 sampai layarnya
///   dipoles.
/// - Tanpa gradien dan tanpa bayangan di layar; hanya lembar bawah dan dialog
///   yang punya bayangan sangat tipis.
/// - Huruf minimum 12 sp, termasuk di desktop (skala 0,9 tidak boleh menembus).
///   Berat 400/500/600 saja (tidak ada 700/800), tanpa spasi huruf negatif.
/// - Lembar kerja tidak memakai tema ini: `TemaBeku` (`BEKU.md`). Yang tetap
///   dibaca dari sini oleh area beku hanya [keluarga], [keluargaMono], dan
///   [gayaAngka] (`lembar_kerja_screen.dart`): JANGAN diubah.
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
      // Teks biru di atas kabut = primerTua (7,18:1). Primer di atas kabut
      // cuma 4,47:1 (`DESIGN.md`: DILARANG sebagai teks).
      onPrimaryContainer: terang ? PaletLab.primerTua : PaletLab.primerTuaGelap,
      // Biru juga untuk `secondary`: satu warna merek. Dulu hijau (warna
      // "lulus"), dan layar yang memakai `secondaryContainer` (pil aktif rail,
      // baris terpilih) jadi hijau yang bertabrakan dengan arti PASS.
      secondary: m.biruTinta,
      onSecondary: m.teksDiBiru,
      secondaryContainer: m.biruTipis,
      onSecondaryContainer: terang
          ? PaletLab.primerTua
          : PaletLab.primerTuaGelap,
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
      // di kertas dan baki. Tepi kontrol terang (`PaletLab.garisKontrol`) cuma
      // ±3,3:1, jadi di tema terang `outline` = tinta kedua; di tema gelap garis
      // tegas (`#7C8FA8`) sudah >= 4,5:1.
      outline: terang ? PaletLab.tinta2 : m.garisTegas,
      outlineVariant: m.garis,
      shadow: Colors.black,
      scrim: Colors.black,
      // Toast/snack/tooltip navy (`ELEMEN.md`). Tema gelap: kabut gelap, sedikit
      // lebih terang dari kertas.
      inverseSurface: terang ? PaletLab.tinta : PaletLab.kabutGelap,
      onInverseSurface: terang ? PaletLab.latar : PaletLab.tintaGelap,
      inversePrimary: PaletLab.primerGelap,
      surfaceTint: Colors.transparent,
    );

    final teks = _teks(m).apply(fontFamily: keluarga);
    final teksSkala = _meja ? _skalaMeja(teks) : teks;

    // Desktop (tetikus) tetap 44: keputusan L1b, tidak ada ukuran meja di
    // `UkuranBiruAwan`.
    final tinggiUtama = _meja ? UkuranLab.aksiMeja : UkuranBiruAwan.tombolUtama;
    final tinggiAksi = _meja ? UkuranLab.aksiMeja : UkuranBiruAwan.tombolTegas;
    // Tombol = persegi bersudut 10 (revisi 16 Nov; dulu pil). Kontrol kecil
    // lain (snack) tetap sudut lama.
    final bentukTombol = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BentukBiruAwan.tombol),
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
        // Dipotong ke sudutnya: riak dan isi widget lama (InkWell persegi di
        // dalam Card) tidak boleh keluar dari sudut 16.
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
          side: garisHalus,
        ),
      ),

      // ── Aksi utama: primer, 48 dp, sudut 10 ──────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(tinggiUtama),
          backgroundColor: skema.primary,
          foregroundColor: skema.onPrimary,
          // Mati = netral. `tungguTipis` terang sekarang awan (biru langit),
          // yang terbaca sebagai stempel "menunggu", bukan tombol mati.
          disabledBackgroundColor: terang
              ? PaletLab.netralStempel
              : m.tungguTipis,
          disabledForegroundColor: m.tinta2.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: bentukTombol,
          textStyle: tengahTebal,
        ),
      ),

      // ── Aksi sekunder: tepi kontrol (3:1), 48 dp, sudut 10 ───────────
      // `DESIGN.md` menulis tepi #C5D5E6, tetapi itu cuma ±1,5:1 di putih;
      // tepi tombol memakai `garisKontrol` (keputusan L1b).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(tinggiAksi),
          foregroundColor: m.biruTinta,
          backgroundColor: m.kertas,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: m.garisTegas),
          shape: bentukTombol,
          textStyle: tengahTebal,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(48, tinggiAksi),
          foregroundColor: m.biruTinta,
          shape: bentukTombol,
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
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 1,
        shape: bentukTombol,
      ),

      // ── Isian: kotak radius 12, tepi kontrol (3:1) ───────────────────
      // Isi putih (`ELEMEN.md` §Isian). Fokus = primer 2 dp; galat = koral
      // batang 2 dp (3,36:1 di putih); kalimat galat tetap `m.gagal` (merah
      // tua: koral gagal sebagai teks). `NeuTextField` (login) dan ~100 isian
      // lama ikut bentuk ini; layar yang didesain ulang memakai komponen baru.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: m.kertas,
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
        border: _kotakIsian(m.garisTegas, 1),
        enabledBorder: _kotakIsian(m.garisTegas, 1),
        focusedBorder: _kotakIsian(m.biru, 2),
        errorBorder: _kotakIsian(PaletLab.koralBatang, 2),
        focusedErrorBorder: _kotakIsian(PaletLab.koralBatang, 2),
        disabledBorder: _kotakIsian(m.kertasTepi, 1),
      ),

      // ── Navigasi: putih, keadaan aktif = kapsul kabut ─────────────────
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
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BentukBiruAwan.lembarBawah),
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
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        // Ikon di atas judul: `secondary` (bawaan M3) tidak terbaca di dialog
        // putih; pakai `primary` (pelajaran tinjauan Pelanggan R1).
        iconColor: skema.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBiruAwan.dialog),
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
        // Warna label ikut keadaan: primer terpilih = label di atas primer.
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
        // Chip = persegi bersudut 12 (revisi 16 Nov; dulu pil).
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BentukBiruAwan.saringan),
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

  static InputBorder _kotakIsian(Color tepi, double tebal) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentukBiruAwan.isian),
        borderSide: BorderSide(color: tepi, width: tebal),
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
  /// | tampilan   | 24/30        | 600   | display*                  |
  /// | judul      | 20/26        | 600   | headline*                 |
  /// | app bar    | 18/24        | 600   | titleLarge                |
  /// | subjudul   | 16/24        | 600   | titleMedium               |
  /// | bagian     | 14/20        | 600   | titleSmall (tinta kedua)  |
  /// | isi        | 15/22        | 400   | bodyMedium (bodyLarge 16) |
  /// | keterangan | 13/18        | 400   | bodySmall (tinta kedua)   |
  /// | tombol     | 15/20        | 600   | labelLarge                |
  /// | label      | 12/16        | 500   | labelMedium, labelSmall   |
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

    final tampilan = gaya(24, 30, FontWeight.w600, m.tinta);
    final judul = gaya(20, 26, FontWeight.w600, m.tinta);
    final label = gaya(12, 16, FontWeight.w500, m.tinta2);

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

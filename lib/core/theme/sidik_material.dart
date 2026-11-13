import 'package:flutter/material.dart';

import 'bentuk_lab.dart';
import 'palet_lab.dart';

/// Token & resep permukaan untuk tema Lab (kobalt + netral dingin).
///
/// Ini SATU-SATUNYA tempat peran warna dan bentuk permukaan ditentukan; nilai
/// mentahnya ada di `PaletLab`. Tidak boleh ada `Color(0x...)` yang ditulis
/// langsung di widget (dijaga `test/tema/token_only_test.dart`). Token ikut
/// tema lewat [ThemeExtension], jadi mode gelap tidak perlu `if (isDark)`
/// bertebaran di layar.
///
/// ## Nama lama, isi baru (13 Nov 2026)
///
/// Nama-nama di sini (`meja`, `kertas`, `logam`, `kaca`, `etsa`, ...) berasal
/// dari sistem "Meja Kerja Lab" yang meniru material fisik. Layar-layar masih
/// memakainya, jadi namanya dipertahankan dan yang berganti isinya:
///
/// - [meja] latar layar (`#F2F4F8`), [kertas] baris/kartu/sel (putih),
///   [kertas2] permukaan cekung.
/// - [logam] permukaan app bar dan navigasi: sekarang putih, bukan aluminium
///   disikat. [logamTepi] adalah GARIS TEGAS (tepi tombol sekunder dan isian,
///   >= 3:1); garis pemisah halus ada di [kertasTepi] dan [garis].
/// - [kaca] dan `lcd*` permukaan alat ukur yang selalu gelap.
/// - Resep di bawah ([kertasLembar], [logamTimbul], ...) menghasilkan
///   permukaan DATAR: tanpa gradien, tanpa bayangan, tanpa bayangan dalam.
///   Kedalaman dibangun dari garis halus dan beda warna permukaan.
///
/// Label HURUF BESAR dengan spasi lebar tidak lagi dibenarkan di mana pun;
/// [gayaEtsa] sekarang gaya keterangan kecil biasa. Layar yang masih memanggil
/// `toUpperCase()` akan dirapikan oleh paket layarnya.
///
/// ## Cara pakai
///
/// ```dart
/// final m = SidikMaterial.of(context);
/// Container(decoration: m.kertasLembar(), child: ...);
/// ```
@immutable
class SidikMaterial extends ThemeExtension<SidikMaterial> {
  const SidikMaterial({
    required this.terang,
    required this.meja,
    required this.meja2,
    required this.kertas,
    required this.kertas2,
    required this.kertasTepi,
    required this.garis,
    required this.tinta,
    required this.tinta2,
    required this.pensil,
    required this.logam,
    required this.logamAtas,
    required this.logamBawah,
    required this.logamTepi,
    required this.etsa,
    required this.kilau,
    required this.lekuk,
    required this.biru,
    required this.biruAtas,
    required this.biruTipis,
    required this.biruTinta,
    required this.lulus,
    required this.lulusTipis,
    required this.gagal,
    required this.gagalTipis,
    required this.awas,
    required this.awasTipis,
    required this.tunggu,
    required this.tungguTipis,
    required this.kaca,
    required this.kaca2,
    required this.lcdHijau,
    required this.lcdAmber,
    required this.lcdTeks,
  });

  /// `true` untuk tema terang. Dipakai resep material buat milih arah cahaya —
  /// bukan buat milih warna (warnanya sudah ikut token).
  final bool terang;

  // ── MEJA: permukaan paling bawah, latar layar ─────────────────────────
  final Color meja;
  final Color meja2;

  // ── KERTAS ────────────────────────────────────────────────────────────
  final Color kertas;
  final Color kertas2;
  final Color kertasTepi;

  /// Garis bantu biru seperti buku tulis. Dipakai sebagai pemisah baris di
  /// daftar — bukan garis UI abu-abu.
  final Color garis;

  /// Tinta pulpen. Sengaja bukan hitam murni.
  final Color tinta;
  final Color tinta2;

  /// Warna angka hasil OCR. Ditulis "pensil" karena memang belum dipastikan
  /// manusia — aturan lama `keyakinan == null berarti TIDAK DIKETAHUI` tetap
  /// berlaku, dan warna ini yang menyampaikannya.
  final Color pensil;

  // ── LOGAM ─────────────────────────────────────────────────────────────
  final Color logam;
  final Color logamAtas;
  final Color logamBawah;
  final Color logamTepi;

  /// Warna label yang diukir di logam.
  final Color etsa;

  /// Sisi yang kena cahaya (atas) dan sisi bayangan (bawah).
  final Color kilau;
  final Color lekuk;

  // ── ANODISASI: satu-satunya warna interaktif ──────────────────────────
  final Color biru;
  final Color biruAtas;
  final Color biruTipis;

  /// Biru untuk TEKS/ikon di atas kertas. Beda dari [biru] karena di tema gelap
  /// biru tombol terlalu pekat buat dibaca sebagai huruf.
  final Color biruTinta;

  // ── TINTA CAP: status ─────────────────────────────────────────────────
  final Color lulus;
  final Color lulusTipis;
  final Color gagal;
  final Color gagalTipis;
  final Color awas;
  final Color awasTipis;
  final Color tunggu;
  final Color tungguTipis;

  // ── KACA / LCD ────────────────────────────────────────────────────────
  final Color kaca;
  final Color kaca2;
  final Color lcdHijau;
  final Color lcdAmber;
  final Color lcdTeks;

  /// Ambil token dari context. Aman dipanggil di mana pun di bawah
  /// `MaterialApp` yang temanya dibangun `SidikTheme`.
  static SidikMaterial of(BuildContext context) =>
      Theme.of(context).extension<SidikMaterial>() ?? terangDefault;

  /// Garis tegas (tepi isian, sel, tombol sekunder, ikon penting): >= 3:1.
  Color get garisTegas => logamTepi;

  /// Warna label/ikon DI ATAS isi [biru] (tombol utama). Putih di tema terang,
  /// kobalt tua di tema gelap (isi [biru]-nya kobalt terang).
  Color get teksDiBiru => terang ? PaletLab.putih : PaletLab.kobaltDiAtas300;

  /// Warna label/ikon DI ATAS isi [gagal] (tombol bahaya).
  Color get teksDiGagal => terang ? PaletLab.putih : PaletLab.gagalDiAtasGelap;

  // ══════════════════════════════════════════════════════════════════════
  // RESEP PERMUKAAN (datar)
  // ══════════════════════════════════════════════════════════════════════

  /// Sudut permukaan: panel data 8, kontrol 10. Lihat [BentukLab].
  static const double sudutKertas = BentukLab.panel;
  static const double sudutLogam = BentukLab.kontrol;
  static const double sudutKaca = BentukLab.panel;

  /// Lembar kertas: putih + garis halus. Tidak ada bayangan; pemisahnya garis.
  BoxDecoration kertasLembar({double radius = sudutKertas, Color? warna}) =>
      BoxDecoration(
        color: warna ?? kertas,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kertasTepi),
      );

  /// Baki: tempat menaruh isi tambahan di atas lembar. Permukaan sedikit
  /// berbeda + garis halus.
  BoxDecoration kertasBaki({double radius = sudutKertas}) => BoxDecoration(
    color: kertas2,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kertasTepi),
  );

  /// Panel app bar, navigasi bawah, bar aksi: permukaan rata.
  ///
  /// Garis pemisah ke isi layar digambar pemanggil lewat [border].
  BoxDecoration logamPanel({BorderRadius? radius, Border? border}) =>
      BoxDecoration(color: logam, borderRadius: radius, border: border);

  /// Benda yang bisa ditekan: tombol, ubin ikon.
  ///
  /// [warna] mengganti isi (tombol biru/merah). Daftar dengan beberapa warna
  /// (peninggalan gradien) dibaca tengahnya; hasilnya tetap SATU warna rata.
  /// [tepi] bawaannya garis halus; tombol sekunder memberi [garisTegas].
  BoxDecoration logamTimbul({
    double radius = sudutLogam,
    List<Color>? warna,
    Color? tepi,
  }) => BoxDecoration(
    color: warna == null ? logam : warna[warna.length ~/ 2],
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tepi ?? kertasTepi),
  );

  /// Keadaan DITEKAN atau TERPILIH.
  ///
  /// Tanpa [warna]: isi kobalt tipis (kapsul item navigasi aktif, tombol
  /// sekunder yang sedang ditekan). Dengan [warna] (tombol biru/merah): isi
  /// itu menggelap sedikit. Dipakai bareng geseran 1 px di `SidikTombol`,
  /// karena perubahan warna saja kebaca "berubah", bukan "tertekan".
  BoxDecoration logamTertekan({
    double radius = sudutLogam,
    List<Color>? warna,
    Color? tepi,
  }) {
    final isi = warna == null
        ? biruTipis
        : Color.alphaBlend(
            Colors.black.withValues(alpha: terang ? 0.10 : 0.18),
            warna[warna.length ~/ 2],
          );
    return BoxDecoration(
      color: isi,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: tepi ?? kertasTepi),
    );
  }

  /// Layar readout alat ukur. Selalu gelap, di dua tema.
  BoxDecoration kacaCekung({double radius = sudutKaca}) => BoxDecoration(
    color: kaca,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kaca2),
  );

  /// Isian: kotak berisi permukaan cekung dengan garis tegas (kontrol 10).
  /// Fokus = garis kobalt 2 dp. Bordernya SATU WARNA per keadaan supaya aman
  /// dipasangi `borderRadius`.
  BoxDecoration isian({Color? garisBawah, bool fokus = false}) => BoxDecoration(
    color: kertas2,
    borderRadius: BorderRadius.circular(BentukLab.kontrol),
    border: fokus
        ? Border.all(color: biru, width: 2)
        : Border.all(color: garisBawah ?? garisTegas),
  );

  /// Gaya keterangan kecil (dulu label terukir). Minimum 12 sp: ukuran di
  /// bawahnya dinaikkan, karena beberapa layar masih meminta 11.
  TextStyle gayaEtsa({double ukuran = 12}) => TextStyle(
    color: tinta2,
    fontSize: ukuran < 12 ? 12 : ukuran,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  // ══════════════════════════════════════════════════════════════════════
  // ThemeExtension
  // ══════════════════════════════════════════════════════════════════════

  @override
  SidikMaterial copyWith({
    bool? terang,
    Color? meja,
    Color? meja2,
    Color? kertas,
    Color? kertas2,
    Color? kertasTepi,
    Color? garis,
    Color? tinta,
    Color? tinta2,
    Color? pensil,
    Color? logam,
    Color? logamAtas,
    Color? logamBawah,
    Color? logamTepi,
    Color? etsa,
    Color? kilau,
    Color? lekuk,
    Color? biru,
    Color? biruAtas,
    Color? biruTipis,
    Color? biruTinta,
    Color? lulus,
    Color? lulusTipis,
    Color? gagal,
    Color? gagalTipis,
    Color? awas,
    Color? awasTipis,
    Color? tunggu,
    Color? tungguTipis,
    Color? kaca,
    Color? kaca2,
    Color? lcdHijau,
    Color? lcdAmber,
    Color? lcdTeks,
  }) {
    return SidikMaterial(
      terang: terang ?? this.terang,
      meja: meja ?? this.meja,
      meja2: meja2 ?? this.meja2,
      kertas: kertas ?? this.kertas,
      kertas2: kertas2 ?? this.kertas2,
      kertasTepi: kertasTepi ?? this.kertasTepi,
      garis: garis ?? this.garis,
      tinta: tinta ?? this.tinta,
      tinta2: tinta2 ?? this.tinta2,
      pensil: pensil ?? this.pensil,
      logam: logam ?? this.logam,
      logamAtas: logamAtas ?? this.logamAtas,
      logamBawah: logamBawah ?? this.logamBawah,
      logamTepi: logamTepi ?? this.logamTepi,
      etsa: etsa ?? this.etsa,
      kilau: kilau ?? this.kilau,
      lekuk: lekuk ?? this.lekuk,
      biru: biru ?? this.biru,
      biruAtas: biruAtas ?? this.biruAtas,
      biruTipis: biruTipis ?? this.biruTipis,
      biruTinta: biruTinta ?? this.biruTinta,
      lulus: lulus ?? this.lulus,
      lulusTipis: lulusTipis ?? this.lulusTipis,
      gagal: gagal ?? this.gagal,
      gagalTipis: gagalTipis ?? this.gagalTipis,
      awas: awas ?? this.awas,
      awasTipis: awasTipis ?? this.awasTipis,
      tunggu: tunggu ?? this.tunggu,
      tungguTipis: tungguTipis ?? this.tungguTipis,
      kaca: kaca ?? this.kaca,
      kaca2: kaca2 ?? this.kaca2,
      lcdHijau: lcdHijau ?? this.lcdHijau,
      lcdAmber: lcdAmber ?? this.lcdAmber,
      lcdTeks: lcdTeks ?? this.lcdTeks,
    );
  }

  @override
  SidikMaterial lerp(ThemeExtension<SidikMaterial>? other, double t) {
    if (other is! SidikMaterial) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SidikMaterial(
      terang: t < 0.5 ? terang : other.terang,
      meja: c(meja, other.meja),
      meja2: c(meja2, other.meja2),
      kertas: c(kertas, other.kertas),
      kertas2: c(kertas2, other.kertas2),
      kertasTepi: c(kertasTepi, other.kertasTepi),
      garis: c(garis, other.garis),
      tinta: c(tinta, other.tinta),
      tinta2: c(tinta2, other.tinta2),
      pensil: c(pensil, other.pensil),
      logam: c(logam, other.logam),
      logamAtas: c(logamAtas, other.logamAtas),
      logamBawah: c(logamBawah, other.logamBawah),
      logamTepi: c(logamTepi, other.logamTepi),
      etsa: c(etsa, other.etsa),
      kilau: c(kilau, other.kilau),
      lekuk: c(lekuk, other.lekuk),
      biru: c(biru, other.biru),
      biruAtas: c(biruAtas, other.biruAtas),
      biruTipis: c(biruTipis, other.biruTipis),
      biruTinta: c(biruTinta, other.biruTinta),
      lulus: c(lulus, other.lulus),
      lulusTipis: c(lulusTipis, other.lulusTipis),
      gagal: c(gagal, other.gagal),
      gagalTipis: c(gagalTipis, other.gagalTipis),
      awas: c(awas, other.awas),
      awasTipis: c(awasTipis, other.awasTipis),
      tunggu: c(tunggu, other.tunggu),
      tungguTipis: c(tungguTipis, other.tungguTipis),
      kaca: c(kaca, other.kaca),
      kaca2: c(kaca2, other.kaca2),
      lcdHijau: c(lcdHijau, other.lcdHijau),
      lcdAmber: c(lcdAmber, other.lcdAmber),
      lcdTeks: c(lcdTeks, other.lcdTeks),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // NILAI TOKEN (dari PaletLab)
  // Angka kontrasnya diuji WCAG AA di dua tema: lihat
  // test/tema/kontras_sidik_test.dart. Jangan ubah satu warna tanpa
  // menjalankan tes itu lagi.
  // ══════════════════════════════════════════════════════════════════════

  static const SidikMaterial terangDefault = SidikMaterial(
    terang: true,
    meja: PaletLab.latarTerang,
    meja2: PaletLab.latar2Terang,
    kertas: PaletLab.kertasTerang,
    kertas2: PaletLab.kertas2Terang,
    kertasTepi: PaletLab.garisHalusTerang,
    garis: PaletLab.garisHalusTerang,
    tinta: PaletLab.tintaTerang, // 17,7:1 di kertas
    tinta2: PaletLab.tinta2Terang, // 7,7:1 di kertas, 7,0:1 di latar
    pensil: PaletLab.pensilTerang, // saran OCR, 5,4:1 di kertas
    logam: PaletLab.kertasTerang,
    logamAtas: PaletLab.kertasTerang,
    logamBawah: PaletLab.latar2Terang,
    logamTepi: PaletLab.garisTegasTerang, // garis tegas, 4,6:1 di kertas
    etsa: PaletLab.tintaTerang,
    kilau: PaletLab.tembus,
    lekuk: PaletLab.tembus,
    biru: PaletLab.kobalt700, // 9,5:1 di kertas; putih di atasnya 9,5:1
    biruAtas: PaletLab.kobalt300,
    biruTipis: PaletLab.kobalt100,
    biruTinta: PaletLab.kobalt700,
    lulus: PaletLab.lulusTerang, // 7,3:1 di latar tipisnya
    lulusTipis: PaletLab.lulusLatarTerang,
    gagal: PaletLab.gagalTerang, // 6,1:1
    gagalTipis: PaletLab.gagalLatarTerang,
    awas: PaletLab.awasTerang, // 6,3:1
    awasTipis: PaletLab.awasLatarTerang,
    tunggu: PaletLab.tungguTerang, // 8,7:1
    tungguTipis: PaletLab.tungguLatarTerang,
    kaca: PaletLab.latarGelap,
    kaca2: PaletLab.kertasGelap,
    lcdHijau: PaletLab.lulusGelap,
    lcdAmber: PaletLab.awasGelap,
    lcdTeks: PaletLab.tintaGelap,
  );

  /// Tema gelap: latar `#0E1320`, permukaan `#171D2B`, kobalt jenjang 300.
  static const SidikMaterial gelapDefault = SidikMaterial(
    terang: false,
    meja: PaletLab.latarGelap,
    meja2: PaletLab.latar2Gelap,
    kertas: PaletLab.kertasGelap,
    kertas2: PaletLab.kertas2Gelap,
    kertasTepi: PaletLab.garisHalusGelap,
    garis: PaletLab.garisHalusGelap,
    tinta: PaletLab.tintaGelap, // 14,0:1 di kertas
    tinta2: PaletLab.tinta2Gelap, // 7,9:1
    pensil: PaletLab.pensilGelap, // 5,8:1
    logam: PaletLab.kertasGelap,
    logamAtas: PaletLab.kertasGelap,
    logamBawah: PaletLab.latar2Gelap,
    logamTepi: PaletLab.garisTegasGelap, // garis tegas, 4,7:1 di kertas
    etsa: PaletLab.tintaGelap,
    kilau: PaletLab.tembus,
    lekuk: PaletLab.tembus,
    biru: PaletLab.kobalt300, // isi tombol & teks aksen: 7,8:1 di kertas
    biruAtas: PaletLab.kobalt300,
    biruTipis: PaletLab.kobaltGelapTipis,
    biruTinta: PaletLab.kobalt300,
    lulus: PaletLab.lulusGelap,
    lulusTipis: PaletLab.lulusLatarGelap,
    gagal: PaletLab.gagalGelap,
    gagalTipis: PaletLab.gagalLatarGelap,
    awas: PaletLab.awasGelap,
    awasTipis: PaletLab.awasLatarGelap,
    tunggu: PaletLab.tungguGelap,
    tungguTipis: PaletLab.tungguLatarGelap,
    kaca: PaletLab.latarGelap,
    kaca2: PaletLab.kertasGelap,
    lcdHijau: PaletLab.lulusGelap,
    lcdAmber: PaletLab.awasGelap,
    lcdTeks: PaletLab.tintaGelap,
  );
}

/// Sisa API "sikat logam". Tidak menggambar apa pun lagi (tema datar); kelas
/// dipertahankan supaya pemanggil lama tetap jalan sampai dikikis.
class SikatLogam extends StatelessWidget {
  const SikatLogam({super.key, this.kerapatan = 3, this.kekuatan = 0.16});

  final double kerapatan;
  final double kekuatan;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

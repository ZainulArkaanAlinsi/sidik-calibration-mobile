import 'package:flutter/material.dart';

/// Token & resep material untuk sistem visual **"Meja Kerja Lab"**.
///
/// Ini SATU-SATUNYA tempat warna dan bentuk permukaan ditulis. Tidak boleh ada
/// `Color(0x...)` yang ditulis langsung di widget — sama persis seperti aturan
/// lama di `AppColors`, cuma sekarang ikut tema lewat [ThemeExtension] jadi
/// mode gelap nggak perlu `if (isDark)` bertebaran di layar.
///
/// ## Tiga material, tiga tugas
///
/// Kalau ragu suatu elemen harus pakai apa, tanya: orang **membaca**,
/// **menekan**, atau **melirik**?
///
/// - **KERTAS** → tempat membaca & mengisi angka. Kartu, daftar, tabel, sel
///   lembar kerja, isian form. → [kertasLembar], [kertasBaki]
/// - **LOGAM** → tempat menekan, dan bingkai yang megang isi. App bar,
///   navigasi, tombol, chip, sakelar, ubin ikon. → [logamPanel], [logamTimbul]
/// - **KACA** → angka hidup yang dilirik sekilas. Panel teknisi, meteran.
///   → [kacaCekung]
///
/// Turunan dari aturan itu: label HURUF BESAR + spasi lebar **cuma boleh di
/// logam** (memang begitu cara panel alat ukur diukir). Di kertas semuanya
/// sentence case seperti formulir cetak.
///
/// ## Kenapa nggak ada blur di sini
///
/// Semua kedalaman digambar pakai gradien + bayangan, nol `BackdropFilter` dan
/// nol `MaskFilter.blur`. Dua itu sumber lag paling nyata di HP kelas bawah,
/// dan versi UI sebelumnya memakai keduanya (`GlassSurface`, `NeuInset`).
/// Gradien + bayangan dirender GPU tanpa bikin layer offscreen.
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

  // ══════════════════════════════════════════════════════════════════════
  // RESEP MATERIAL
  // ══════════════════════════════════════════════════════════════════════

  /// Sudut ngikut material: kertas dipotong lurus, logam dilembutkan mesin.
  static const double sudutKertas = 5;
  static const double sudutLogam = 10;
  static const double sudutKaca = 12;

  /// Lembar kertas yang terangkat sedikit dari meja.
  ///
  /// Seratnya SENGAJA tidak digambar di Flutter. Di CSS dia dua
  /// `repeating-linear-gradient` 3% alpha; di HP seratnya praktis tak terlihat
  /// sementara biayanya nyata kalau digambar per kartu. Yang bikin kertas
  /// kebaca sebagai kertas itu warnanya, tepinya, dan bayangannya — bukan
  /// seratnya.
  BoxDecoration kertasLembar({double radius = sudutKertas, Color? warna}) =>
      BoxDecoration(
        color: warna ?? kertas,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kertasTepi),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: terang ? 0.13 : 0.45),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: terang ? 0.16 : 0.55),
            blurRadius: 16,
            spreadRadius: -10,
            offset: const Offset(0, 7),
          ),
        ],
      );

  /// Baki cekung: tempat menaruh isi tambahan di atas lembar.
  BoxDecoration kertasBaki({double radius = sudutKertas}) => BoxDecoration(
    color: kertas2,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: terang ? 0.14 : 0.5),
        blurRadius: 4,
        offset: const Offset(0, 2),
        blurStyle: BlurStyle.inner,
      ),
    ],
  );

  /// Panel aluminium disikat. Dipakai app bar, navigasi bawah, bar aksi.
  ///
  /// Garis sikatnya digambar [SikatLogam] sebagai lapisan terpisah — di sini
  /// cuma gradien dasar + bevel, supaya panel tanpa sikat pun tetap benar.
  BoxDecoration logamPanel({BorderRadius? radius, Border? border}) =>
      BoxDecoration(
        borderRadius: radius,
        border: border,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [logamAtas, logam, logamBawah],
          stops: const [0, 0.42, 1],
        ),
      );

  /// Benda logam yang TIMBUL dan bisa ditekan: tombol, chip, ubin ikon.
  ///
  /// [warna] mengganti gradien dasar untuk tombol anodisasi (biru/merah).
  BoxDecoration logamTimbul({
    double radius = sudutLogam,
    List<Color>? warna,
    Color? tepi,
  }) {
    final isi = warna ?? [logamAtas, logam, logamBawah];
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: tepi ?? logamTepi),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isi,
        stops: isi.length == 3 ? const [0, 0.52, 1] : null,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: terang ? 0.20 : 0.45),
          blurRadius: 1,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: terang ? 0.30 : 0.55),
          blurRadius: 6,
          spreadRadius: -3,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Keadaan DITEKAN: benda masuk ke dalam panel. Dipakai bareng geseran 1 px
  /// di [SidikTombol] — dua-duanya perlu, karena bayangan saja tanpa gerakan
  /// kebaca sebagai "berubah warna", bukan "tertekan".
  BoxDecoration logamTertekan({
    double radius = sudutLogam,
    List<Color>? warna,
    Color? tepi,
  }) {
    final isi = warna ?? [logamBawah, logamAtas];
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: tepi ?? logamTepi),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isi,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 4,
          offset: const Offset(0, 2),
          blurStyle: BlurStyle.inner,
        ),
      ],
    );
  }

  /// Layar readout cekung. Selalu gelap, di dua tema.
  BoxDecoration kacaCekung({double radius = sudutKaca}) => BoxDecoration(
    color: kaca,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFF05070A)),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.055),
        Colors.black.withValues(alpha: 0.30),
      ],
      stops: const [0, 0.62],
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.75),
        blurRadius: 5,
        offset: const Offset(0, 2),
        blurStyle: BlurStyle.inner,
      ),
    ],
  );

  /// Isian di kertas: sedikit cekung, dengan garis isian tebal di bawahnya
  /// seperti kolom di formulir cetak.
  ///
  /// Bordernya sengaja SATU WARNA per keadaan. Flutter menolak `borderRadius`
  /// pada `Border` yang sisi-sisinya berbeda warna ("A borderRadius can only be
  /// given on borders with uniform colors") — assert di debug, cat rusak di
  /// rilis. Jadi keadaan biasa cuma punya garis bawah, dan keadaan fokus
  /// membiru di keempat sisi (lebar boleh beda, warnanya sama).
  BoxDecoration isian({Color? garisBawah, bool fokus = false}) => BoxDecoration(
    color: kertas2,
    borderRadius: BorderRadius.circular(4),
    border: fokus
        ? Border(
            top: BorderSide(color: biru),
            left: BorderSide(color: biru),
            right: BorderSide(color: biru),
            bottom: BorderSide(color: biru, width: 2),
          )
        : Border(
            bottom: BorderSide(color: garisBawah ?? tinta2, width: 2),
          ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.10),
        blurRadius: 3,
        offset: const Offset(0, 2),
        blurStyle: BlurStyle.inner,
      ),
    ],
  );

  /// Gaya teks label yang diukir di logam. HURUF BESAR + spasi lebar di sini
  /// BENAR — itu memang cara panel alat ukur diberi label.
  TextStyle gayaEtsa({double ukuran = 11}) => TextStyle(
    color: etsa,
    fontSize: ukuran,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.09 * ukuran,
    shadows: [
      Shadow(
        color: terang
            ? Colors.white.withValues(alpha: 0.52)
            : Colors.black.withValues(alpha: 0.65),
        offset: Offset(0, terang ? 1 : -1),
      ),
    ],
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
  // NILAI TOKEN
  // Angka kontrasnya sudah diuji ke WCAG AA di dua tema — lihat
  // test/tema/kontras_sidik_test.dart. Jangan ubah satu warna tanpa
  // menjalankan test itu lagi.
  // ══════════════════════════════════════════════════════════════════════

  static const SidikMaterial terangDefault = SidikMaterial(
    terang: true,
    meja: Color(0xFFD6D2C8),
    meja2: Color(0xFFCBC7BC),
    kertas: Color(0xFFF5F1E7),
    kertas2: Color(0xFFEAE5D8),
    kertasTepi: Color(0xFFD9D2C0),
    garis: Color(0xFFC9D5E2),
    tinta: Color(0xFF1A1F26), // 14,7:1 di kertas
    // Sengaja lebih tua dari pilihan pertama (#585E67). Di situ keterangan
    // yang jatuh langsung di atas permukaan meja cuma 4,3:1 — di bawah
    // ambang, dan itu kejadian nyata di beberapa layar.
    tinta2: Color(0xFF4A5059), // 7,2:1 di kertas · 5,4:1 di meja
    pensil: Color(0xFF616770), // 4,9:1 — batas AA, jangan diterangin lagi
    logam: Color(0xFFC7C4BC),
    logamAtas: Color(0xFFDAD7D0),
    logamBawah: Color(0xFFB3B0A8),
    logamTepi: Color(0xFF9C998F),
    etsa: Color(0xFF2B2F35), // 7,7:1 di logam
    kilau: Color(0xC7FFFFFF),
    lekuk: Color(0x33000000),
    biru: Color(0xFF1D4292), // 8,3:1 di kertas · putih di atasnya 9,4:1
    biruAtas: Color(0xFF3563C4),
    biruTipis: Color(0xFFDFE7F8),
    biruTinta: Color(0xFF1D4292),
    // Hijau sengaja LEBIH TUA dari pilihan pertama (#166B3C). Di situ hijau
    // dan merahnya nyaris sama terangnya, jadi di fotokopi hitam-putih —
    // dan buat mata yang buta warna merah-hijau — PASS dan FAIL jadi satu
    // rupa. Lihat kontras_sidik_test.dart.
    lulus: Color(0xFF125739), // 7,6:1
    lulusTipis: Color(0xFFDCEBE0),
    gagal: Color(0xFFA81B33), // 6,5:1
    gagalTipis: Color(0xFFF6DEE2),
    awas: Color(0xFF8C5C0A), // 5,1:1
    awasTipis: Color(0xFFF7EBD5),
    tunggu: Color(0xFF474D55), // 7,6:1
    tungguTipis: Color(0xFFE4E2DD),
    kaca: Color(0xFF0C1013),
    kaca2: Color(0xFF151B20),
    lcdHijau: Color(0xFF7FE3A8),
    lcdAmber: Color(0xFFF0B95E),
    lcdTeks: Color(0xFFD8E4E8),
  );

  /// Lab waktu lampu atas dimatikan — benda yang sama, cahayanya beda.
  /// Bukan warna yang dibalik: kertas tetap kertas, cuma diterangi lampu meja.
  static const SidikMaterial gelapDefault = SidikMaterial(
    terang: false,
    meja: Color(0xFF0F1114),
    meja2: Color(0xFF16191D),
    kertas: Color(0xFF24272D),
    kertas2: Color(0xFF1B1E23),
    kertasTepi: Color(0xFF33373E),
    garis: Color(0xFF39414B),
    tinta: Color(0xFFEAE6DC), // 12,0:1
    tinta2: Color(0xFFA6A9B1), // 6,4:1
    pensil: Color(0xFF8F949C), // 4,9:1
    logam: Color(0xFF393D45),
    logamAtas: Color(0xFF4A4F58),
    logamBawah: Color(0xFF2C3037),
    logamTepi: Color(0xFF21242A),
    etsa: Color(0xFFD9DCE2),
    kilau: Color(0x21FFFFFF),
    lekuk: Color(0x8C000000),
    biru: Color(0xFF2B4E9E),
    biruAtas: Color(0xFF4470CE),
    biruTipis: Color(0xFF1C2740),
    biruTinta: Color(0xFF8FB0FF), // 7,0:1
    lulus: Color(0xFF5DCE93), // 7,6:1
    lulusTipis: Color(0xFF16301F),
    gagal: Color(0xFFFF8092), // 6,2:1
    gagalTipis: Color(0xFF3A1820),
    awas: Color(0xFFF2B655), // 8,3:1
    awasTipis: Color(0xFF36280F),
    tunggu: Color(0xFFB6BAC4), // 7,7:1
    tungguTipis: Color(0xFF262A31),
    kaca: Color(0xFF0C1013),
    kaca2: Color(0xFF151B20),
    lcdHijau: Color(0xFF7FE3A8),
    lcdAmber: Color(0xFFF0B95E),
    lcdTeks: Color(0xFFD8E4E8),
  );
}

/// Garis sikat aluminium, digambar sebagai lapisan tipis di atas panel logam.
///
/// Sengaja pakai painter, bukan gambar: sikatnya cuma garis 1 px tiap 3 px,
/// jadi menggambarnya lebih murah daripada memuat & men-tile tekstur, dan
/// ukurannya ikut panel tanpa perlu aset per-kerapatan layar.
///
/// Dipakai cuma di permukaan logam yang KECIL (app bar, nav, bar aksi, tombol).
/// Jangan dipasang di area sebesar layar penuh.
class SikatLogam extends StatelessWidget {
  const SikatLogam({super.key, this.kerapatan = 3, this.kekuatan = 0.16});

  /// Jarak antar garis sikat, dalam piksel logis.
  final double kerapatan;

  /// Alpha garis terangnya.
  final double kekuatan;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PelukisSikat(kerapatan: kerapatan, kekuatan: kekuatan),
        size: Size.infinite,
      ),
    );
  }
}

class _PelukisSikat extends CustomPainter {
  const _PelukisSikat({required this.kerapatan, required this.kekuatan});

  final double kerapatan;
  final double kekuatan;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = Colors.white.withValues(alpha: kekuatan)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += kerapatan) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cat);
    }
  }

  @override
  bool shouldRepaint(_PelukisSikat old) =>
      old.kerapatan != kerapatan || old.kekuatan != kekuatan;
}

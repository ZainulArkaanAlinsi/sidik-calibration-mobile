import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Permukaan panel — bidang rata dengan garis tepi tipis dan bayangan lembut.
/// Varian utamanya masih ngeblur apa pun di belakangnya; warnanya sendiri
/// nggak pernah bergradasi.
///
/// ## Kenapa blur-nya dijatah
///
/// `BackdropFilter` itu operasi paling mahal yang bisa dipasang di Flutter:
/// tiap frame dia maksa `saveLayer` lalu nge-blur seluruh area di belakangnya.
/// App ini udah pernah kena masalahnya — `NeuInset` dulu pakai `MaskFilter.blur`
/// dan bikin ngelag di HP low-end tiap kali user ngetik, sampai akhirnya
/// diganti gradient (lihat `neu.dart`).
///
/// Makanya kaca beneran cuma dipakai buat permukaan yang **kecil, diam, dan
/// muncul sesekali** — sheet hasil, dialog, app bar. Buat permukaan yang
/// **panjang atau di-scroll** (kartu di dalam daftar), pakai [GlassSurface.rata]
/// yang bidangnya solid tanpa blur sama sekali: bentuk dan bayangannya sama,
/// tapi nol biaya raster.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.blur = 24,
    this.opacity = 0.72,
  }) : _pakaiBlur = true;

  /// Versi tanpa `BackdropFilter`. Aman dipakai berkali-kali dalam satu daftar.
  const GlassSurface.rata({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.opacity = 0.86,
  }) : blur = 0,
       _pakaiBlur = false;

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double opacity;
  final bool _pakaiBlur;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final dasar = gelap ? AppColors.inkElevated : AppColors.white;

    // Bidangnya rata satu warna. Dulu di sini ada gradasi putih-ke-aksen plus
    // halo warna di pojok; itu bikin cobalt dan mint kelebur sama warna
    // permukaan, jadi ronanya nggak pernah kebaca murni. Sekarang kedalaman
    // digambar sama bayangan dan garis tepi doang — aksen warna cuma muncul
    // dari isi kartunya, dan muncul utuh.
    final isi = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: dasar.withValues(alpha: _pakaiBlur ? opacity : 1),
        border: Border.all(
          color: gelap ? AppColors.inkOutline : AppColors.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: gelap ? 0.55 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (!_pakaiBlur) return isi;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: isi,
      ),
    );
  }
}

/// Permukaan timbul bergaya 3D lembut — kartu yang kelihatan ngambang sedikit
/// di atas latar, pakai dua bayangan: satu gelap di bawah (bayangan jatuh) dan
/// satu terang di atas (pantulan cahaya).
///
/// Bayangannya sengaja lebar dan tipis, bukan pekat dan sempit — itu yang
/// bikin kesan empuk, bukan kesan kartu ketebalan.
class SoftRaised extends StatelessWidget {
  const SoftRaised({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(16),
    this.warna,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? warna;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final dasar = warna ?? (gelap ? AppColors.inkSurface : AppColors.white);

    final kotak = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Warna rata. Kedalaman kartu ini seluruhnya dari bayangan di bawah
        // dan garis tepi rambut — nggak ada gradasi, supaya warna aksen yang
        // ditaruh di atasnya kebaca persis seperti nilainya.
        color: dasar,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: gelap ? AppColors.inkOutline : AppColors.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: gelap ? 0.55 : 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          // Bayangan kedua yang lebih rapat & gelap, persis di bawah kartu.
          // Yang lebar bikin kesan ngambang tinggi; yang rapat ini yang bikin
          // tepi bawahnya "napak", jadi bentuknya kebaca padat, bukan kabur.
          BoxShadow(
            color: AppColors.ink.withValues(alpha: gelap ? 0.35 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return kotak;

    // RepaintBoundary: kartu bayangan begini gampang jadi beban kalau ikut
    // repaint tiap frame pas daftarnya di-scroll.
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: kotak,
        ),
      ),
    );
  }
}

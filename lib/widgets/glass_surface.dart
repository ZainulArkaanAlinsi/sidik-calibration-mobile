import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Permukaan "liquid glass" — panel tembus pandang yang ngeblur apa pun di
/// belakangnya, plus garis tipis di tepi biar bidangnya kebaca.
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
/// yang meniru kesan kaca lewat gradient tanpa blur sama sekali: mirip di mata,
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
    final dasar = gelap ? AppColors.darkElevated : AppColors.white;

    // Gradient miring: sisi kiri-atas lebih terang (seolah cahaya jatuh dari
    // sana), sisi kanan-bawah lebih redup. Ini yang bikin bidangnya kebaca
    // sebagai lempeng kaca, bukan sekadar kotak transparan.
    final isi = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            dasar.withValues(alpha: opacity),
            dasar.withValues(alpha: opacity * (gelap ? 0.78 : 0.62)),
          ],
        ),
        border: Border.all(
          color: (gelap ? AppColors.white : AppColors.white).withValues(
            alpha: gelap ? 0.14 : 0.65,
          ),
          width: 1,
        ),
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
    final dasar = warna ?? (gelap ? AppColors.darkSurface : AppColors.white);

    final kotak = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dasar,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (gelap ? Colors.black : AppColors.navy).withValues(
              alpha: gelap ? 0.42 : 0.10,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (gelap ? AppColors.white : AppColors.white).withValues(
              alpha: gelap ? 0.05 : 0.85,
            ),
            blurRadius: 12,
            offset: const Offset(0, -3),
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

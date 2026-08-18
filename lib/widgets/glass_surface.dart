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
    // Semburat warna tipis di kaca — bukan putih polos. Putih murni di atas
    // latar yang udah pucat (`gradasiLatar` terang) nyaris nggak kebeda dari
    // kartu Material biasa; kaca beneran selalu mantulin sedikit warna
    // sekitarnya.
    final aksenKaca = gelap ? AppColors.tealBright : AppColors.electricBlue;

    // Gradient miring: sisi kiri-atas lebih terang (seolah cahaya jatuh dari
    // sana), sisi kanan-bawah lebih redup. Ini yang bikin bidangnya kebaca
    // sebagai lempeng kaca, bukan sekadar kotak transparan.
    //
    // Tepinya sendiri digambar sebagai gradasi (bukan `Border.all` satu
    // warna): dibungkus lewat Container 1,2px yang latarnya gradient, terus
    // isinya ditempel di dalam — trik lama buat gradient border di Flutter
    // tanpa nambah dependency. Garis putih rata dulu ilang total di latar
    // terang (putih di atas putih); gradasi ini tetap kebaca dari dua sisi.
    final isi = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: gelap ? 0.30 : 0.95),
            aksenKaca.withValues(alpha: gelap ? 0.20 : 0.28),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (gelap ? Colors.black : AppColors.navy).withValues(
              alpha: gelap ? 0.18 : 0.10,
            ),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: aksenKaca.withValues(alpha: gelap ? 0.10 : 0.14),
            blurRadius: 34,
            spreadRadius: -10,
            offset: const Offset(-12, -14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  dasar,
                  aksenKaca,
                  gelap ? 0.12 : 0.05,
                )!.withValues(alpha: opacity),
                dasar.withValues(alpha: opacity * (gelap ? 0.76 : 0.60)),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Halo warna lembut di pojok — ala panel instrumen retro.
              // Dipotong `ClipRRect` di atas, jadi cuma nongol separuh —
              // kesannya nempel di kaca, bukan digambar rapi di tengah kartu.
              Positioned(
                right: -radius * 0.6,
                top: -radius * 0.6,
                width: radius * 2.4,
                height: radius * 2.4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          aksenKaca.withValues(alpha: gelap ? 0.16 : 0.13),
                          aksenKaca.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Pantulan di atas: pita gradasi, bukan garis rambut — itu yang
              // dulu ilang total di latar terang (putih 1px di atas putih).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 46,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.white.withValues(
                            alpha: gelap ? 0.10 : 0.55,
                          ),
                          AppColors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
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
        // Gradasi tipis + garis tepi rambut, bukan warna rata: kartu ini
        // sengaja BUKAN kaca (nggak ada halo/pantulan), tapi warna rata
        // polos di sebelah kartu kaca yang sekarang ada tekstur bikin dia
        // kebaca kayak elemen dari sistem desain yang beda — cukup gradasi
        // super tipis biar tetap satu keluarga tanpa ikut jadi "kaca".
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(dasar, Colors.white, gelap ? 0.05 : 0.6)!, dasar],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: gelap
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.navy.withValues(alpha: 0.045),
        ),
        boxShadow: [
          BoxShadow(
            color: (gelap ? Colors.black : AppColors.navy).withValues(
              alpha: gelap ? 0.48 : 0.16,
            ),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          // Bayangan kedua yang lebih rapat & gelap, persis di bawah kartu.
          // Yang lebar bikin kesan ngambang tinggi; yang rapat ini yang bikin
          // tepi bawahnya "napak", jadi bentuknya kebaca padat, bukan kabur.
          BoxShadow(
            color: (gelap ? Colors.black : AppColors.navy).withValues(
              alpha: gelap ? 0.30 : 0.07,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
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

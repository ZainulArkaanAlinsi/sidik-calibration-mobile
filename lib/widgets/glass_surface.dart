import 'package:flutter/material.dart';

import '../core/theme/sidik_material.dart';

/// Permukaan panel tempat data dibaca — sekarang LEMBAR KERTAS, tanpa blur.
///
/// Nama kelasnya peninggalan (dulu kaca buram ber-`BackdropFilter`). Dia
/// dipertahankan karena delapan tempat di dashboard, draf, daftar alat, profil,
/// dan arsip memanggilnya; kontraknya (`child`, `radius`, `padding`, `blur`,
/// `opacity`, konstruktor `.rata`) tidak berubah, jadi pemanggilnya tidak
/// perlu disentuh.
///
/// ## Kenapa kacanya dibuang dari sini
///
/// Di sistem "Meja Kerja Lab" kaca bening cuma untuk benda yang MENGAMBANG
/// dan SEMENTARA (sheet, dialog). Semua pemakai kelas ini justru permukaan
/// data — kartu ringkasan, daftar draf, kartu alat. Orang tidak membaca angka
/// lewat kaca buram, dan `BackdropFilter` di permukaan yang ikut digulir
/// memaksa `saveLayer` tiap frame: persis penyebab lag yang dulu dikejar di
/// `NeuInset`.
///
/// `blur` & `opacity` tetap diterima supaya pemanggil lama tetap terkompilasi,
/// tapi sengaja diabaikan.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.blur = 24,
    this.opacity = 0.72,
  });

  const GlassSurface.rata({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(20),
    this.opacity = 0.86,
  }) : blur = 0;

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Diabaikan — lihat docblock kelas.
  final double blur;

  /// Diabaikan — kertas tidak tembus pandang.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    return Container(
      decoration: m.kertasLembar(radius: sudutKertasDari(radius)),
      padding: padding,
      child: child,
    );
  }
}

/// Kotak yang sedikit terangkat dari meja — sekarang juga lembar kertas.
///
/// Dipakai arsip, folder manager, dan kartu statistik. `warna` tetap dihormati
/// (dipakai untuk kartu yang diwarnai status), `onTap` tetap bekerja.
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
    final m = SidikMaterial.of(context);
    final sudut = sudutKertasDari(radius);

    final kotak = Container(
      padding: padding,
      decoration: m.kertasLembar(radius: sudut, warna: warna),
      child: child,
    );

    if (onTap == null) return kotak;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(sudut),
          child: kotak,
        ),
      ),
    );
  }
}

/// Sudut kertas dari `radius` lama.
///
/// Tema lama memakai sudut 24–28 px; kertas yang dibulatkan sebesar itu tidak
/// lagi kebaca sebagai kertas, melainkan pil. Pemanggil yang memang minta
/// sudut kecil (≤ 12) tetap dihormati; yang besar diturunkan ke sudut lembar.
double sudutKertasDari(double radius) =>
    radius <= 12 ? radius : SidikMaterial.sudutKertas + 3;
